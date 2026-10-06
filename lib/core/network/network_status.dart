import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../safe_notifier.dart';

/// Cihazın çevrimdışı olup olmadığını izler.
///
/// Testler [listenToPlatform] kapalı örnek kullanır; üretimde
/// [NetworkStatus.platform] Connectivity akışına bağlanır.
class NetworkStatus extends ChangeNotifier with SafeNotifier {
  NetworkStatus({
    this.isOffline = false,
    this.listenToPlatform = false,
    this.connectivity,
  });

  factory NetworkStatus.platform({Connectivity? connectivity}) {
    return NetworkStatus(
      listenToPlatform: true,
      connectivity: connectivity,
    );
  }

  final bool listenToPlatform;
  final Connectivity? connectivity;

  bool isOffline;
  bool _started = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  VoidCallback? onWentOnline;

  bool get isOnline => !isOffline;

  Future<void> start() async {
    if (_started || !listenToPlatform) return;
    _started = true;

    final connectivity = this.connectivity ?? Connectivity();
    try {
      _apply(await connectivity.checkConnectivity());
      _subscription = connectivity.onConnectivityChanged.listen(_apply);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('[NetworkStatus] başlatılamadı: $error');
      }
    }
  }

  /// Testler ve manuel senaryolar için.
  void setOffline(bool value) {
    _setOffline(value);
  }

  void _apply(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    _setOffline(offline);
  }

  void _setOffline(bool value) {
    if (value == isOffline) return;
    final wasOffline = isOffline;
    isOffline = value;
    safeNotifyListeners();
    if (wasOffline && !isOffline) {
      onWentOnline?.call();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
