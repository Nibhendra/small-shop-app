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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo or Header
              Center(
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Welcome",
                textAlign: TextAlign.center,
                style: AppTheme.headingStyle,
              ),
              const SizedBox(height: 8),
              Text(
                "Sign in to manage your shop",
                textAlign: TextAlign.center,
                style: AppTheme.captionStyle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 48),

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
                    child: Divider(color: Colors.grey.withValues(alpha: 0.4)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR'),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.withValues(alpha: 0.4)),
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
                "Example: +919876543210 (WhatsApp recommended)",
                style: AppTheme.captionStyle.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              CustomButton(
                text: "Send OTP on WhatsApp (Recommended)",
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
    );
  }
}
