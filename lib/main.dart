import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/user_provider.dart';
import 'package:shop_app/providers/sales_provider.dart';

import 'package:shop_app/providers/inventory_provider.dart';
import 'package:shop_app/screens/login_screen.dart';
import 'package:shop_app/screens/home_screen.dart';
import 'package:shop_app/screens/add_sale_screen.dart';
import 'package:shop_app/screens/profile_onboarding_screen.dart';
import 'package:shop_app/screens/profile_screen.dart';
import 'package:shop_app/screens/splash_screen.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/services/local_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("CRITICAL FIREBASE INIT ERROR: $e");
  }
  runApp(const MyApp());
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }

        // Ensure profile exists (non-blocking best-effort)
        FirestoreService().ensureUserProfile();

        return FutureBuilder<Map<String, dynamic>?>(
          future: FirestoreService().getUserProfile(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = FirebaseAuth.instance.currentUser;
            final profile = profileSnap.data;

            if (user != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                Provider.of<UserProvider>(context, listen: false).setFromFirebase(
                  uid: user.uid,
                  displayName: profile?['name']?.toString() ?? user.displayName,
                  email: (profile?['email'] ?? user.email)?.toString(),
                  phone: (profile?['phone'] ?? user.phoneNumber)?.toString(),
                  shopName: profile?['shop_name']?.toString(),
                  gender: profile?['gender']?.toString(),
                  address: profile?['address']?.toString(),
                );
              });
            }

            final complete = FirestoreService.isProfileComplete(profile);
            if (!complete) {
              return const ProfileOnboardingScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
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
        },
      ),
    );
  }
}
