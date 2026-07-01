import 'package:authenticator/models/otp_account.dart';
import 'package:authenticator/services/otp_gen.dart';
import 'package:authenticator/services/otp_parser.dart';
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

  test('parses otpauth HOTP uri', () {
    final account = OtpAuthParser.parse(
      'otpauth://hotp/Kutra:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Kutra&counter=42&algorithm=SHA1&digits=6',
    );

    expect(account.type, 'hotp');
    expect(account.counter, 42);
    expect(account.digits, 6);
  });

  test('generates RFC 6238 compatible SHA1 TOTP code', () {
    final account = OtpAccount(
      type: 'totp',
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

  test('generates RFC 4226 compatible SHA1 HOTP code', () {
    final code = HotpGenerator.codeForRaw(
      secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      counter: 0,
      digits: 6,
    );
    expect(code, '755224');
  });

  test('supports provider-defined digits and period values', () {
    final account = OtpAuthParser.parse(
      'otpauth://totp/Kutra:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Kutra&digits=12&period=3600',
    );

    expect(account.digits, 12);
    expect(account.period, 3600);
    expect(TotpGenerator.codeFor(account, DateTime(2026)).length, 12);
  });
}
