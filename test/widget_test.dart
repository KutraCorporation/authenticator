import 'package:authenticator/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses otpauth TOTP uri', () {
    final account = OtpAuthParser.parse(
      'otpauth://totp/Kutra:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Kutra&algorithm=SHA1&digits=6&period=30',
    );

    expect(account.issuer, 'Kutra');
    expect(account.displayLabel, 'user@example.com');
    expect(account.digits, 6);
    expect(account.period, 30);
  });

  test('generates RFC 6238 compatible SHA1 TOTP code', () {
    final account = OtpAccount(
      issuer: 'Test',
      label: 'test@example.com',
      secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      digits: 8,
      period: 30,
    );

    final code = TotpGenerator.codeFor(
      account,
      DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
    );

    expect(code, '94287082');
  });
}
