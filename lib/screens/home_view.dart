import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/sales_provider.dart';
import 'package:shop_app/providers/credit_provider.dart';
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
