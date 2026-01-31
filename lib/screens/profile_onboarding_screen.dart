import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/user_provider.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/utils/app_theme.dart';
import 'package:shop_app/widgets/custom_button.dart';
import 'package:shop_app/widgets/custom_textfield.dart';

class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({super.key});

  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  String? _gender;
  bool _isLoading = false;
  bool _isInitialLoading = true;

  static const Set<String> _allowedGenders = {
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  };

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final profile = await FirestoreService().getUserProfile();

      _nameController.text =
          (profile?['name']?.toString().trim().isNotEmpty == true)
          ? profile!['name'].toString()
          : (user?.displayName ?? '');

      _shopNameController.text = profile?['shop_name']?.toString() ?? '';

      final phone = profile?['phone']?.toString() ?? user?.phoneNumber ?? '';
      _phoneController.text = phone;

      final email = profile?['email']?.toString() ?? user?.email ?? '';
      _emailController.text = email;

      final rawGender = profile?['gender']?.toString().trim().toLowerCase();
      _gender = (rawGender != null && _allowedGenders.contains(rawGender))
          ? rawGender
          : null;
      _addressController.text = profile?['address']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();

      // Uniqueness checks (best-effort; Firestore doesn't enforce uniqueness).
      await FirestoreService().assertUniqueContact(
        email: email.isEmpty ? null : email,
        phone: phone,
      );

      await FirestoreService().upsertUserProfile({
        'name': _nameController.text.trim(),
        'shop_name': _shopNameController.text.trim(),
        'phone': phone,
        'email': email.isEmpty ? null : email,
        'gender': _gender,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      });

      final user = FirebaseAuth.instance.currentUser;
      if (mounted && user != null) {
        Provider.of<UserProvider>(context, listen: false).setFromFirebase(
          uid: user.uid,
          displayName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          shopName: _shopNameController.text.trim(),
          gender: _gender,
          address: _addressController.text.trim(),
        );
      }

      if (!mounted) return;
      
      // Navigate directly to home screen instead of going through AuthGate
      // This avoids race condition where Firestore hasn't propagated the update yet
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your profile...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Complete your profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'We need a few details to set up your shop.',
                    style: AppTheme.captionStyle,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Your name',
                    prefixIcon: Icons.person_outline,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: (_gender != null && _allowedGenders.contains(_gender))
                        ? _gender
                        : null,
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(
                        value: 'female',
                        child: Text('Female'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Other'),
                      ),
                      DropdownMenuItem(
                        value: 'prefer_not_to_say',
                        child: Text('Prefer not to say'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Select gender';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _shopNameController,
                    label: "Shop name",
                    prefixIcon: Icons.store_mall_directory_outlined,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Enter shop name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _phoneController,
                    label: 'Phone number',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter phone number';
                      if (!value.startsWith('+')) {
                        return 'Use format +<countrycode><number>';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email (optional)',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return null;
                      final ok = RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(value);
                      if (!ok) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _addressController,
                    label: 'Address (optional)',
                    prefixIcon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Save & Continue',
                    onPressed: _isLoading ? null : _save,
                    isLoading: _isLoading,
                    icon: Icons.arrow_forward,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
