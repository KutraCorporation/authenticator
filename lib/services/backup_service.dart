import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../models/otp_account.dart';

class BackupService {
  static String exportJson(List<OtpAccount> accounts) {
    final data = {
      'version': 2,
      'type': 'kutra_backup',
      'accounts': accounts.map((a) => a.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static List<OtpAccount> importJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final accounts = data['accounts'] as List<dynamic>;
    return accounts
        .map((item) => OtpAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static String exportEncrypted(List<OtpAccount> accounts, String password) {
    final json = exportJson(accounts);
    final salt = _randomBytes(16);
    final key = _deriveKey(password, salt);
    final iv = _randomBytes(16);
    final encrypted = _aesEncrypt(Uint8List.fromList(utf8.encode(json)), key, iv);
    final combined = Uint8List(1 + 16 + 16 + encrypted.length)
      ..[0] = 2
      ..setRange(1, 17, salt)
      ..setRange(17, 33, iv)
      ..setRange(33, 33 + encrypted.length, encrypted);
    return base64.encode(combined);
  }

  static List<OtpAccount> importEncrypted(String encoded, String password) {
    final combined = base64.decode(encoded);
    if (combined[0] != 2) {
      throw const FormatException('Desteklenmeyen yedek formatı.');
    }
    final salt = combined.sublist(1, 17);
    final iv = combined.sublist(17, 33);
    final encrypted = combined.sublist(33);
    final key = _deriveKey(password, salt);
    final decrypted = _aesDecrypt(encrypted, key, iv);
    return importJson(utf8.decode(decrypted));
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, 600000, 32));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _aesEncrypt(Uint8List plaintext, Uint8List key, Uint8List iv) {
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(key), iv));
    final padded = _pad(plaintext, 16);
    final out = Uint8List(padded.length);
    var offset = 0;
    for (var i = 0; i < padded.length; i += 16) {
      offset += cipher.processBlock(padded, i, out, offset);
    }
    return out;
  }

  static Uint8List _aesDecrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));
    final out = Uint8List(ciphertext.length);
    var offset = 0;
    for (var i = 0; i < ciphertext.length; i += 16) {
      offset += cipher.processBlock(ciphertext, i, out, offset);
    }
    return _unpad(out);
  }

  static Uint8List _pad(Uint8List data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLen)
      ..setRange(0, data.length, data)
      ..fillRange(data.length, data.length + padLen, padLen);
    return padded;
  }

  static Uint8List _unpad(Uint8List data) {
    final padLen = data.isNotEmpty ? data[data.length - 1] : 0;
    if (padLen < 1 || padLen > 16) {
      throw const FormatException('Geçersiz yedek verisi.');
    }
    return data.sublist(0, data.length - padLen);
  }
}
