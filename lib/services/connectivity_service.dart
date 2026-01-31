import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shop_app/services/local_store.dart';
import 'package:shop_app/services/offline_sync_service.dart';

/// Service to monitor connectivity and handle offline/online transitions.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _onlineController.stream;

  /// Initialize the connectivity service and start monitoring.
  Future<void> init() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _updateConnectivity(results);

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectivity);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    
    // Consider online if any result is not 'none'
    _isOnline = results.any((result) => result != ConnectivityResult.none);

    // Update local store
    LocalStore.setOfflineMode(!_isOnline);

    // Notify listeners
    _onlineController.add(_isOnline);

    debugPrint('Connectivity changed: ${_isOnline ? "Online" : "Offline"}');

    // If we just came back online, trigger sync
    if (_isOnline && !wasOnline) {
      _syncPendingData();
    }
  }

  /// Attempt to sync pending data when coming back online.
  Future<void> _syncPendingData() async {
    debugPrint('Syncing pending data...');
    
    try {
      final offlineSync = OfflineSyncService();
      await offlineSync.tryFlushPendingSales();
      await offlineSync.tryFlushPendingPayments();
      
      // Update last sync time
      await LocalStore.setLastSyncTime(DateTime.now());
      
      debugPrint('Sync completed');
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }

  /// Manually trigger a sync attempt.
  Future<void> manualSync() async {
    if (_isOnline) {
      await _syncPendingData();
    }
  }

  /// Get the count of pending items to sync.
  Future<int> getPendingCount() async {
    final pendingSales = LocalStore.getPendingSales().length;
    final pendingPayments = LocalStore.getPendingPayments().length;
    return pendingSales + pendingPayments;
  }

  /// Dispose of resources.
  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }
}
