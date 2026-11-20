import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_service.dart';

class AutoSyncRunner {
  AutoSyncRunner(this.sync);
  final SyncService sync;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _timer;
  bool _running = false;

  void start() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) _run();
    });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _run());
    _run();
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try { await sync.syncPending(); } catch (_) { /* outbox retained; next trigger retries */ }
    finally { _running = false; }
  }

  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
