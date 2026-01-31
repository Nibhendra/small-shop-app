import 'package:hive_flutter/hive_flutter.dart';

class LocalStore {
  static const String _boxName = 'vyapaar_store';

  static Box<dynamic>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  static Box<dynamic> get _b {
    final box = _box;
    if (box == null) {
      throw StateError('LocalStore not initialized. Call LocalStore.init() first.');
    }
    return box;
  }

  // ==================== PRODUCTS ====================

  static List<Map<String, dynamic>> getCachedProducts() {
    final raw = _b.get('products');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  static Future<void> setCachedProducts(List<Map<String, dynamic>> products) async {
    await _b.put('products', products);
  }

  // ==================== PENDING SALES (OFFLINE) ====================

  static List<Map<String, dynamic>> getPendingSales() {
    final raw = _b.get('pending_sales');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  static Future<void> setPendingSales(List<Map<String, dynamic>> sales) async {
    await _b.put('pending_sales', sales);
  }

  // ==================== CUSTOMERS (UDHAAR) ====================

  static List<Map<String, dynamic>> getCachedCustomers() {
    final raw = _b.get('customers');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  static Future<void> setCachedCustomers(List<Map<String, dynamic>> customers) async {
    await _b.put('customers', customers);
  }

  // ==================== PENDING PAYMENTS (OFFLINE) ====================

  static List<Map<String, dynamic>> getPendingPayments() {
    final raw = _b.get('pending_payments');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  static Future<void> setPendingPayments(List<Map<String, dynamic>> payments) async {
    await _b.put('pending_payments', payments);
  }

  static Future<void> addPendingPayment(Map<String, dynamic> payment) async {
    final current = getPendingPayments();
    current.add(payment);
    await setPendingPayments(current);
  }

  // ==================== CACHED SALES ====================

  static List<Map<String, dynamic>> getCachedSales() {
    final raw = _b.get('sales');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  static Future<void> setCachedSales(List<Map<String, dynamic>> sales) async {
    await _b.put('sales', sales);
  }

  // ==================== LAST SYNC TIMESTAMP ====================

  static DateTime? getLastSyncTime() {
    final ms = _b.get('last_sync_ms');
    if (ms is int) {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return null;
  }

  static Future<void> setLastSyncTime(DateTime time) async {
    await _b.put('last_sync_ms', time.millisecondsSinceEpoch);
  }

  // ==================== OFFLINE MODE STATUS ====================

  static bool isOfflineMode() {
    return _b.get('offline_mode', defaultValue: false) as bool;
  }

  static Future<void> setOfflineMode(bool value) async {
    await _b.put('offline_mode', value);
  }

  // ==================== TWILIO WHATSAPP SANDBOX ====================

  /// Get the set of phone numbers that have joined the Twilio WhatsApp sandbox
  static Set<String> getTwilioJoinedPhones() {
    final raw = _b.get('twilio_joined_phones');
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return {};
  }

  /// Check if a phone number has joined the Twilio WhatsApp sandbox
  static bool hasTwilioJoined(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return getTwilioJoinedPhones().contains(normalized);
  }

  /// Mark a phone number as having joined the Twilio WhatsApp sandbox
  static Future<void> setTwilioJoined(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final phones = getTwilioJoinedPhones();
    phones.add(normalized);
    await _b.put('twilio_joined_phones', phones.toList());
  }
}
