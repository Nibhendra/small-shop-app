import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/sales_provider.dart';
import 'package:shop_app/providers/credit_provider.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/utils/app_theme.dart';
import 'package:shop_app/widgets/dashboard_card.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  void _showTransactionDetail(BuildContext context, Map<String, dynamic> sale) {
    final isCredit = sale['is_credit'] == true;
    final items = (sale['items'] as List<dynamic>?) ?? [];
    final customerName = sale['customer_name']?.toString() ?? '';
    final customerPhone = sale['customer_phone']?.toString() ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCredit
                            ? AppTheme.errorColor.withValues(alpha: 0.1)
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit ? Icons.access_time : Icons.receipt_long,
                        color: isCredit ? AppTheme.errorColor : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCredit ? 'Credit Sale (Udhaar)' : 'Sale',
                            style: AppTheme.subHeadingStyle,
                          ),
                          Text(
                            DateFormat('MMMM d, yyyy • h:mm a').format(
                              _asDateTime(sale['created_at']),
                            ),
                            style: AppTheme.captionStyle,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${sale['amount']}',
                      style: AppTheme.headingStyle.copyWith(
                        color: isCredit ? AppTheme.errorColor : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                
                // Transaction Info
                _buildInfoRow('Payment Mode', sale['payment_mode'] ?? 'Cash'),
                _buildInfoRow('Platform', sale['platform'] ?? 'Offline'),
                if (sale['description']?.toString().isNotEmpty == true)
                  _buildInfoRow('Description', sale['description']),
                
                // Customer info for credit sales
                if (isCredit && customerName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Customer', style: AppTheme.captionStyle),
                  const SizedBox(height: 8),
                  _buildInfoRow('Name', customerName),
                  if (customerPhone.isNotEmpty) _buildInfoRow('Phone', customerPhone),
                ],
                
                // Items
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Items', style: AppTheme.captionStyle),
                  const SizedBox(height: 8),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item['name']} x${item['quantity']}',
                            style: AppTheme.bodyStyle,
                          ),
                        ),
                        Text(
                          '₹${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(0)}',
                          style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )),
                ],
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    // Convert to Udhaar button (only for non-credit sales)
                    if (!isCredit)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _convertToUdhaar(context, sale);
                          },
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text('Convert to Udhaar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: const BorderSide(color: AppTheme.errorColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    
                    // Record Payment button (only for credit sales)
                    if (isCredit && sale['customer_id'] != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _recordPayment(context, sale);
                          },
                          icon: const Icon(Icons.payments),
                          label: const Text('Record Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, sale);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete Transaction'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.captionStyle),
          Text(value, style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _convertToUdhaar(BuildContext context, Map<String, dynamic> sale) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Udhaar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter customer details for this credit sale:'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone (+91...)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              
              if (name.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid customer name')),
                );
                return;
              }
              if (!phone.startsWith('+')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone must start with + (e.g. +91...)')),
                );
                return;
              }
              
              Navigator.pop(ctx);
              
              try {
                final firestore = FirestoreService();
                final customerId = await firestore.upsertCustomer(
                  name: name,
                  phone: phone,
                );
                
                // Update the sale to be credit
                await firestore.convertSaleToCredit(
                  saleId: sale['id'],
                  customerId: customerId,
                  customerName: name,
                  customerPhone: phone,
                );
                
                // Refresh data
                if (context.mounted) {
                  Provider.of<SalesProvider>(context, listen: false).loadData();
                  Provider.of<CreditProvider>(context, listen: false).loadCustomers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sale converted to Udhaar'),
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Convert'),
          ),
        ],
      ),
    );
  }

  void _recordPayment(BuildContext context, Map<String, dynamic> sale) {
    final amountController = TextEditingController(
      text: (sale['amount_due'] ?? sale['amount']).toString(),
    );
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Customer: ${sale['customer_name'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount Received',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
                return;
              }
              
              Navigator.pop(ctx);
              
              try {
                await FirestoreService().recordCustomerPayment(
                  customerId: sale['customer_id'],
                  amount: amount,
                );
                
                if (context.mounted) {
                  Provider.of<SalesProvider>(context, listen: false).loadData();
                  Provider.of<CreditProvider>(context, listen: false).loadCustomers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment of ₹$amount recorded'),
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<SalesProvider>(context, listen: false)
                  .deleteSale(sale['id']);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sale deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesProvider>(
      builder: (context, salesProvider, child) {
        if (salesProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async => salesProvider.loadData(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dashboard Cards Row
                SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      SizedBox(
                        width: 250,
                        child: DashboardCard(
                          title: "Total Sales",
                          value:
                              "₹ ${salesProvider.totalSales.toStringAsFixed(0)}",
                          icon: Icons.currency_rupee,
                          color: const Color(0xFF5B67F1),
                          subtitle: "All time earnings",
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 250,
                        child: DashboardCard(
                          title: "Today's Sales",
                          value:
                              "₹ ${salesProvider.todaySales.toStringAsFixed(0)}",
                          icon: Icons.trending_up,
                          color: const Color(0xFF5ABF77),
                          subtitle: "Earned today",
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 250,
                        child: DashboardCard(
                          title: "Transactions",
                          value: "${salesProvider.todayTransactions}",
                          icon: Icons.shopping_cart_outlined,
                          color: const Color(0xFF8C52FF),
                          subtitle: "Orders today",
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Credit/Udhaar Card
                      Consumer<CreditProvider>(
                        builder: (context, creditProvider, _) {
                          return SizedBox(
                            width: 250,
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/ledger'),
                              child: DashboardCard(
                                title: "Udhaar/Credit",
                                value:
                                    "₹ ${creditProvider.totalDue.toStringAsFixed(0)}",
                                icon: Icons.account_balance_wallet,
                                color: creditProvider.totalDue > 0
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF43A047),
                                subtitle: creditProvider.customersWithDue.isEmpty
                                    ? "No pending dues"
                                    : "${creditProvider.customersWithDue.length} customers owe",
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Recent Transactions",
                      style: AppTheme.subHeadingStyle,
                    ),
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                salesProvider.sales.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.storefront,
                                size: 64,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No sales yet\nAdd your first sale to get started",
                                textAlign: TextAlign.center,
                                style: AppTheme.captionStyle,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: salesProvider.sales.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final sale = salesProvider.sales[index];
                          return Container(
                            decoration: AppTheme.cardDecoration.copyWith(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [],
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _showTransactionDetail(context, sale),
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Delete Sale"),
                                    content: const Text(
                                      "Are you sure you want to delete this sale? This action cannot be undone.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          final id = (sale['id'] ?? '').toString();

                                          Provider.of<SalesProvider>(
                                            context,
                                            listen: false,
                                          ).deleteSale(id);

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                "Sale deleted",
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              margin: const EdgeInsets.only(
                                                bottom: 80,
                                                left: 24,
                                                right: 24,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: sale['is_credit'] == true
                                      ? AppTheme.errorColor.withValues(alpha: 0.1)
                                      : sale['payment_mode'] == 'UPI'
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : AppTheme.primaryColor.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  sale['is_credit'] == true
                                      ? Icons.access_time
                                      : sale['payment_mode'] == 'UPI'
                                          ? Icons.qr_code
                                          : sale['payment_mode'] == 'Card'
                                              ? Icons.credit_card
                                              : Icons.money,
                                  color: sale['is_credit'] == true
                                      ? AppTheme.errorColor
                                      : sale['payment_mode'] == 'UPI'
                                          ? Colors.green
                                          : AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sale['description']?.toString().isNotEmpty ==
                                              true
                                          ? sale['description']
                                          : "Sale",
                                      style: AppTheme.bodyStyle.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (sale['is_credit'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'CREDIT',
                                        style: TextStyle(
                                          color: AppTheme.errorColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                "${sale['platform'] ?? 'Offline'} • ${DateFormat('MMM d, h:mm a').format(_asDateTime(sale['created_at']))}",
                                style: AppTheme.captionStyle.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Text(
                                "₹ ${sale['amount']}",
                                style: AppTheme.subHeadingStyle.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
