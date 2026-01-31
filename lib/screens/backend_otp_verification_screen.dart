import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shop_app/services/otp_backend_service.dart';
import 'package:shop_app/utils/app_theme.dart';
import 'package:shop_app/widgets/custom_button.dart';
import 'package:shop_app/widgets/custom_textfield.dart';

class BackendOtpVerificationScreen extends StatefulWidget {
  const BackendOtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.channel,
  });

  final String phoneNumber;
  final String channel; // whatsapp | sms

  static Route<void> route({
    required String phoneNumber,
    required String channel,
  }) {
    return MaterialPageRoute(
      builder: (_) => BackendOtpVerificationScreen(
        phoneNumber: phoneNumber,
        channel: channel,
      ),
    );
  }

  @override
  State<BackendOtpVerificationScreen> createState() =>
      _BackendOtpVerificationScreenState();
}

class _BackendOtpVerificationScreenState
    extends State<BackendOtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  final OtpBackendService _service = OtpBackendService();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter the OTP code'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await _service.verifyOtp(
        phone: widget.phoneNumber,
        code: code,
      );

      await FirebaseAuth.instance.signInWithCustomToken(token);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isLoading = true);
    try {
      await _service.startOtp(
        phone: widget.phoneNumber,
        channel: widget.channel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.channel == 'whatsapp'
                ? 'OTP resent on WhatsApp'
                : 'OTP resent by SMS',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend: $e'),
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
    final channelLabel =
        widget.channel == 'whatsapp' ? 'WhatsApp' : 'SMS';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Verify OTP ($channelLabel)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the code sent to',
                  style: AppTheme.captionStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.phoneNumber,
                  style: AppTheme.headingStyle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: _otpController,
                  label: 'OTP code',
                  prefixIcon: Icons.lock_outline,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Verify',
                  onPressed: _isLoading ? null : _verify,
                  isLoading: _isLoading,
                  icon: Icons.verified_outlined,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading ? null : _resend,
                  child: const Text('Resend code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
