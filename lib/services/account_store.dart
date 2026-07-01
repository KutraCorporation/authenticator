import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/otp_account.dart';

class SecureAccountStore {
  static const _key = 'kutra_accounts_v2';
  static const _biometricKey = 'kutra_biometric_enabled';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<OtpAccount>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final items = jsonDecode(raw) as List<dynamic>;
    return items
        .map((item) => OtpAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<OtpAccount> accounts) {
    return _storage.write(
      key: _key,
      value: jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  Future<bool> getBiometricEnabled() async {
    final raw = await _storage.read(key: _biometricKey);
    return raw == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) {
    return _storage.write(key: _biometricKey, value: enabled.toString());
  }
}
