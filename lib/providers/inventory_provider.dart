import 'package:flutter/material.dart';
import 'package:shop_app/models/product_model.dart';
import 'package:shop_app/services/firestore_service.dart';

class InventoryProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  final FirestoreService _firestore = FirestoreService();

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Product> get lowStockProducts =>
      _products.where((p) => p.stock <= p.lowStockThreshold).toList();

  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final productMaps = await _firestore.getProducts();
      _products = productMaps
          .map(
            (map) => Product.fromMap(
              map,
              id: map['id'] as String,
            ),
          )
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(
    String name,
    double price,
    int stock,
    String category,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestore.addProduct(
        name: name,
        price: price,
        stock: stock,
        category: category,
      );
      await fetchProducts(); // Refresh list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProduct(Product product) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestore.updateProduct(
        productId: product.id,
        fields: product.toMap(),
      );
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestore.deleteProduct(id);
      _products.removeWhere((p) => p.id == id);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
