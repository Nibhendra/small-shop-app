import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/user_provider.dart';
import 'package:shop_app/providers/sales_provider.dart';
import 'package:shop_app/providers/credit_provider.dart';

import 'package:shop_app/providers/inventory_provider.dart';
import 'package:shop_app/screens/login_screen.dart';
import 'package:shop_app/screens/home_screen.dart';
import 'package:shop_app/screens/add_sale_screen.dart';
import 'package:shop_app/screens/profile_onboarding_screen.dart';
import 'package:shop_app/screens/profile_screen.dart';
import 'package:shop_app/screens/splash_screen.dart';
import 'package:shop_app/screens/customer_ledger_screen.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/services/local_store.dart';
import 'package:shop_app/services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("CRITICAL FIREBASE INIT ERROR: $e");
  }
  
  // Initialize connectivity monitoring AFTER Firebase
  await ConnectivityService().init();
  
  runApp(const MyApp());
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _profileComplete;
  bool _isLoading = true;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _profileComplete = null;
            _currentUid = null;
          });
        }
      } else if (user.uid != _currentUid) {
        _currentUid = user.uid;
        _loadProfile(user);
      }
    });
  }

  Future<void> _loadProfile(User user) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Ensure profile document exists
      await FirestoreService().ensureUserProfile();
      
      // Fetch profile from Firestore
      final profile = await FirestoreService().getUserProfile();
      debugPrint('AuthGate: Fetched profile for ${user.uid}: $profile');

      final complete = FirestoreService.isProfileComplete(profile);
      debugPrint('AuthGate: Profile complete = $complete');

      if (mounted) {
        // Update UserProvider
        Provider.of<UserProvider>(context, listen: false).setFromFirebase(
          uid: user.uid,
          displayName: profile?['name']?.toString() ?? user.displayName,
          email: (profile?['email'] ?? user.email)?.toString(),
          phone: (profile?['phone'] ?? user.phoneNumber)?.toString(),
          shopName: profile?['shop_name']?.toString(),
          gender: profile?['gender']?.toString(),
          address: profile?['address']?.toString(),
        );

        setState(() {
          _profileComplete = complete;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AuthGate: Error loading profile: $e');
      if (mounted) {
        setState(() {
          _profileComplete = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return const LoginScreen();
    }

    if (_profileComplete == true) {
      return const HomeScreen();
    }

    return const ProfileOnboardingScreen();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => CreditProvider()),
      ],
      child: MaterialApp(
        title: 'Vyapaar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/': (context) => const AuthGate(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/add-sale': (context) => const AddSaleScreen(),
          '/onboarding': (context) => const ProfileOnboardingScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/ledger': (context) => const CustomerLedgerScreen(),
        },
      ),
    );
  }
}
