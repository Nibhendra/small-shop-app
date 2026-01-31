import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/services/local_store.dart';

class OfflineSyncService {
  OfflineSyncService({FirestoreService? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirestoreService(),
        _auth = auth ?? FirebaseAuth.instance;

  final FirestoreService _firestore;
  final FirebaseAuth _auth;

  static bool _flushingSales = false;
  static bool _flushingPayments = false;

  Future<void> enqueueSale(Map<String, dynamic> sale) async {
    final current = LocalStore.getPendingSales();
    current.add(sale);
    await LocalStore.setPendingSales(current);
  }

  Future<void> enqueuePayment(Map<String, dynamic> payment) async {
    await LocalStore.addPendingPayment(payment);
  }

  Future<int> pendingCount() async {
    return LocalStore.getPendingSales().length + LocalStore.getPendingPayments().length;
  }

  Future<int> pendingSalesCount() async {
    return LocalStore.getPendingSales().length;
  }

  Future<int> pendingPaymentsCount() async {
    return LocalStore.getPendingPayments().length;
  }

  Future<void> tryFlushPendingSales() async {
    if (_flushingSales) return;
    if (_auth.currentUser == null) return;

    final pending = LocalStore.getPendingSales();
    if (pending.isEmpty) return;

    _flushingSales = true;
    try {
      final remaining = <Map<String, dynamic>>[];

      for (final item in pending) {
        try {
          await _firestore.addSaleAndUpdateStock(
            amount: (item['amount'] as num).toDouble(),
            description: item['description'] as String,
            paymentMode: item['payment_mode'] as String,
            platform: item['platform'] as String,
            cart: Map<String, int>.from(item['cart'] as Map),
            customerId: item['customer_id'] as String?,
            customerName: item['customer_name'] as String?,
            customerPhone: item['customer_phone'] as String?,
            isCredit: item['is_credit'] as bool? ?? false,
          );
          debugPrint('Synced offline sale: ${item['description']}');
        } on FirebaseException catch (e) {
          // Still offline/unavailable; keep it.
          if (e.code == 'unavailable' || e.code == 'network-request-failed') {
            remaining.add(item);
            continue;
          }
          // Non-network error; keep it for now to avoid data loss.
          remaining.add({
            ...item,
            'last_error': e.message ?? e.code,
          });
        } catch (e) {
          remaining.add({
            ...item,
            'last_error': e.toString(),
          });
        }
      }

      await LocalStore.setPendingSales(remaining);
    } finally {
      _flushingSales = false;
    }
  }

  Future<void> tryFlushPendingPayments() async {
    if (_flushingPayments) return;
    if (_auth.currentUser == null) return;

    final pending = LocalStore.getPendingPayments();
    if (pending.isEmpty) return;

    _flushingPayments = true;
    try {
      final remaining = <Map<String, dynamic>>[];

      for (final item in pending) {
        try {
          await _firestore.recordCustomerPayment(
            customerId: item['customer_id'] as String,
            amount: (item['amount'] as num).toDouble(),
            note: item['note'] as String?,
          );
          debugPrint('Synced offline payment: ${item['amount']}');
        } on FirebaseException catch (e) {
          // Still offline/unavailable; keep it.
          if (e.code == 'unavailable' || e.code == 'network-request-failed') {
            remaining.add(item);
            continue;
          }
          // Non-network error; keep it for now to avoid data loss.
          remaining.add({
            ...item,
            'last_error': e.message ?? e.code,
          });
        } catch (e) {
          remaining.add({
            ...item,
            'last_error': e.toString(),
          });
        }
      }

      await LocalStore.setPendingPayments(remaining);
    } finally {
      _flushingPayments = false;
    }
  }
}
