import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/models/customer_model.dart';
import 'package:shop_app/providers/credit_provider.dart';
import 'package:shop_app/screens/customer_detail_screen.dart';
import 'package:shop_app/services/whatsapp_service.dart';
import 'package:shop_app/utils/app_theme.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CreditProvider>(context, listen: false).loadCustomers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    if (_searchQuery.isEmpty) return customers;
    final query = _searchQuery.toLowerCase();
    return customers.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Customer Ledger (Udhaar)', style: AppTheme.headingStyle.copyWith(fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Dues', icon: Icon(Icons.money_off)),
            Tab(text: 'All Customers', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: Consumer<CreditProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.customers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, Color(0xFF8B7CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Total Due',
                      '₹${provider.totalDue.toStringAsFixed(0)}',
                      Icons.account_balance_wallet,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    _buildSummaryItem(
                      'Customers with Due',
                      '${provider.customersWithDue.length}',
                      Icons.people_outline,
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomerList(
                      _filterCustomers(provider.customersWithDue),
                      emptyMessage: 'No pending dues! 🎉',
                    ),
                    _buildCustomerList(
                      _filterCustomers(provider.customers),
                      emptyMessage: 'No customers yet',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendBulkReminders,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.send, color: Colors.white),
        label: const Text('Send Reminders', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerList(List<Customer> customers, {required String emptyMessage}) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(emptyMessage, style: AppTheme.captionStyle),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => Provider.of<CreditProvider>(context, listen: false).loadCustomers(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return _buildCustomerCard(customer);
        },
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(customer: customer),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: customer.hasDue
                    ? AppTheme.errorColor.withValues(alpha: 0.1)
                    : AppTheme.secondaryColor.withValues(alpha: 0.1),
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: customer.hasDue ? AppTheme.errorColor : AppTheme.secondaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name.isEmpty ? 'Customer' : customer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      customer.phone,
                      style: AppTheme.captionStyle,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (customer.hasDue)
                    Text(
                      '₹${customer.balanceDue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  if (customer.hasDue)
                    const Text(
                      'due',
                      style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
                    ),
                  if (!customer.hasDue)
                    const Text(
                      'No dues',
                      style: TextStyle(color: AppTheme.secondaryColor, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              if (customer.hasDue)
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green, size: 20),
                  onPressed: () => _sendReminder(customer),
                  tooltip: 'Send WhatsApp Reminder',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendReminder(Customer customer) async {
    final sent = await WhatsAppService.sendPaymentReminder(
      phone: customer.phone,
      customerName: customer.name,
      amount: customer.balanceDue,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'WhatsApp opened for ${customer.name}'
              : 'Could not open WhatsApp',
        ),
        backgroundColor: sent ? Colors.green : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _sendBulkReminders() async {
    final provider = Provider.of<CreditProvider>(context, listen: false);
    final customersWithDue = provider.customersWithDue;

    if (customersWithDue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers with pending dues')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminders'),
        content: Text(
          'Send WhatsApp payment reminders to ${customersWithDue.length} customers?\n\n'
          'Note: You will need to send each message manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    for (final customer in customersWithDue) {
      await WhatsAppService.sendPaymentReminder(
        phone: customer.phone,
        customerName: customer.name,
        amount: customer.balanceDue,
      );
      // Small delay between opens
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
