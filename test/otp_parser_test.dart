import 'package:authenticator/services/otp_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TOTP URI parsing', () {
    test('1. standard TOTP with issuer in both label and query', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/Kutra:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Kutra&algorithm=SHA1&digits=6&period=30',
      );

      expect(account.type, 'totp');
      expect(account.issuer, 'Kutra');
      expect(account.label, 'Kutra:user@example.com');
      expect(account.displayLabel, 'user@example.com');
      expect(account.secret, 'JBSWY3DPEHPK3PXP');
      expect(account.algorithm, 'SHA1');
      expect(account.digits, 6);
      expect(account.period, 30);
      expect(account.counter, 0);
      expect(account.customParameters, isEmpty);
    });

    test('2. TOTP with SHA256 algorithm', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA256&digits=6&period=30',
      );

      expect(account.type, 'totp');
      expect(account.issuer, 'Example');
      expect(account.algorithm, 'SHA256');
      expect(account.digits, 6);
    });

    test('3. TOTP with SHA512 algorithm', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA512&digits=6&period=30',
      );

      expect(account.algorithm, 'SHA512');
    });

    test('4. TOTP with 8 digits', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/GitHub:user@github.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&digits=8&period=30',
      );

      expect(account.issuer, 'GitHub');
      expect(account.digits, 8);
      expect(account.algorithm, 'SHA1');
    });

    test('5. TOTP with custom 60-second period', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/DigitalOcean:dev@digitalocean.com?secret=JBSWY3DPEHPK3PXP&issuer=DigitalOcean&period=60&digits=6',
      );

      expect(account.issuer, 'DigitalOcean');
      expect(account.period, 60);
      expect(account.digits, 6);
    });

    test('6. TOTP with long period (1 hour)', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/SlowApp:test@example.com?secret=JBSWY3DPEHPK3PXP&issuer=SlowApp&period=3600&digits=6',
      );

      expect(account.period, 3600);
    });

    test('7. TOTP with extra custom parameter', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/CustomApp:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=CustomApp&digits=6&period=30&image=https://example.com/icon.png',
      );

      expect(
          account.customParameters, {'image': 'https://example.com/icon.png'});
    });

    test('8. TOTP with issuer only in label (no query issuer)', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/MyIssuer:user@example.com?secret=JBSWY3DPEHPK3PXP&digits=6&period=30',
      );

      expect(account.issuer, 'MyIssuer');
      expect(account.label, 'MyIssuer:user@example.com');
      expect(account.displayLabel, 'user@example.com');
    });

    test('9. TOTP with no issuer at all', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/user@example.com?secret=JBSWY3DPEHPK3PXP&digits=6&period=30',
      );

      expect(account.issuer, '');
      expect(account.label, 'user@example.com');
      expect(account.displayLabel, 'user@example.com');
    });

    test('10. TOTP with URL-encoded special characters in label', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/Provider%20Inc:user%2Btag@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Provider%20Inc&digits=6&period=30',
      );

      expect(account.issuer, 'Provider Inc');
      expect(account.label, 'Provider Inc:user+tag@example.com');
      expect(account.displayLabel, 'user+tag@example.com');
    });
  });

  group('HOTP URI parsing', () {
    test('1. standard HOTP with counter', () {
      final account = OtpAuthParser.parse(
        'otpauth://hotp/ACME:user@acme.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME&counter=42&algorithm=SHA1&digits=6',
      );

      expect(account.type, 'hotp');
      expect(account.issuer, 'ACME');
      expect(account.counter, 42);
      expect(account.digits, 6);
      expect(account.algorithm, 'SHA1');
      expect(account.period, 30);
    });

    test('2. HOTP with SHA256 and 8 digits', () {
      final account = OtpAuthParser.parse(
        'otpauth://hotp/Bank:secure@bank.com?secret=JBSWY3DPEHPK3PXP&issuer=Bank&algorithm=SHA256&digits=8&counter=7',
      );

      expect(account.type, 'hotp');
      expect(account.algorithm, 'SHA256');
      expect(account.digits, 8);
      expect(account.counter, 7);
    });

    test('3. HOTP with zero counter', () {
      final account = OtpAuthParser.parse(
        'otpauth://hotp/NewKey:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=NewKey&counter=0&digits=6',
      );

      expect(account.counter, 0);
    });

    test('4. HOTP with extra custom parameters', () {
      final account = OtpAuthParser.parse(
        'otpauth://hotp/Custom:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Custom&counter=1&digits=6&pin=1234&device=phone',
      );

      expect(account.counter, 1);
      expect(account.customParameters, {
        'pin': '1234',
        'device': 'phone',
      });
    });

    test('5. HOTP with issuer in label only', () {
      final account = OtpAuthParser.parse(
        'otpauth://hotp/VPN:user@vpn.com?secret=JBSWY3DPEHPK3PXP&counter=99&digits=6',
      );

      expect(account.issuer, 'VPN');
      expect(account.label, 'VPN:user@vpn.com');
      expect(account.counter, 99);
    });
  });

  group('Edge cases', () {
    test('missing issuer in both label and query', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/user@example.com?secret=JBSWY3DPEHPK3PXP&digits=6&period=30',
      );

      expect(account.issuer, '');
      expect(account.displayIssuer, 'Kutra');
    });

    test('unusual digits (12)', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/Test:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Test&digits=12&period=30',
      );

      expect(account.digits, 12);
    });

    test('multiple extra custom parameters preserved', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/App:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=App&digits=6&period=30&image=https://img.com/icon.png&lock=true&theme=dark',
      );

      expect(account.customParameters, {
        'image': 'https://img.com/icon.png',
        'lock': 'true',
        'theme': 'dark',
      });
    });

    test('all custom parameters from original URI are round-tripped', () {
      const original =
          'otpauth://totp/App:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=App&digits=6&period=30&foo=bar&baz=qux';
      final account = OtpAuthParser.parse(original);

      final reconstructed = Uri.parse(original);
      final allParams = Map<String, String>.from(reconstructed.queryParameters);

      expect(allParams['secret'], account.secret);
      expect(allParams['issuer'], account.issuer);
      expect(allParams['foo'], account.customParameters['foo']);
      expect(allParams['baz'], account.customParameters['baz']);
      expect(allParams['foo'], 'bar');
      expect(allParams['baz'], 'qux');
    });

    test('label colon without issuer prefix still works', () {
      final account = OtpAuthParser.parse(
        'otpauth://totp/:user@example.com?secret=JBSWY3DPEHPK3PXP&digits=6&period=30',
      );

      expect(account.issuer, '');
      expect(account.label, ':user@example.com');
    });

    test('throws on invalid scheme', () {
      expect(
        () => OtpAuthParser.parse('http://example.com'),
        throwsFormatException,
      );
    });

    test('throws on unsupported type', () {
      expect(
        () =>
            OtpAuthParser.parse('otpauth://motp/test?secret=JBSWY3DPEHPK3PXP'),
        throwsFormatException,
      );
    });

    test('throws on missing secret', () {
      expect(
        () => OtpAuthParser.parse('otpauth://totp/test?digits=6'),
        throwsFormatException,
      );
    });

    test('throws on digits less than 6', () {
      expect(
        () => OtpAuthParser.parse(
          'otpauth://totp/test:user@test.com?secret=JBSWY3DPEHPK3PXP&issuer=test&digits=4',
        ),
        throwsFormatException,
      );
    });
  });
}
