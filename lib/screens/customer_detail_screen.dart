import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/models/customer_model.dart';
import 'package:shop_app/providers/credit_provider.dart';
import 'package:shop_app/providers/sales_provider.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/utils/app_theme.dart';
import 'package:shop_app/widgets/custom_button.dart';
import 'package:shop_app/widgets/custom_textfield.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<LedgerEntry> _ledger = [];
  bool _isLoading = true;
  Customer? _currentCustomer;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('=== Loading customer detail ===');
      debugPrint('Customer ID: ${widget.customer.id}');
      debugPrint('Customer Name: ${widget.customer.name}');
      debugPrint('Customer Phone: ${widget.customer.phone}');
      
      // Refresh customer data
      final customerData = await _firestore.getCustomer(widget.customer.id);
      debugPrint('Customer data from Firestore: $customerData');
      if (customerData != null) {
        _currentCustomer = Customer.fromMap(customerData, id: customerData['id'] as String);
        debugPrint('Current customer balance: ${_currentCustomer?.balanceDue}');
      }

      // Load ledger
      debugPrint('Loading ledger for customer ID: ${widget.customer.id}');
      final ledgerData = await _firestore.watchCustomerLedger(widget.customer.id).first;
      debugPrint('Raw ledger data: $ledgerData');
      debugPrint('Ledger count: ${ledgerData.length}');
      
      _ledger = ledgerData.map((m) {
        debugPrint('Parsing ledger entry: $m');
        return LedgerEntry.fromMap(m, id: m['id'] as String);
      }).toList();
      
      debugPrint('Parsed ledger entries: ${_ledger.length}');
      for (var entry in _ledger) {
        debugPrint('Entry: type=${entry.type}, amount=${entry.amount}, desc=${entry.description}');
      }
    } catch (e, stack) {
      debugPrint('Error loading customer data: $e');
      debugPrint('Stack trace: $stack');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRecordPaymentDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Record Payment',
                    style: AppTheme.headingStyle.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From: ${_currentCustomer?.name ?? 'Customer'}',
                    style: AppTheme.captionStyle,
                  ),
                  Text(
                    'Current Due: ₹${_currentCustomer?.balanceDue.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: amountController,
                    label: 'Payment Amount (₹)',
                    prefixIcon: Icons.currency_rupee,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: noteController,
                    label: 'Note (optional)',
                    prefixIcon: Icons.notes,
                  ),
                  const SizedBox(height: 8),
                  // Quick amount buttons
                  Wrap(
                    spacing: 8,
                    children: [
                      _quickAmountChip(amountController, 100),
                      _quickAmountChip(amountController, 500),
                      _quickAmountChip(amountController, 1000),
                      if (_currentCustomer != null && _currentCustomer!.balanceDue > 0)
                        ActionChip(
                          label: Text('Full: ₹${_currentCustomer!.balanceDue.toStringAsFixed(0)}'),
                          onPressed: () {
                            amountController.text = _currentCustomer!.balanceDue.toStringAsFixed(0);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Record Payment',
                    onPressed: isProcessing
                        ? null
                        : () async {
                            debugPrint('=== Record Payment Button Pressed ===');
                            final amount = double.tryParse(amountController.text.trim()) ?? 0;
                            debugPrint('Amount entered: $amount');
                            if (amount <= 0) {
                              debugPrint('Invalid amount, showing error');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a valid amount'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                              return;
                            }

                            debugPrint('Starting payment recording...');
                            setModalState(() => isProcessing = true);

                            try {
                              debugPrint('Calling CreditProvider.recordPayment...');
                              debugPrint('Customer ID: ${widget.customer.id}');
                              debugPrint('Amount: $amount');
                              await Provider.of<CreditProvider>(context, listen: false)
                                  .recordPayment(
                                customerId: widget.customer.id,
                                amount: amount,
                                note: noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                              );
                              debugPrint('Payment recorded successfully!');

                              if (!mounted) return;
                              Navigator.pop(ctx);
                              
                              // Refresh sales data so home view updates
                              debugPrint('Refreshing SalesProvider...');
                              if (mounted) {
                                Provider.of<SalesProvider>(context, listen: false).loadData();
                              }
                              
                              debugPrint('Reloading customer data...');
                              await _loadData();
                              debugPrint('Customer data reloaded!');
                              
                              // Check if balance is now 0, pop back to ledger
                              if (_currentCustomer != null && _currentCustomer!.balanceDue <= 0) {
                                debugPrint('Balance is 0, going back to ledger');
                                if (mounted) {
                                  Navigator.of(context).pop(true); // Return true to indicate refresh needed
                                }
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment recorded successfully'),
                                  backgroundColor: AppTheme.secondaryColor,
                                ),
                              );
                            } on FirebaseException catch (e) {
                              setModalState(() => isProcessing = false);
                              if (!mounted) return;
                              
                              // Check if this was handled as offline
                              if (e.code == 'unavailable' || e.code == 'network-request-failed') {
                                Navigator.pop(ctx);
                                // Update local customer state
                                if (_currentCustomer != null) {
                                  setState(() {
                                    _currentCustomer = _currentCustomer!.copyWith(
                                      balanceDue: (_currentCustomer!.balanceDue - amount).clamp(0, double.infinity),
                                    );
                                  });
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Saved offline. Will sync when online.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.message}'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            } catch (e) {
                              setModalState(() => isProcessing = false);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                          },
                    isLoading: isProcessing,
                    icon: Icons.check,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _quickAmountChip(TextEditingController controller, int amount) {
    return ActionChip(
      label: Text('₹$amount'),
      onPressed: () {
        controller.text = amount.toString();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _currentCustomer ?? widget.customer;
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(customer.name.isEmpty ? 'Customer' : customer.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Customer Info Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: customer.hasDue
                                ? AppTheme.errorColor.withValues(alpha: 0.1)
                                : AppTheme.secondaryColor.withValues(alpha: 0.1),
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 24,
                                color: customer.hasDue ? AppTheme.errorColor : AppTheme.secondaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name.isEmpty ? 'Customer' : customer.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: AppTheme.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(customer.phone, style: AppTheme.captionStyle),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoTile(
                            'Balance Due',
                            '₹${customer.balanceDue.toStringAsFixed(0)}',
                            customer.hasDue ? AppTheme.errorColor : AppTheme.secondaryColor,
                          ),
                          _buildInfoTile(
                            'Transactions',
                            '${_ledger.length}',
                            AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Ledger Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text('Transaction History', style: AppTheme.subHeadingStyle),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Ledger List
                Expanded(
                  child: _ledger.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No transactions yet', style: AppTheme.captionStyle),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _ledger.length,
                          itemBuilder: (context, index) {
                            final entry = _ledger[index];
                            return _buildLedgerEntry(entry, dateFormat);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: customer.hasDue
          ? FloatingActionButton.extended(
              onPressed: _showRecordPaymentDialog,
              backgroundColor: AppTheme.secondaryColor,
              icon: const Icon(Icons.payments, color: Colors.white),
              label: const Text('Record Payment', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildInfoTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: AppTheme.captionStyle),
      ],
    );
  }

  Widget _buildLedgerEntry(LedgerEntry entry, DateFormat dateFormat) {
    final isSale = entry.isSale;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSale
              ? AppTheme.errorColor.withValues(alpha: 0.1)
              : AppTheme.secondaryColor.withValues(alpha: 0.1),
          child: Icon(
            isSale ? Icons.shopping_cart : Icons.payments,
            color: isSale ? AppTheme.errorColor : AppTheme.secondaryColor,
            size: 20,
          ),
        ),
        title: Text(
          isSale ? 'Credit Sale' : 'Payment Received',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description != null && entry.description!.isNotEmpty)
              Text(entry.description!, style: AppTheme.captionStyle),
            if (entry.note != null && entry.note!.isNotEmpty)
              Text('Note: ${entry.note}', style: AppTheme.captionStyle),
            Text(
              dateFormat.format(entry.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Text(
          '${isSale ? '+' : '-'}₹${entry.amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: isSale ? AppTheme.errorColor : AppTheme.secondaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
