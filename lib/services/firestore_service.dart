import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }
    return user;
  }

  DocumentReference<Map<String, dynamic>> _userDoc([String? uid]) {
    return _firestore.collection('users').doc(uid ?? _user.uid);
  }

  CollectionReference<Map<String, dynamic>> _productsCol([String? uid]) {
    return _userDoc(uid).collection('products');
  }

  CollectionReference<Map<String, dynamic>> _salesCol([String? uid]) {
    return _userDoc(uid).collection('sales');
  }

  Future<void> ensureUserProfile({String? shopName}) async {
    final u = _user;
    await _userDoc().set(
      {
        'name': u.displayName ?? 'User',
        'email': u.email,
        'phone': u.phoneNumber,
        'shop_name': shopName ?? '',
        'gender': '',
        'address': '',
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final snap = await _userDoc().get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<void> updateUserProfile({required String name, required String shopName}) async {
    await upsertUserProfile({
      'name': name,
      'shop_name': shopName,
    });
  }

  Future<void> upsertUserProfile(Map<String, dynamic> fields) async {
    // Firestore supports nulls, but for profile edits it's usually cleaner to
    // delete optional fields when empty.
    final payload = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
    };

    for (final entry in fields.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) {
        payload[key] = FieldValue.delete();
      } else {
        payload[key] = value;
      }
    }

    await _userDoc().set(payload, SetOptions(merge: true));
  }

  static bool isProfileComplete(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final name = profile['name']?.toString().trim() ?? '';
    final shop = profile['shop_name']?.toString().trim() ?? '';
    final gender = profile['gender']?.toString().trim() ?? '';
    final phone = profile['phone']?.toString().trim() ?? '';
    return name.isNotEmpty && shop.isNotEmpty && gender.isNotEmpty && phone.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final q = await _productsCol().orderBy('name').get();
    return q.docs
        .map((d) => {
              'id': d.id,
              ...d.data(),
            })
        .toList();
  }

  Future<String> addProduct({
    required String name,
    required double price,
    required int stock,
    required String category,
    int lowStockThreshold = 5,
  }) async {
    final doc = await _productsCol().add({
      'name': name,
      'price': price,
      'stock': stock,
      'category': category,
      'low_stock_threshold': lowStockThreshold,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateProduct({
    required String productId,
    required Map<String, dynamic> fields,
  }) async {
    await _productsCol().doc(productId).set(
      {
        ...fields,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteProduct(String productId) async {
    await _productsCol().doc(productId).delete();
  }

  Future<List<Map<String, dynamic>>> getSales({int limit = 20}) async {
    final q = await _salesCol()
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();

    return q.docs
        .map((d) => {
              'id': d.id,
              ...d.data(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final q = await _salesCol()
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('created_at', descending: true)
        .get();

    return q.docs
        .map((d) => {
              'id': d.id,
              ...d.data(),
            })
        .toList();
  }

  Future<void> deleteSale(String saleId) async {
    await _salesCol().doc(saleId).delete();
  }

  /// Atomically:
  /// - decrements stock for each product in [cart] (productId -> quantity)
  /// - creates a sale record in `users/{uid}/sales`
  Future<void> addSaleAndUpdateStock({
    required double amount,
    required String description,
    required String paymentMode,
    required String platform,
    required Map<String, int> cart,
  }) async {
    if (cart.isEmpty) {
      throw ArgumentError('Cart is empty');
    }

    final salesDoc = _salesCol().doc();

    await _firestore.runTransaction((tx) async {
      final items = <Map<String, dynamic>>[];

      for (final entry in cart.entries) {
        final productRef = _productsCol().doc(entry.key);
        final productSnap = await tx.get(productRef);
        if (!productSnap.exists) {
          throw StateError('Product not found');
        }

        final product = productSnap.data() as Map<String, dynamic>;
        final currentStock = (product['stock'] as num?)?.toInt() ?? 0;
        final quantity = entry.value;

        if (quantity <= 0) continue;
        if (currentStock < quantity) {
          throw StateError('Insufficient stock for ${product['name'] ?? 'item'}');
        }

        tx.update(productRef, {
          'stock': currentStock - quantity,
          'updated_at': FieldValue.serverTimestamp(),
        });

        items.add({
          'product_id': entry.key,
          'name': product['name'],
          'price': product['price'],
          'quantity': quantity,
        });
      }

      tx.set(salesDoc, {
        'amount': amount,
        'description': description,
        'payment_mode': paymentMode,
        'platform': platform,
        'items': items,
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  }
}
