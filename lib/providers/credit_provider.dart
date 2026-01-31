import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shop_app/models/customer_model.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/services/local_store.dart';
import 'package:shop_app/services/offline_sync_service.dart';

class CreditProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  List<Customer> _customersWithDue = [];
  bool _isLoading = false;
  String? _error;
  double _totalDue = 0;

  final FirestoreService _firestore = FirestoreService();

  // Getters
  List<Customer> get customers => _customers;
  List<Customer> get customersWithDue => _customersWithDue;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get totalDue => _totalDue;

  Future<void> loadCustomers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use stream snapshot once.
      final customersData = await _firestore.watchCustomers().first;
      _customers = customersData.map((m) => Customer.fromMap(m, id: m['id'] as String)).toList();

      // Filter customers with dues
      _customersWithDue = _customers.where((c) => c.balanceDue > 0).toList();

      // Calculate total due
      _totalDue = _customersWithDue.fold(0, (total, c) => total + c.balanceDue);

      // Cache for offline
      await LocalStore.setCachedCustomers(customersData);
    } catch (e) {
      _error = e.toString();

      // Fallback to cached
      final cached = LocalStore.getCachedCustomers();
      if (cached.isNotEmpty) {
        _customers = cached.map((m) => Customer.fromMap(m, id: m['id'] as String)).toList();
        _customersWithDue = _customers.where((c) => c.balanceDue > 0).toList();
        _totalDue = _customersWithDue.fold(0, (total, c) => total + c.balanceDue);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> recordPayment({
    required String customerId,
    required double amount,
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestore.recordCustomerPayment(
        customerId: customerId,
        amount: amount,
        note: note,
      );
      await loadCustomers(); // Refresh the list
    } on FirebaseException catch (e) {
      // Offline fallback - queue the payment for later sync
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        await OfflineSyncService().enqueuePayment({
          'customer_id': customerId,
          'amount': amount,
          'note': note,
          'created_at_ms': DateTime.now().millisecondsSinceEpoch,
        });
        
        // Optimistically update local state
        final index = _customers.indexWhere((c) => c.id == customerId);
        if (index != -1) {
          final customer = _customers[index];
          _customers[index] = customer.copyWith(
            balanceDue: (customer.balanceDue - amount).clamp(0, double.infinity),
          );
          _customersWithDue = _customers.where((c) => c.balanceDue > 0).toList();
          _totalDue = _customersWithDue.fold(0, (total, c) => total + c.balanceDue);
        }
        
        _isLoading = false;
        notifyListeners();
        return; // Don't rethrow - handled as offline
      }
      _error = e.toString();
      rethrow;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Customer?> getCustomer(String customerId) async {
    try {
      final data = await _firestore.getCustomer(customerId);
      if (data == null) return null;
      return Customer.fromMap(data, id: data['id'] as String);
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  Future<List<LedgerEntry>> getLedger(String customerId) async {
    try {
      final ledgerData = await _firestore.watchCustomerLedger(customerId).first;
      return ledgerData.map((m) => LedgerEntry.fromMap(m, id: m['id'] as String)).toList();
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }
}
