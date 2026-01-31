import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/models/product_model.dart';
import 'package:shop_app/providers/inventory_provider.dart';
import 'package:shop_app/screens/add_product_screen.dart';
import 'package:shop_app/utils/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<InventoryProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          // Filtering logic
          List<Product> filteredProducts = provider.products;
          if (_searchQuery.isNotEmpty) {
            filteredProducts = provider.products
                .where(
                  (p) =>
                      p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
                )
                .toList();
          }

          return Column(
            children: [
              // Header & Search
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Inventory", style: AppTheme.headingStyle),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: AppTheme.primaryColor,
                          ),
                          onPressed: provider.fetchProducts,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        hintText: "Search products...",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Product List
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? "No products yet"
                                  : "No matches found",
                              style: AppTheme.captionStyle,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredProducts.length,
                      separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          final isLowStock =
                              product.stock <= product.lowStockThreshold;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isLowStock
                                      ? AppTheme.errorColor.withValues(
                                          alpha: 0.1,
                                        )
                                      : AppTheme.primaryColor.withValues(
                                          alpha: 0.1,
                                        ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: isLowStock
                                      ? AppTheme.errorColor
                                      : AppTheme.primaryColor,
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: AppTheme.subHeadingStyle.copyWith(
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                "Price: ₹${product.price}  •  ${product.category}",
                                style: AppTheme.captionStyle,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${product.stock}",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isLowStock
                                          ? AppTheme.errorColor
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "Units Left",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddProductScreen()),
        ),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Item", style: TextStyle(color: Colors.white)),
        elevation: 4,
      ),
    );
  }
}
