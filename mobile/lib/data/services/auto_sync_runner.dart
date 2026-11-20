import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_service.dart';

class AutoSyncRunner with WidgetsBindingObserver {
  AutoSyncRunner(this.sync);
  final SyncService sync;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _timer;
  bool _running = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) _run();
    });
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _run());
    _run();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _run();
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try { await sync.syncPending(); } catch (_) { /* outbox retained; next trigger retries */ }
    finally { _running = false; }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
