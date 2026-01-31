import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shop_app/providers/user_provider.dart';
import 'package:shop_app/services/firestore_service.dart';
import 'package:shop_app/services/local_store.dart';
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

  // Twilio WhatsApp Sandbox configuration
  // Change these values to match your Twilio sandbox settings
  static const String _twilioWhatsAppNumber =
      '+14155238886'; // Twilio sandbox number
  static const String _twilioJoinCode =
      'join anywhere-spring'; // Your Twilio sandbox join code

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

    // Check if OTP backend is configured
    if (OtpBackendService.baseUrl.isEmpty) {
      if (!mounted) return;
      _showOtpBackendNotConfiguredDialog(channel);
      return;
    }

    // For WhatsApp channel, check if user has joined Twilio sandbox
    if (channel == 'whatsapp' && !LocalStore.hasTwilioJoined(phone)) {
      if (!mounted) return;
      final joined = await _showTwilioSandboxJoinDialog(phone);
      if (!joined) return; // User cancelled or didn't confirm
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
      String errorMsg = e.toString();
      if (errorMsg.contains('OTP backend is not configured')) {
        _showOtpBackendNotConfiguredDialog(channel);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP: $errorMsg'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a dialog explaining the Twilio WhatsApp sandbox join process
  /// Returns true if user confirms they've joined, false otherwise
  Future<bool> _showTwilioSandboxJoinDialog(String phone) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _TwilioSandboxJoinDialog(
            phone: phone,
            twilioNumber: _twilioWhatsAppNumber,
            joinCode: _twilioJoinCode,
          ),
        ) ??
        false;
  }

  void _showOtpBackendNotConfiguredDialog(String channel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${channel == 'whatsapp' ? 'WhatsApp' : 'SMS'} OTP Not Configured',
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The OTP backend server is not configured for this app.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              'To enable WhatsApp OTP:\n'
              '1. Deploy the OTP backend (see docs/whatsapp_otp.md)\n'
              '2. Run the app with:\n'
              '   --dart-define=OTP_API_BASE_URL=<your-backend-url>\n\n'
              'For now, please use Google Sign-in or Firebase SMS OTP.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
          setState(() => _isLoading = false);

          String message = e.message ?? e.code;

          // Provide more helpful error messages
          if (e.code == 'app-not-authorized' ||
              e.code == 'operation-not-allowed' ||
              message.contains('not authorized') ||
              message.contains('not enabled')) {
            _showFirebasePhoneAuthNotEnabledDialog();
            return;
          }

          if (e.code == 'invalid-phone-number') {
            message = 'Invalid phone number format. Use +<countrycode><number>';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many OTP requests. Please try again later.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Please try again tomorrow.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false); // Reset loading before navigation
          Navigator.push(
            context,
            OtpVerificationScreen.route(
              phoneNumber: phone,
              verificationId: verificationId,
              forceResendingToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Called when the automatic code retrieval timeout expires
          debugPrint('Firebase SMS: Auto-retrieval timeout for $verificationId');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString();
      if (errorMsg.contains('not authorized') ||
          errorMsg.contains('not enabled') ||
          errorMsg.contains('CONFIGURATION_NOT_FOUND')) {
        _showFirebasePhoneAuthNotEnabledDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $errorMsg'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFirebasePhoneAuthNotEnabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Firebase Phone Auth Not Enabled'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phone authentication is not enabled or configured.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              'To enable Firebase SMS OTP:\n\n'
              '1. Go to Firebase Console → Authentication → Sign-in method\n'
              '2. Enable "Phone" provider\n'
              '3. Add SHA-1 & SHA-256 fingerprints in Project Settings\n'
              '4. Download updated google-services.json\n\n'
              'For now, please use Google Sign-in.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
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
                      text: "Send OTP by SMS (Firebase)",
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

/// Dialog widget for Twilio WhatsApp Sandbox join flow
class _TwilioSandboxJoinDialog extends StatefulWidget {
  const _TwilioSandboxJoinDialog({
    required this.phone,
    required this.twilioNumber,
    required this.joinCode,
  });

  final String phone;
  final String twilioNumber;
  final String joinCode;

  @override
  State<_TwilioSandboxJoinDialog> createState() =>
      _TwilioSandboxJoinDialogState();
}

class _TwilioSandboxJoinDialogState extends State<_TwilioSandboxJoinDialog> {
  bool _isOpening = false;

  Future<void> _openWhatsAppToJoin() async {
    setState(() => _isOpening = true);

    try {
      // Create WhatsApp URL with pre-filled message
      final message = Uri.encodeComponent(widget.joinCode);
      final whatsappUrl = Uri.parse(
        'https://wa.me/${widget.twilioNumber.replaceAll('+', '')}?text=$message',
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not open WhatsApp. Please install WhatsApp first.',
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening WhatsApp: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  Future<void> _confirmJoined() async {
    if (mounted) {
      // Close dialog - the phone will be marked as joined AFTER successful OTP verification
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.chat, color: Colors.green.shade600, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'WhatsApp Setup Required',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'One-time setup for WhatsApp OTP',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'To receive OTP on WhatsApp, you need to send a join message first:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Join code display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Code:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.joinCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Open WhatsApp button (moved up)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isOpening ? null : _openWhatsAppToJoin,
                icon: _isOpening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  _isOpening ? 'Opening...' : 'Open WhatsApp to Join',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Divider with "OR"
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR SCAN QR CODE',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),

            const SizedBox(height: 16),

            // QR Code section (moved down)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/twilio_whatsapp_qr.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'QR Code\nNot Found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Instructions
            Text(
              'Scan with your phone camera to open WhatsApp and send the join code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirmJoined,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Done Joining'),
        ),
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
