import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/models/product_model.dart';
import 'package:shop_app/providers/inventory_provider.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/utils/app_theme.dart';
import 'package:shop_app/widgets/custom_button.dart';
import 'package:shop_app/widgets/custom_textfield.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _amountController = TextEditingController(text: '0.00');
  final _descriptionController = TextEditingController();

  String _paymentMode = 'Cash';
  String _platform = 'Offline';
  bool _isLoading = false;

  // productId -> quantity
  final Map<String, int> _cart = {};

  final FirestoreService _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<InventoryProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Product? _findProduct(InventoryProvider provider, String productId) {
    try {
      return provider.products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  void _calculateTotal() {
    double total = 0;
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    for (final entry in _cart.entries) {
      final product = _findProduct(provider, entry.key);
      if (product == null) continue;
      total += product.price * entry.value;
    }

    _amountController.text = total.toStringAsFixed(2);
  }

  void _addItem(Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Out of stock')),
      );
      return;
    }

    final currentQty = _cart[product.id] ?? 0;
    if (currentQty >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum stock reached')),
      );
      return;
    }

    setState(() {
      _cart[product.id] = currentQty + 1;
      _calculateTotal();
    });
  }

  void _removeItem(Product product) {
    if (!_cart.containsKey(product.id)) return;

    setState(() {
      final current = _cart[product.id] ?? 0;
      if (current <= 1) {
        _cart.remove(product.id);
      } else {
        _cart[product.id] = current - 1;
      }
      _calculateTotal();
    });
  }

  Future<void> _submitSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<InventoryProvider>(context, listen: false);

      String description = _descriptionController.text.trim();
      if (description.isEmpty) {
        final parts = <String>[];
        for (final entry in _cart.entries) {
          final product = _findProduct(provider, entry.key);
          if (product == null) continue;
          parts.add('${product.name} (${entry.value})');
        }
        description = parts.isEmpty ? 'Sale' : 'Sale: ${parts.join(', ')}';
      }

      await _firestore.addSaleAndUpdateStock(
        amount: double.tryParse(_amountController.text) ?? 0,
        description: description,
        paymentMode: _paymentMode,
        platform: _platform,
        cart: _cart,
      );

      await provider.fetchProducts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale added successfully'),
          backgroundColor: AppTheme.secondaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProductGrid({required int crossAxisCount}) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.products.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.products.isEmpty) {
          return const Center(child: Text('No products yet'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: provider.products.length,
          itemBuilder: (context, index) {
            final product = provider.products[index];
            final qtyInCart = _cart[product.id] ?? 0;
            final isOut = product.stock <= 0;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isOut ? null : () => _addItem(product),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        qtyInCart > 0 ? AppTheme.primaryColor : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.10),
                        child: Text(
                          product.name.isNotEmpty
                              ? product.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text('₹${product.price.toStringAsFixed(0)}'),
                      const SizedBox(height: 4),
                      Text(
                        isOut ? 'Out of Stock' : 'Stock: ${product.stock}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isOut ? Colors.red : Colors.grey,
                        ),
                      ),
                      if (qtyInCart > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$qtyInCart selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartContent({required bool scrollable}) {
    final paymentModes = const ['Cash', 'UPI', 'Card'];
    final platforms = const ['Offline', 'Online'];

    final cartList = Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        if (_cart.isEmpty) {
          return const Center(child: Text('Cart is empty'));
        }
        return ListView.separated(
          shrinkWrap: !scrollable,
          physics: scrollable ? null : const NeverScrollableScrollPhysics(),
          itemCount: _cart.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final productId = _cart.keys.elementAt(index);
            final quantity = _cart.values.elementAt(index);
            final product = _findProduct(provider, productId);
            if (product == null) return const SizedBox.shrink();

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text('₹${product.price} x $quantity'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: _isLoading ? null : () => _removeItem(product),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: _isLoading ? null : () => _addItem(product),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final totalsRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          '₹${_amountController.text}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );

    final paymentChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in paymentModes)
          ChoiceChip(
            label: Text(mode),
            selected: _paymentMode == mode,
            onSelected: _isLoading
                ? null
                : (_) {
                    setState(() => _paymentMode = mode);
                  },
          ),
      ],
    );

    final platformChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in platforms)
          ChoiceChip(
            label: Text(p),
            selected: _platform == p,
            onSelected: _isLoading
                ? null
                : (_) {
                    setState(() => _platform = p);
                  },
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cart', style: AppTheme.headingStyle.copyWith(fontSize: 20)),
        const SizedBox(height: 8),
        const Divider(),
        if (scrollable)
          Expanded(child: cartList)
        else
          cartList,
        const Divider(),
        totalsRow,
        const SizedBox(height: 16),
        Text('Payment mode', style: AppTheme.captionStyle),
        const SizedBox(height: 8),
        paymentChips,
        const SizedBox(height: 12),
        Text('Platform', style: AppTheme.captionStyle),
        const SizedBox(height: 8),
        platformChips,
        const SizedBox(height: 16),
        CustomTextField(
          controller: _descriptionController,
          label: 'Customer / Notes',
          prefixIcon: Icons.notes_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Complete Sale',
          onPressed: _isLoading ? null : _submitSale,
          isLoading: _isLoading,
          icon: Icons.check_circle_outline,
        ),
      ],
    );
  }

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.80,
              child: _buildCartContent(scrollable: true),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('New Sale', style: AppTheme.headingStyle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final crossAxisCount = constraints.maxWidth >= 700 ? 3 : 2;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Select Items', style: AppTheme.subHeadingStyle),
                      ),
                      const SizedBox(height: 10),
                      Expanded(child: _buildProductGrid(crossAxisCount: crossAxisCount)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: _buildCartContent(scrollable: true),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: _buildProductGrid(crossAxisCount: crossAxisCount)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: AppTheme.captionStyle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${_amountController.text}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _cart.isEmpty || _isLoading ? null : _openCartSheet,
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text('Cart (${_cart.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
