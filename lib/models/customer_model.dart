import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? phoneNormalized;
  final double balanceDue;
  final DateTime? lastSaleAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.phoneNormalized,
    required this.balanceDue,
    this.lastSaleAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasDue => balanceDue > 0;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'phone_normalized': phoneNormalized,
      'balance_due': balanceDue,
      'last_sale_at': lastSaleAt != null ? Timestamp.fromDate(lastSaleAt!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, {required String id}) {
    return Customer(
      id: id,
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      phoneNormalized: map['phone_normalized']?.toString(),
      balanceDue: (map['balance_due'] as num?)?.toDouble() ?? 0,
      lastSaleAt: _toDateTime(map['last_sale_at']),
      createdAt: _toDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: _toDateTime(map['updated_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? phoneNormalized,
    double? balanceDue,
    DateTime? lastSaleAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phoneNormalized: phoneNormalized ?? this.phoneNormalized,
      balanceDue: balanceDue ?? this.balanceDue,
      lastSaleAt: lastSaleAt ?? this.lastSaleAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LedgerEntry {
  final String id;
  final String type; // 'sale' or 'payment'
  final double amount;
  final String? saleId;
  final String? description;
  final String? note;
  final DateTime createdAt;

  LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    this.saleId,
    this.description,
    this.note,
    required this.createdAt,
  });

  bool get isSale => type == 'sale';
  bool get isPayment => type == 'payment';

  factory LedgerEntry.fromMap(Map<String, dynamic> map, {required String id}) {
    return LedgerEntry(
      id: id,
      type: (map['type'] ?? 'sale').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      saleId: map['sale_id']?.toString(),
      description: map['description']?.toString(),
      note: map['note']?.toString(),
      createdAt: Customer._toDateTime(map['created_at']) ?? DateTime.now(),
    );
  }
}
