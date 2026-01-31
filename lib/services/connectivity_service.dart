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
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectInterval = Duration(seconds: 5);

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

    // If we just came back online, trigger sync and stop reconnect attempts
    if (_isOnline && !wasOnline) {
      _stopReconnectTimer();
      _reconnectAttempts = 0;
      _syncPendingData();
    }
    
    // If we just went offline, start reconnect attempts
    if (!_isOnline && wasOnline) {
      _startReconnectTimer();
    }
  }

  /// Start periodic reconnection attempts
  void _startReconnectTimer() {
    _stopReconnectTimer();
    _reconnectAttempts = 0;
    
    debugPrint('Starting auto-reconnect timer...');
    
    _reconnectTimer = Timer.periodic(_reconnectInterval, (timer) async {
      if (_isOnline) {
        _stopReconnectTimer();
        return;
      }
      
      _reconnectAttempts++;
      debugPrint('Reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts');
      
      // Check connectivity again
      try {
        final results = await _connectivity.checkConnectivity();
        _updateConnectivity(results);
      } catch (e) {
        debugPrint('Reconnect check failed: $e');
      }
      
      // Stop after max attempts (will restart on next disconnect)
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        debugPrint('Max reconnect attempts reached, stopping timer');
        _stopReconnectTimer();
      }
    });
  }

  /// Stop reconnection timer
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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

  /// Force a reconnection check
  Future<void> forceReconnect() async {
    debugPrint('Forcing reconnection check...');
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectivity(results);
      if (_isOnline) {
        await _syncPendingData();
      }
    } catch (e) {
      debugPrint('Force reconnect failed: $e');
    }
  }

  /// Dispose of resources.
  void dispose() {
    _stopReconnectTimer();
    _subscription?.cancel();
    _onlineController.close();
  }
}
