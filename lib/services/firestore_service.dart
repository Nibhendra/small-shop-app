import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static String? _normalizeEmail(String? email) {
    final e = email?.trim();
    if (e == null || e.isEmpty) return null;
    return e.toLowerCase();
  }

  static String? _normalizePhone(String? phone) {
    final p = phone?.trim();
    if (p == null || p.isEmpty) return null;
    // Keep leading '+', remove common separators/spaces.
    final cleaned = p.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return cleaned;
  }

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

  CollectionReference<Map<String, dynamic>> _customersCol([String? uid]) {
    return _userDoc(uid).collection('customers');
  }

  String _customerIdFromPhone(String phoneE164) {
    final normalized = _normalizePhone(phoneE164) ?? '';
    if (!normalized.startsWith('+') || normalized.length < 8) {
      // Fall back to a random id if phone is invalid.
      return 'c_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
    }
    return normalized.substring(1); // drop '+'
  }

  Future<String> upsertCustomer({
    required String name,
    required String phone,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone == null || !normalizedPhone.startsWith('+')) {
      throw ArgumentError('Customer phone must be in E.164 format.');
    }

    final id = _customerIdFromPhone(normalizedPhone);
    final ref = _customersCol().doc(id);

    await ref.set(
      {
        'name': name.trim(),
        'phone': phone.trim(),
        'phone_normalized': normalizedPhone,
        'balance_due': FieldValue.increment(0),
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return id;
  }

  Future<Map<String, dynamic>?> getCustomer(String customerId) async {
    final snap = await _customersCol().doc(customerId).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...?snap.data()};
  }

  Future<Map<String, dynamic>?> getCustomerByPhone(String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone == null) return null;

    final q = await _customersCol()
        .where('phone_normalized', isEqualTo: normalizedPhone)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return {'id': q.docs.first.id, ...q.docs.first.data()};
  }

  Stream<List<Map<String, dynamic>>> watchCustomers({bool onlyDue = false}) {
    Query<Map<String, dynamic>> q = _customersCol().orderBy('updated_at', descending: true);
    if (onlyDue) {
      q = q.where('balance_due', isGreaterThan: 0);
    }
    return q.snapshots().map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList(growable: false),
        );
  }

  Stream<List<Map<String, dynamic>>> watchCustomerLedger(String customerId) {
    return _customersCol()
        .doc(customerId)
        .collection('ledger')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList(growable: false),
        );
  }

  Future<void> recordCustomerPayment({
    required String customerId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) throw ArgumentError('Amount must be > 0');

    final customerRef = _customersCol().doc(customerId);
    final ledgerRef = customerRef.collection('ledger').doc();

    await _firestore.runTransaction((tx) async {
      tx.update(customerRef, {
        'balance_due': FieldValue.increment(-amount),
        'updated_at': FieldValue.serverTimestamp(),
      });

      tx.set(ledgerRef, {
        'type': 'payment',
        'amount': amount,
        'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });
    });
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

        if (key == 'email') {
          payload['email_lower'] = FieldValue.delete();
        }
        if (key == 'phone') {
          payload['phone_normalized'] = FieldValue.delete();
        }
      } else {
        payload[key] = value;

        if (key == 'email') {
          final normalized = _normalizeEmail(value.toString());
          payload['email_lower'] = normalized ?? FieldValue.delete();
        }
        if (key == 'phone') {
          final normalized = _normalizePhone(value.toString());
          payload['phone_normalized'] = normalized ?? FieldValue.delete();
        }
      }
    }

    await _userDoc().set(payload, SetOptions(merge: true));
  }

  Future<void> assertUniqueContact({String? email, String? phone}) async {
    final uid = _user.uid;

    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail != null) {
      final q = await _firestore
          .collection('users')
          .where('email_lower', isEqualTo: normalizedEmail)
          .limit(2)
          .get();

      final conflict = q.docs.any((d) => d.id != uid);
      if (conflict) {
        throw StateError('Email address is already in use.');
      }
    }

    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone != null) {
      final q = await _firestore
          .collection('users')
          .where('phone_normalized', isEqualTo: normalizedPhone)
          .limit(2)
          .get();

      final conflict = q.docs.any((d) => d.id != uid);
      if (conflict) {
        throw StateError('Phone number is already in use.');
      }
    }
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
    String? customerId,
    String? customerName,
    String? customerPhone,
    bool isCredit = false,
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
        'is_credit': isCredit,
        if (isCredit) ...{
          'amount_due': amount,
          'amount_paid': 0,
          'customer_id': customerId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
        },
        'items': items,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (isCredit) {
        if (customerId == null || customerId.trim().isEmpty) {
          throw StateError('Customer is required for Pay Later');
        }
        final customerRef = _customersCol().doc(customerId);
        final ledgerRef = customerRef.collection('ledger').doc();

        tx.set(
          customerRef,
          {
            'name': (customerName ?? '').trim(),
            'phone': (customerPhone ?? '').trim(),
            'phone_normalized': _normalizePhone(customerPhone) ?? FieldValue.delete(),
            'balance_due': FieldValue.increment(amount),
            'last_sale_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
            'created_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.set(ledgerRef, {
          'type': 'sale',
          'amount': amount,
          'sale_id': salesDoc.id,
          'description': description,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
