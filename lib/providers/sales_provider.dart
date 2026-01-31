import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shop_app/services/firestore_service.dart';

class SalesProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _sales = [];
  bool _isLoading = true;
  double _totalSales = 0;
  double _todaySales = 0;
  int _todayTransactions = 0;
  List<Map<String, dynamic>> _weeklySales = [];

  // Platform Stats
  double _offlineSales = 0;
  double _whatsappSales = 0;
  double _onlineSales = 0;

  // Getters
  List<Map<String, dynamic>> get sales => _sales;
  bool get isLoading => _isLoading;
  double get totalSales => _totalSales;
  double get todaySales => _todaySales;
  int get todayTransactions => _todayTransactions;
  List<Map<String, dynamic>> get weeklySales => _weeklySales;
  double get offlineSales => _offlineSales;
  double get whatsappSales => _whatsappSales;
  double get onlineSales => _onlineSales;

  final FirestoreService _firestore = FirestoreService();

  DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final salesData = await _firestore.getSales();
      final weeklySalesData = await _firestore.getWeeklySales();

      // Calculate totals
      double total = 0;
      double today = 0;
      int todayCount = 0;

      double offline = 0;
      double whatsapp = 0;
      double online = 0;

      final now = DateTime.now();

      for (var sale in salesData) {
        double amount = (sale['amount'] as num).toDouble();
        bool isCredit = sale['is_credit'] == true;
        
        // Only count non-credit sales in totals (credit = receivables, not actual sales)
        if (!isCredit) {
          total += amount;
        }

        DateTime date = _asDateTime(sale['created_at']);
        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          // Only count non-credit sales in today's total
          if (!isCredit) {
            today += amount;
          }
          todayCount++;
        }

        // Platform Calculation (only for non-credit sales)
        if (!isCredit) {
          String platform = (sale['platform'] ?? 'Offline').toString();
          if (platform == 'WhatsApp') {
            whatsapp += amount;
          } else if (platform == 'Online') {
            online += amount;
          } else {
            offline += amount;
          }
        }
      }

      _sales = salesData;
      _totalSales = total;
      _todaySales = today;
      _todayTransactions = todayCount;
      _weeklySales = weeklySalesData;

      _offlineSales = offline;
      _whatsappSales = whatsapp;
      _onlineSales = online;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSale(String id) async {
    try {
      // Optimistic update: remove from list immediately
      _sales.removeWhere(
        (sale) => (sale['id']?.toString() ?? '') == id,
      );

      // Recalculate totals
      _calculateTotals();
      notifyListeners();

      await _firestore.deleteSale(id);

      // Reload to ensure sync (optional)
      await loadData();
    } catch (e) {
      debugPrint("Error deleting sale: $e");
      // Revert if needed, but for now just log
      await loadData(); // Reload to restore state if failed
    }
  }

  void _calculateTotals() {
    // Recalculate totals based on current _sales list
    double total = 0;
    double today = 0;
    int todayCount = 0;

    double offline = 0;
    double whatsapp = 0;
    double online = 0;

    final now = DateTime.now();

    for (var sale in _sales) {
      double amount = (sale['amount'] as num).toDouble();
      total += amount;

      DateTime date = _asDateTime(sale['created_at']);
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        today += amount;
        todayCount++;
      }

      String platform = (sale['platform'] ?? 'Offline').toString();
      if (platform == 'WhatsApp') {
        whatsapp += amount;
      } else if (platform == 'Online') {
        online += amount;
      } else {
        offline += amount;
      }
    }

    _totalSales = total;
    _todaySales = today;
    _todayTransactions = todayCount;
    _offlineSales = offline;
    _whatsappSales = whatsapp;
    _onlineSales = online;
  }
}
