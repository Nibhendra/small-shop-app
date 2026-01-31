import 'dart:convert';

import 'package:http/http.dart' as http;

/// Calls the backend that sends OTP via Gupshup (WhatsApp/SMS) and returns
/// Firebase custom tokens on successful verification.
class OtpBackendService {
  OtpBackendService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Configure at build time:
  /// `flutter run --dart-define=OTP_API_BASE_URL=https://<region>-<project>.cloudfunctions.net/api`
  static const String baseUrl = String.fromEnvironment(
    'OTP_API_BASE_URL',
    defaultValue: '',
  );

  Uri _uri(String path) {
    if (baseUrl.isEmpty) {
      throw StateError(
        'OTP backend is not configured. Set --dart-define=OTP_API_BASE_URL=...'
        ' (example: https://<region>-<project>.cloudfunctions.net/api)',
      );
    }
    return Uri.parse('${baseUrl.replaceAll(RegExp(r"/+\$"), '')}$path');
  }

  Future<void> startOtp({required String phone, required String channel}) async {
    final res = await _client.post(
      _uri('/otp/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'channel': channel}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    final msg = _extractError(res.body) ?? res.body;
    throw StateError(msg);
  }

  Future<String> verifyOtp({required String phone, required String code}) async {
    final res = await _client.post(
      _uri('/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = (data['token'] ?? '').toString();
      if (token.isEmpty) throw StateError('Backend did not return a token');
      return token;
    }

    final msg = _extractError(res.body) ?? res.body;
    throw StateError(msg);
  }

  String? _extractError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final e = data['error'];
        if (e != null) return e.toString();
      }
    } catch (_) {}
    return null;
  }
}
