class Product {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String category;
  final int lowStockThreshold;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    this.lowStockThreshold = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'stock': stock,
      'category': category,
      'low_stock_threshold': lowStockThreshold,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, {required String id}) {
    return Product(
      id: id,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      stock: map['stock'] as int,
      category: map['category'] as String,
      lowStockThreshold: map['low_stock_threshold'] as int? ?? 5,
    );
  }
}
