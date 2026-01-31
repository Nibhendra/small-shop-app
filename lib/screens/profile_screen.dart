import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/user_provider.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/utils/app_theme.dart';
import 'package:shop_app/widgets/custom_button.dart';
import 'package:shop_app/widgets/custom_textfield.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _shopNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  String? _gender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false);
    _nameController = TextEditingController(text: user.name);
    _shopNameController = TextEditingController(text: user.shopName);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phone);
    _addressController = TextEditingController(text: user.address);
    _gender = user.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();

      await FirestoreService().assertUniqueContact(
        email: email.isEmpty ? null : email,
      );

      await FirestoreService().upsertUserProfile({
        'name': _nameController.text.trim(),
        'shop_name': _shopNameController.text.trim(),
        'gender': _gender,
        'email': email.isEmpty ? null : email,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        // phone changes should be verified; keep write off for now.
      });

      if (!mounted) return;

      Provider.of<UserProvider>(context, listen: false).updateProfileExtended(
        name: _nameController.text.trim(),
        shopName: _shopNameController.text.trim(),
        email: _emailController.text.trim(),
        gender: _gender,
        address: _addressController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
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
    final user = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  _readOnlyTile('Shop ID',
                      user.id.isNotEmpty ? 'shop_${user.id.substring(0, user.id.length >= 8 ? 8 : user.id.length)}' : ''),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Your name',
                    prefixIcon: Icons.person_outline,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) return 'Enter name';
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
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _shopNameController,
                    label: 'Shop name',
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
                    label: 'Phone number (read-only)',
                    prefixIcon: Icons.phone_outlined,
                    enabled: false,
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
                    text: 'Save',
                    onPressed: _isLoading ? null : _save,
                    isLoading: _isLoading,
                    icon: Icons.save_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.captionStyle),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
