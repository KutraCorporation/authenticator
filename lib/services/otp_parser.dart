import '../models/otp_account.dart';
import 'otp_gen.dart';

class OtpAuthParser {
  static const _standardParams = {
    'secret',
    'issuer',
    'algorithm',
    'digits',
    'period',
    'counter',
  };

  static OtpAccount parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'otpauth') {
      throw const FormatException('Geçerli bir otpauth bağlantısı değil.');
    }

    final type = uri.host.toLowerCase();
    if (type != 'totp' && type != 'hotp') {
      throw const FormatException('Yalnızca TOTP ve HOTP destekleniyor.');
    }

    final secret = uri.queryParameters['secret']?.replaceAll(' ', '') ?? '';
    if (secret.isEmpty) {
      throw const FormatException('Bağlantıda secret alanı yok.');
    }

    final digits = int.tryParse(uri.queryParameters['digits'] ?? '') ?? 6;
    final period = int.tryParse(uri.queryParameters['period'] ?? '') ?? 30;
    final algorithm = (uri.queryParameters['algorithm'] ?? 'SHA1')
        .toUpperCase();
    final label = Uri.decodeComponent(uri.pathSegments.join('/'));
    final issuer = uri.queryParameters['issuer'] ?? _issuerFromLabel(label);

    if (digits < 6) {
      throw const FormatException('Basamak sayısı en az 6 olmalı.');
    }

    final counter = int.tryParse(uri.queryParameters['counter'] ?? '') ?? 0;

    final customParameters = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      if (!_standardParams.contains(key)) {
        customParameters[key] = value;
      }
    });

    Base32Codec.decode(secret);

    return OtpAccount(
      type: type,
      issuer: issuer,
      label: label,
      secret: secret,
      algorithm: algorithm,
      digits: digits,
      period: period,
      counter: counter,
      customParameters: customParameters,
    );
  }

  static String _issuerFromLabel(String label) {
    final index = label.indexOf(':');
    return index > 0 ? label.substring(0, index) : '';
  }
}
