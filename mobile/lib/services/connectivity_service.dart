import 'dart:async';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device currently has a usable network connection and
/// exposes it as a [ValueNotifier] so widgets (e.g. the offline banner) and
/// services can react.
///
/// Services also feed back real request outcomes via [reportNetworkError] /
/// [reportNetworkOk] so the banner reflects "backend unreachable" states too,
/// which the platform connectivity check alone cannot detect.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final results = await _connectivity.checkConnectivity();
      _apply(results);
      _subscription = _connectivity.onConnectivityChanged.listen(_apply);
      log('📶 Connectivity monitor started');
    } catch (e) {
      // Non-fatal: without the plugin the banner simply never shows.
      log('📶 Connectivity init failed: $e');
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    isOffline.value = offline;
  }

  /// Call from a service after a network request fails/times out.
  void reportNetworkError() => isOffline.value = true;

  /// Call from a service after a network request succeeds.
  void reportNetworkOk() => isOffline.value = false;

  void dispose() {
    _subscription?.cancel();
    isOffline.dispose();
  }
}
