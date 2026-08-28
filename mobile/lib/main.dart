import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/favorites_provider.dart';
import 'providers/community_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/cache_service.dart';
import 'services/connectivity_service.dart';
import 'services/push_notification_service.dart';
import 'services/recipe_service.dart';
import 'utils/app_themes.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Persistent disk cache (Hive) — must be ready before any screen renders so
  // offline fallbacks have data to read. Connectivity is best-effort and
  // fire-and-forget; the banner just appears when it becomes available.
  await CacheService.instance.init();
  unawaited(ConnectivityService.instance.init());
  // Pull the whole recipe catalog into the offline pool the first time the
  // app is online, so search/filters/details work fully offline even for
  // recipes never browsed. Fire-and-forget by design — startup never waits.
  RecipeService.prefetchWhenOnline();

  // Initialise push notifications in the background. Fire-and-forget on
  // purpose: on some devices FCM's permission prompt / token fetch can block
  // (or never resolve), and startup must never wait on it — otherwise the app
  // hangs on the launch logo with no UI. Token registration + foreground
  // banners just kick in whenever FCM finishes initialising.
  unawaited(PushNotificationService.instance.initialize(navigatorKey: navigatorKey));
  // Keep the device's FCM registration in sync with sign-in / sign-out.
  fb.FirebaseAuth.instance.authStateChanges().listen((_) async {
    await PushNotificationService.instance.onAuthChanged();
  });

  runApp(const SudanileKitchenApp());
}

class SudanileKitchenApp extends StatelessWidget {
  const SudanileKitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Sudanile Kitchen',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
