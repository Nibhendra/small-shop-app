import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for sending WhatsApp messages for payment reminders.
/// Uses URL schemes to open WhatsApp with pre-filled messages.
class WhatsAppService {
  /// Sends a payment reminder to a customer via WhatsApp.
  /// 
  /// [phone] must be in E.164 format (e.g., +919876543210).
  /// Returns true if WhatsApp was opened successfully.
  static Future<bool> sendPaymentReminder({
    required String phone,
    required String customerName,
    required double amount,
    String? shopName,
  }) async {
    try {
      // Clean phone number - remove spaces and keep +
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      
      // Remove the + for WhatsApp API
      final phoneForUrl = cleanPhone.startsWith('+') 
          ? cleanPhone.substring(1) 
          : cleanPhone;

      if (phoneForUrl.length < 10) {
        debugPrint('WhatsApp: Invalid phone number');
        return false;
      }

      final message = _buildReminderMessage(
        customerName: customerName,
        amount: amount,
        shopName: shopName,
      );

      final encodedMessage = Uri.encodeComponent(message);
      final waUrl = 'https://wa.me/$phoneForUrl?text=$encodedMessage';

      return await _launchUrl(waUrl);
    } catch (e) {
      debugPrint('WhatsApp error: $e');
      return false;
    }
  }

  /// Sends a custom message via WhatsApp.
  static Future<bool> sendCustomMessage({
    required String phone,
    required String message,
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final phoneForUrl = cleanPhone.startsWith('+') 
          ? cleanPhone.substring(1) 
          : cleanPhone;

      if (phoneForUrl.length < 10) {
        return false;
      }

      final encodedMessage = Uri.encodeComponent(message);
      final waUrl = 'https://wa.me/$phoneForUrl?text=$encodedMessage';

      return await _launchUrl(waUrl);
    } catch (e) {
      debugPrint('WhatsApp error: $e');
      return false;
    }
  }

  static String _buildReminderMessage({
    required String customerName,
    required double amount,
    String? shopName,
  }) {
    final shop = shopName ?? 'Our Shop';
    final amountStr = amount.toStringAsFixed(0);
    final name = customerName.isNotEmpty ? customerName : 'Customer';

    return '''🙏 नमस्ते $name जी,

यह एक friendly reminder है कि आपके $shop में ₹$amountStr बकाया है।

जब भी सुविधाजनक हो, कृपया भुगतान कर दें।

धन्यवाद! 🙏

---

Hello $name,

This is a friendly reminder that you have a pending balance of ₹$amountStr at $shop.

Please clear the dues at your earliest convenience.

Thank you!''';
  }

  static Future<bool> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('Cannot launch URL: $url');
        return false;
      }
    } catch (e) {
      debugPrint('Launch URL error: $e');
      return false;
    }
  }
}
