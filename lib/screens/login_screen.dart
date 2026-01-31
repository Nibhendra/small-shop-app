import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/user_provider.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/screens/backend_otp_verification_screen.dart';
import 'package:shop_app/screens/otp_verification_screen.dart';
import 'package:shop_app/services/otp_backend_service.dart';
import 'package:shop_app/utils/app_theme.dart';
import 'package:shop_app/widgets/custom_button.dart';
import 'package:shop_app/widgets/custom_textfield.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  final OtpBackendService _otpBackend = OtpBackendService();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _syncUserIntoProvider() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirestoreService();
    await firestore.ensureUserProfile();
    final profile = await firestore.getUserProfile();

    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).setFromFirebase(
      uid: user.uid,
      displayName: profile?['name']?.toString() ?? user.displayName,
      email: user.email,
      phone: user.phoneNumber,
      shopName: profile?['shop_name']?.toString(),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _syncUserIntoProvider();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startOtp({required String channel}) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter phone in format +<countrycode><number>'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _otpBackend.startOtp(phone: phone, channel: channel);
      if (!mounted) return;
      Navigator.push(
        context,
        BackendOtpVerificationScreen.route(
          phoneNumber: phone,
          channel: channel,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startFirebaseSmsOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter phone in format +<countrycode><number>'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await _syncUserIntoProvider();
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/');
          } catch (_) {
            // fall back to manual entry
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? e.code),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          Navigator.push(
            context,
            OtpVerificationScreen.route(
              phoneNumber: phone,
              verificationId: verificationId,
              forceResendingToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF180629), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 88,
                    width: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Vyapaar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to manage your shop',
                    textAlign: TextAlign.center,
                    style: AppTheme.captionStyle.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    CustomButton(
                      text: "Continue with Google",
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: Icons.login,
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR'),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    CustomTextField(
                      controller: _phoneController,
                      label: "Phone Number (E.164)",
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Example: +919876543210",
                      style: AppTheme.captionStyle.copyWith(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    CustomButton(
                      text: "Send OTP on WhatsApp",
                      isLoading: _isLoading,
                      onPressed: _isLoading
                          ? null
                          : () => _startOtp(channel: 'whatsapp'),
                      icon: Icons.chat_bubble_outline,
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: "Send OTP by SMS",
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _startFirebaseSmsOtp,
                      icon: Icons.sms_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
