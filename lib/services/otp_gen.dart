import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/otp_account.dart';

class Base32Codec {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static Uint8List decode(String input) {
    final normalized = input.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
    var buffer = 0;
    var bitsLeft = 0;
    final bytes = <int>[];

    for (final rune in normalized.runes) {
      final value = _alphabet.indexOf(String.fromCharCode(rune));
      if (value < 0) {
        throw const FormatException('Secret Base32 formatında değil.');
      }
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bytes.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }

    if (bytes.isEmpty) {
      throw const FormatException('Secret boş olamaz.');
    }
    return Uint8List.fromList(bytes);
  }
}

Hash _hashFor(String algorithm) {
  switch (algorithm.toUpperCase()) {
    case 'SHA256':
      return sha256;
    case 'SHA512':
      return sha512;
    case 'SHA1':
      return sha1;
    default:
      throw FormatException('$algorithm algoritması desteklenmiyor.');
  }
}

BigInt _binaryFromDigest(List<int> digest, int digits) {
  final offset = digest.last & 0x0f;

  if (digits <= 10) {
    return BigInt.from(
      ((digest[offset] & 0x7f) << 24) |
          ((digest[offset + 1] & 0xff) << 16) |
          ((digest[offset + 2] & 0xff) << 8) |
          (digest[offset + 3] & 0xff),
    );
  }

  final maxBytes = digest.length - offset;
  final bytesNeeded = ((digits * 10 ~/ 3) + 7) ~/ 8;
  final numBytes = bytesNeeded.clamp(4, maxBytes);

  var binary = BigInt.from(digest[offset] & 0x7f);
  for (var i = 1; i < numBytes; i++) {
    binary = (binary << 8) | BigInt.from(digest[offset + i] & 0xff);
  }
  return binary;
}

String _generateCode(Uint8List key, int counter, int digits, String algorithm) {
  final counterBytes = ByteData(8)..setInt64(0, counter, Endian.big);
  final digest = Hmac(
    _hashFor(algorithm),
    key,
  ).convert(counterBytes.buffer.asUint8List()).bytes;
  final binary = _binaryFromDigest(digest, digits);
  final modulus = BigInt.from(10).pow(digits);
  final otp = binary % modulus;
  return otp.toString().padLeft(digits, '0');
}

class TotpGenerator {
  static String codeFor(OtpAccount account, DateTime now) {
    final counter = now.millisecondsSinceEpoch ~/ 1000 ~/ account.period;
    final key = Base32Codec.decode(account.secret);
    return _generateCode(key, counter, account.digits, account.algorithm);
  }
}

class HotpGenerator {
  static String codeFor(OtpAccount account) {
    final key = Base32Codec.decode(account.secret);
    return _generateCode(key, account.counter, account.digits, account.algorithm);
  }

  static String codeForRaw({
    required String secret,
    required int counter,
    int digits = 6,
    String algorithm = 'SHA1',
  }) {
    final key = Base32Codec.decode(secret);
    return _generateCode(key, counter, digits, algorithm);
  }
}
