import 'dart:async';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import '../screens/home_screen.dart';
import '../screens/recipe_detail_screen.dart';
import 'recipe_service.dart';

/// Wraps Firebase Cloud Messaging: requests permission, keeps the device's
/// FCM token registered with the backend (together with the alert tags the
/// user enabled in the Notifications screen), and surfaces foreground
/// messages as an in-app banner.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiService _api = ApiService();
  final RecipeService _recipeService = RecipeService();

  GlobalKey<NavigatorState>? navigatorKey;
  String? _token;
  bool _initialized = false;
  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;

  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _initialized = true;
    this.navigatorKey = navigatorKey;

    try {
      if (!kIsWeb) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        ).timeout(const Duration(seconds: 10));
        log('FCM permission: ${settings.authorizationStatus.name}');
      }
    } catch (e) {
      log('FCM permission request failed: $e');
    }

    // Foreground messages are shown as an in-app banner (background messages
    // are rendered by FCM in the system tray automatically).
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Tapping a notification (app opened from background) routes the user.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message.data);
    });
    _messaging.getInitialMessage().then((message) {
      if (message != null) _handleTap(message.data);
    });

    // FCM tokens rotate — re-register whenever it happens.
    _messaging.onTokenRefresh.listen((token) async {
      _token = token;
      await syncSettings();
    });

    await _refreshTokenAndRegister();
  }

  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'web';
    }
  }

  Future<void> _refreshTokenAndRegister() async {
    try {
      // Guard against a dead/unresponsive FCM client (e.g. no Play services)
      // so a background init can never hang the app's startup pipeline.
      _token = await _messaging.getToken().timeout(const Duration(seconds: 15));
      await syncSettings();
    } catch (e) {
      // On web this needs the firebase-messaging service worker; fail quietly.
      log('FCM getToken failed: $e');
      // The old token (if any) is now unusable — drop it server-side so the
      // backend stops trying to push to a dead registration.
      await unregister();
    }
  }

  /// Reads the user's Notifications screen toggles and re-registers this
  /// device's tags with the backend. Call after the settings change or the
  /// auth state changes.
  Future<void> syncSettings() async {
    final token = _token;
    if (token == null) return;
    if (fb.FirebaseAuth.instance.currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final tags = <String>[];

    final pushEnabled = prefs.getBool('push_notifications') ?? true;
    if (pushEnabled) {
      if (prefs.getBool('new_recipes_alerts') ?? true) {
        tags.add('new_recipes');
      }
      if (prefs.getBool('recipe_approval_alerts') ?? true) {
        tags.add('recipe_approval');
      }
      if (prefs.getBool('community_updates_alerts') ?? true) {
        tags.add('community_updates');
      }
    }

    try {
      await _api.post('/notifications/register/', {
        'token': token,
        'platform': _platform,
        'tags': tags,
      });
      log('FCM registered (tags: $tags)');
    } catch (e) {
      log('FCM register failed: $e');
    }
  }

  /// Drops this device's token so the user stops receiving pushes.
  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;
    try {
      await _api.post('/notifications/unregister/', {'token': token});
      log('FCM token unregistered');
    } catch (e) {
      log('FCM unregister failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Sudanile Kitchen';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    _showBanner(title, body, message.data);
  }

  void _showBanner(String title, String body, Map<String, dynamic> data) {
    final overlay = navigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    _bannerTimer?.cancel();
    _bannerEntry?.remove();

    _bannerEntry = OverlayEntry(
      builder: (_) => _NotificationBanner(
        title: title,
        body: body,
        onTap: () {
          _dismissBanner();
          _handleTap(data);
        },
        onDismiss: _dismissBanner,
      ),
    );
    overlay.insert(_bannerEntry!);

    _bannerTimer = Timer(const Duration(seconds: 5), _dismissBanner);
  }

  void _dismissBanner() {
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    _bannerEntry = null;
  }

  void _handleTap(Map<String, dynamic> data) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    final type = data['type'];
    if (type == 'new_recipe' && data['recipe_id'] != null) {
      final recipeId = int.tryParse(data['recipe_id'].toString());
      if (recipeId != null) {
        _openRecipe(navigator, recipeId);
        return;
      }
    }

    // Default: land on Home (which also covers community updates).
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _openRecipe(
      NavigatorState navigator, int recipeId) async {
    final recipe = await _recipeService.getRecipe(recipeId);
    if (recipe == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
    );
  }

  /// Convenience for the auth flow: if the user signs out we unregister, and
  /// once they sign back in we re-register with the stored preferences.
  Future<void> onAuthChanged() async {
    final signedIn = fb.FirebaseAuth.instance.currentUser != null;
    if (signedIn) {
      await _refreshTokenAndRegister();
    } else {
      await unregister();
    }
  }
}

/// A small top-of-screen notification banner used for foreground pushes.
class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
