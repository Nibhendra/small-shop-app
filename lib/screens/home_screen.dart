import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/user_provider.dart';
import 'package:shop_app/providers/sales_provider.dart';
import 'package:shop_app/providers/credit_provider.dart';
import 'package:shop_app/screens/home_view.dart';
import 'package:shop_app/widgets/profile_settings_dialog.dart';
import 'package:shop_app/services/connectivity_service.dart';
import 'package:shop_app/services/offline_sync_service.dart';

import 'package:shop_app/screens/inventory_screen.dart';
import 'package:shop_app/utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isOnline = true;
  int _pendingCount = 0;
  
  // Stream subscription for connectivity changes
  late final dynamic _connectivitySubscription;

  final List<Widget> _views = [
    const HomeView(),
    const InventoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load data once when the main screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SalesProvider>(context, listen: false).loadData();
      Provider.of<CreditProvider>(context, listen: false).loadCustomers();
      _checkConnectivity();
    });

    // Listen to connectivity changes
    _connectivitySubscription = ConnectivityService().onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
        _updatePendingCount();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    _isOnline = ConnectivityService().isOnline;
    await _updatePendingCount();
    if (mounted) setState(() {});
  }

  Future<void> _updatePendingCount() async {
    final count = await OfflineSyncService().pendingCount();
    if (mounted) {
      setState(() => _pendingCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "My Dashboard",
              style: AppTheme.headingStyle.copyWith(fontSize: 24),
            ),
            Text("Welcome, ${userProvider.name}", style: AppTheme.captionStyle),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Offline/Sync indicator
          if (!_isOnline || _pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Chip(
                backgroundColor: !_isOnline
                    ? Colors.orange.withValues(alpha: 0.2)
                    : AppTheme.primaryColor.withValues(alpha: 0.2),
                avatar: Icon(
                  !_isOnline ? Icons.cloud_off : Icons.sync,
                  size: 16,
                  color: !_isOnline ? Colors.orange : AppTheme.primaryColor,
                ),
                label: Text(
                  !_isOnline ? 'Offline' : '$_pendingCount pending',
                  style: TextStyle(
                    fontSize: 11,
                    color: !_isOnline ? Colors.orange : AppTheme.primaryColor,
                  ),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          // Ledger/Udhaar button
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primaryColor),
                Consumer<CreditProvider>(
                  builder: (context, provider, _) {
                    if (provider.totalDue > 0) {
                      return Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${provider.customersWithDue.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/ledger');
            },
            tooltip: 'Customer Ledger (Udhaar)',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: () {
              Provider.of<SalesProvider>(context, listen: false).loadData();
              Provider.of<CreditProvider>(context, listen: false).loadCustomers();
              _updatePendingCount();
            },
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppTheme.primaryColor,
              ),
            ),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'settings') {
                showDialog(
                  context: context,
                  builder: (context) => const ProfileSettingsDialog(),
                );
              } else if (value == 'logout') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Logout"),
                    content: const Text("Are you sure you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          () async {
                            try {
                              await FirebaseAuth.instance.signOut();
                              await GoogleSignIn().signOut();
                            } catch (_) {}
                            if (!context.mounted) return;
                            Provider.of<UserProvider>(
                              context,
                              listen: false,
                            ).clear();
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (route) => false,
                            );
                          }();
                        },
                        child: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false, // Non-clickable header
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProvider.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userProvider.phone,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Divider(height: 24),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: Colors.black87),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: Colors.black87,
                    ),
                    SizedBox(width: 12),
                    Text("Settings"),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text("Logout", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _views[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) async {
            if (index == 2) {
              // Add Sale Action
              final salesProvider = Provider.of<SalesProvider>(
                context,
                listen: false,
              );
              final result = await Navigator.pushNamed(context, '/add-sale');
              if (result == true) {
                salesProvider.loadData();
              }
            } else if (index == 3) {
              await Navigator.pushNamed(context, '/profile');
            } else {
              setState(() => _currentIndex = index);
            }
          },
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(
                Icons.inventory_2,
                color: AppTheme.primaryColor,
              ),
              label: 'Inventory',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline, size: 32),
              selectedIcon: Icon(
                Icons.add_circle,
                color: AppTheme.primaryColor,
                size: 32,
              ),
              label: 'Add Sale',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.primaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
