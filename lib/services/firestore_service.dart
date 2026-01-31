import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    debugPrint('=== FirestoreService.recordCustomerPayment ===');
    debugPrint('Customer ID: $customerId');
    debugPrint('Amount: $amount');
    
    if (amount <= 0) throw ArgumentError('Amount must be > 0');

    final customerRef = _customersCol().doc(customerId);
    final ledgerRef = customerRef.collection('ledger').doc();
    
    debugPrint('Customer ref path: ${customerRef.path}');
    debugPrint('Ledger ref path: ${ledgerRef.path}');

    await _firestore.runTransaction((tx) async {
      debugPrint('Transaction started...');
      // Read first to ensure customer exists (required before writes)
      final customerSnap = await tx.get(customerRef);
      if (!customerSnap.exists) {
        debugPrint('ERROR: Customer not found!');
        throw StateError('Customer not found');
      }
      
      final currentBalance = customerSnap.data()?['balance_due'] ?? 0.0;
      debugPrint('Current balance: $currentBalance');
      final newBalance = (currentBalance - amount).clamp(0, double.infinity);
      debugPrint('New balance will be: $newBalance');

      // Now perform writes
      tx.update(customerRef, {
        'balance_due': newBalance,
        'updated_at': FieldValue.serverTimestamp(),
      });

      tx.set(ledgerRef, {
        'type': 'payment',
        'amount': amount,
        'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Transaction writes prepared');
    });
    
    // Update credit sales for this customer - mark as paid if balance is 0
    debugPrint('Updating credit sales for customer...');
    final salesQuery = await _salesCol()
        .where('customer_id', isEqualTo: customerId)
        .where('is_credit', isEqualTo: true)
        .get();
    
    double remainingPayment = amount;
    for (final doc in salesQuery.docs) {
      if (remainingPayment <= 0) break;
      
      final saleData = doc.data();
      final amountDue = (saleData['amount_due'] ?? 0.0) as double;
      final amountPaid = (saleData['amount_paid'] ?? 0.0) as double;
      
      if (amountDue <= 0) continue;
      
      final paymentForThisSale = remainingPayment >= amountDue ? amountDue : remainingPayment;
      final newAmountDue = amountDue - paymentForThisSale;
      final newAmountPaid = amountPaid + paymentForThisSale;
      
      debugPrint('Updating sale ${doc.id}: amountDue $amountDue -> $newAmountDue');
      
      await doc.reference.update({
        'amount_due': newAmountDue,
        'amount_paid': newAmountPaid,
        'is_credit': newAmountDue > 0, // Mark as not credit if fully paid
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      remainingPayment -= paymentForThisSale;
    }
    
    debugPrint('Payment transaction completed successfully!');
  }

  Future<void> ensureUserProfile({String? shopName}) async {
    final docRef = _userDoc();
    final snap = await docRef.get();
    
    // Only create if document doesn't exist - don't overwrite existing profile
    if (!snap.exists) {
      final u = _user;
      await docRef.set({
        'name': u.displayName ?? '',
        'email': u.email ?? '',
        'phone': u.phoneNumber ?? '',
        'shop_name': shopName ?? '',
        'gender': '',
        'address': '',
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });
    }
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
      // PHASE 1: Read all products first (Firestore requires all reads before writes)
      final productRefs = <DocumentReference<Map<String, dynamic>>>[];
      final productSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      
      for (final productId in cart.keys) {
        final productRef = _productsCol().doc(productId);
        productRefs.add(productRef);
        final snap = await tx.get(productRef);
        productSnapshots.add(snap);
      }

      // PHASE 2: Validate all products and prepare items
      final items = <Map<String, dynamic>>[];
      final stockUpdates = <DocumentReference<Map<String, dynamic>>, int>{};
      
      int index = 0;
      for (final entry in cart.entries) {
        final productSnap = productSnapshots[index];
        final productRef = productRefs[index];
        index++;
        
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

        stockUpdates[productRef] = currentStock - quantity;

        items.add({
          'product_id': entry.key,
          'name': product['name'],
          'price': product['price'],
          'quantity': quantity,
        });
      }

      // PHASE 3: Perform all writes
      for (final update in stockUpdates.entries) {
        tx.update(update.key, {
          'stock': update.value,
          'updated_at': FieldValue.serverTimestamp(),
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
        debugPrint('Creating credit sale - customerId: $customerId, amount: $amount');
        final customerRef = _customersCol().doc(customerId);
        final ledgerRef = customerRef.collection('ledger').doc();
        debugPrint('Ledger ref path: ${ledgerRef.path}');

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

        debugPrint('Setting ledger entry: type=sale, amount=$amount, sale_id=${salesDoc.id}');
        tx.set(ledgerRef, {
          'type': 'sale',
          'amount': amount,
          'sale_id': salesDoc.id,
          'description': description,
          'created_at': FieldValue.serverTimestamp(),
        });
        debugPrint('Credit sale transaction prepared');
      }
    });
    debugPrint('Transaction completed');
  }

  /// Converts an existing sale to a credit (Udhaar) sale
  Future<void> convertSaleToCredit({
    required String saleId,
    required String customerId,
    required String customerName,
    required String customerPhone,
  }) async {
    final saleRef = _salesCol().doc(saleId);
    final customerRef = _customersCol().doc(customerId);
    final ledgerRef = customerRef.collection('ledger').doc();

    await _firestore.runTransaction((tx) async {
      // Read first
      final saleSnap = await tx.get(saleRef);
      if (!saleSnap.exists) {
        throw StateError('Sale not found');
      }

      final saleData = saleSnap.data()!;
      final amount = (saleData['amount'] as num?)?.toDouble() ?? 0;
      final description = saleData['description']?.toString() ?? '';

      // Update sale to be credit
      tx.update(saleRef, {
        'is_credit': true,
        'amount_due': amount,
        'amount_paid': 0,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update/create customer with balance
      tx.set(
        customerRef,
        {
          'name': customerName.trim(),
          'phone': customerPhone.trim(),
          'phone_normalized': _normalizePhone(customerPhone) ?? FieldValue.delete(),
          'balance_due': FieldValue.increment(amount),
          'last_sale_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Add ledger entry
      tx.set(ledgerRef, {
        'type': 'sale',
        'amount': amount,
        'sale_id': saleId,
        'description': description,
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Deletes all user data including subcollections
  Future<void> deleteUserData() async {
    final userDocRef = _userDoc();
    
    // Delete products subcollection
    final productsSnap = await _productsCol().get();
    for (final doc in productsSnap.docs) {
      await doc.reference.delete();
    }
    
    // Delete sales subcollection
    final salesSnap = await _salesCol().get();
    for (final doc in salesSnap.docs) {
      await doc.reference.delete();
    }
    
    // Delete customers and their ledgers
    final customersSnap = await _customersCol().get();
    for (final customerDoc in customersSnap.docs) {
      // Delete ledger subcollection for each customer
      final ledgerSnap = await customerDoc.reference.collection('ledger').get();
      for (final ledgerDoc in ledgerSnap.docs) {
        await ledgerDoc.reference.delete();
      }
      await customerDoc.reference.delete();
    }
    
    // Finally delete the user document
    await userDocRef.delete();
  }
}
