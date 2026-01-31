import 'package:flutter/material.dart';
import 'package:shop_app/services/connectivity_service.dart';
import 'package:shop_app/services/offline_sync_service.dart';
import 'package:shop_app/utils/app_theme.dart';

/// A banner that shows when the app is offline or has pending sync items.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOnline = true;
  int _pendingCount = 0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();

    ConnectivityService().onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
        _updatePendingCount();
      }
    });
  }

  Future<void> _checkStatus() async {
    _isOnline = ConnectivityService().isOnline;
    await _updatePendingCount();
    if (mounted) setState(() {});
  }

  Future<void> _updatePendingCount() async {
    final count = await OfflineSyncService().pendingCount();
    if (mounted) {
      setState(() => _pendingCount = count);
    }
  }

  Future<void> _manualSync() async {
    if (!_isOnline || _isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await ConnectivityService().manualSync();
      await _updatePendingCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if online and nothing pending
    if (_isOnline && _pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _isOnline ? AppTheme.primaryColor : Colors.orange,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              _isOnline ? Icons.sync : Icons.cloud_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isOnline
                        ? 'Pending sync: $_pendingCount items'
                        : 'You are offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!_isOnline)
                    Text(
                      _pendingCount > 0
                          ? '$_pendingCount items will sync when online'
                          : 'Data will be saved locally',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (_isOnline && _pendingCount > 0)
              TextButton(
                onPressed: _isSyncing ? null : _manualSync,
                child: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SYNC NOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
