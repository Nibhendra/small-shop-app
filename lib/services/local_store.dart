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
}
