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
  State<ProfileOnboardingScreen> createState() => _ProfileOnboardingScreenState();
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
  bool _loaded = false;

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
    if (_loaded) return;
    _loaded = true;

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

    _gender = profile?['gender']?.toString();
    _addressController.text = profile?['address']?.toString() ?? '';

    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    setState(() => _isLoading = true);
    try {
      await FirestoreService().upsertUserProfile({
        'name': _nameController.text.trim(),
        'shop_name': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
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
    return FutureBuilder<void>(
      future: _loadInitial(),
      builder: (context, snapshot) {
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
                        key: ValueKey(_gender ?? ''),
                        initialValue: _gender,
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(value: 'female', child: Text('Female')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
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
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter phone number';
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
      },
    );
  }
}
