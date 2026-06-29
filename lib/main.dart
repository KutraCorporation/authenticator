import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const KutraAuthenticatorApp());
}

class KutraColors {
  static const black = Color(0xFF0A0A0A);
  static const ink = Color(0xFF0D0D0D);
  static const panel = Color(0xFF111111);
  static const panelRaised = Color(0xFF151515);
  static const text = Color(0xFFE8E8E8);
  static const muted = Color(0xFFB8B8B8);
  static const dim = Color(0xFF737373);
  static const cyan = Color(0xFF00D9F5);
  static const cyanDeep = Color(0xFF00B8D4);
  static const purple = Color(0xFFA855F7);
  static const danger = Color(0xFFFF5F57);
  static const border = Color(0x14FFFFFF);
  static const borderStrong = Color(0x24FFFFFF);
}

class KutraAuthenticatorApp extends StatelessWidget {
  const KutraAuthenticatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kutra Authenticator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: KutraColors.cyan,
          brightness: Brightness.dark,
          primary: KutraColors.cyan,
          secondary: KutraColors.purple,
          surface: KutraColors.panel,
          onSurface: KutraColors.text,
        ),
        scaffoldBackgroundColor: KutraColors.black,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: KutraColors.panelRaised,
          contentTextStyle: TextStyle(color: KutraColors.text),
        ),
      ),
      home: const AuthenticatorHome(),
    );
  }
}

class OtpAccount {
  const OtpAccount({
    required this.issuer,
    required this.label,
    required this.secret,
    this.algorithm = 'SHA1',
    this.digits = 6,
    this.period = 30,
  });

  final String issuer;
  final String label;
  final String secret;
  final String algorithm;
  final int digits;
  final int period;

  String get displayIssuer => issuer.isEmpty ? 'Kutra' : issuer;

  String get displayLabel {
    if (label.isEmpty) return 'Yeni hesap';
    final issuerPrefix = '$issuer:';
    return label.startsWith(issuerPrefix)
        ? label.substring(issuerPrefix.length)
        : label;
  }

  Map<String, dynamic> toJson() => {
    'issuer': issuer,
    'label': label,
    'secret': secret,
    'algorithm': algorithm,
    'digits': digits,
    'period': period,
  };

  factory OtpAccount.fromJson(Map<String, dynamic> json) => OtpAccount(
    issuer: json['issuer'] as String? ?? '',
    label: json['label'] as String? ?? '',
    secret: json['secret'] as String? ?? '',
    algorithm: json['algorithm'] as String? ?? 'SHA1',
    digits: json['digits'] as int? ?? 6,
    period: json['period'] as int? ?? 30,
  );
}

class OtpAuthParser {
  static OtpAccount parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'otpauth') {
      throw const FormatException('Geçerli bir otpauth bağlantısı değil.');
    }
    if (uri.host.toLowerCase() != 'totp') {
      throw const FormatException('Şimdilik yalnızca TOTP destekleniyor.');
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

    if (![6, 7, 8].contains(digits)) {
      throw const FormatException('Desteklenen basamak sayısı 6, 7 veya 8.');
    }
    if (period < 10 || period > 120) {
      throw const FormatException('Period 10 ile 120 saniye arasında olmalı.');
    }
    Base32Codec.decode(secret);

    return OtpAccount(
      issuer: issuer,
      label: label,
      secret: secret,
      algorithm: algorithm,
      digits: digits,
      period: period,
    );
  }

  static String _issuerFromLabel(String label) {
    final index = label.indexOf(':');
    return index > 0 ? label.substring(0, index) : '';
  }
}

class TotpGenerator {
  static String codeFor(OtpAccount account, DateTime now) {
    final counter = now.millisecondsSinceEpoch ~/ 1000 ~/ account.period;
    final key = Base32Codec.decode(account.secret);
    final counterBytes = ByteData(8)..setInt64(0, counter, Endian.big);
    final digest = Hmac(
      _hashFor(account.algorithm),
      key,
    ).convert(counterBytes.buffer.asUint8List()).bytes;
    final offset = digest.last & 0x0f;
    final binary =
        ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);
    final otp = binary % pow(10, account.digits).toInt();
    return otp.toString().padLeft(account.digits, '0');
  }

  static Hash _hashFor(String algorithm) {
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
}

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

class SecureAccountStore {
  static const _key = 'kutra_accounts_v1';
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
}

class AuthenticatorHome extends StatefulWidget {
  const AuthenticatorHome({super.key});

  @override
  State<AuthenticatorHome> createState() => _AuthenticatorHomeState();
}

class _AuthenticatorHomeState extends State<AuthenticatorHome> {
  final _store = SecureAccountStore();
  final _manualController = TextEditingController();
  final List<OtpAccount> _accounts = [];
  late final Timer _timer;
  DateTime _now = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _store.load();
    setState(() {
      _accounts
        ..clear()
        ..addAll(accounts);
      _loading = false;
    });
  }

  Future<void> _addFromUri(String value) async {
    final account = OtpAuthParser.parse(value);
    setState(() => _accounts.add(account));
    await _store.save(_accounts);
  }

  Future<void> _remove(OtpAccount account) async {
    setState(() => _accounts.remove(account));
    await _store.save(_accounts);
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (code == null || !mounted) return;
    await _tryAdd(code);
  }

  Future<void> _tryAdd(String value) async {
    try {
      await _addFromUri(value);
      _manualController.clear();
      if (!mounted) return;
      _showMessage('Hesap eklendi.');
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: _Header(onScan: _openScanner),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _ManualEntry(
                  controller: _manualController,
                  onSubmit: () => _tryAdd(_manualController.text),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_accounts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: _accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    return _OtpCard(
                      account: account,
                      now: _now,
                      onRemove: () => _remove(account),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A0A), Color(0xFF101012), Color(0xFF0A0A0A)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: KutraColors.panel.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: KutraColors.borderStrong),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3300D9F5),
              blurRadius: 42,
              spreadRadius: -30,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: KutraColors.borderStrong),
                    gradient: const LinearGradient(
                      colors: [KutraColors.cyan, KutraColors.purple],
                    ),
                  ),
                  child: const Text(
                    'K',
                    style: TextStyle(
                      color: KutraColors.black,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kutra',
                        style: TextStyle(
                          color: KutraColors.text,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Authenticator',
                        style: TextStyle(
                          color: KutraColors.cyan,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'QR kod oku',
                  style: IconButton.styleFrom(
                    backgroundColor: KutraColors.cyan,
                    foregroundColor: KutraColors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Sınırların ötesinde güvenlik: QR kodu okut veya otpauth bağlantısını yapıştır, TOTP kodlarını cihazında güvenli alanda sakla.',
              style: TextStyle(
                color: KutraColors.muted,
                height: 1.42,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _FeaturePill(icon: Icons.qr_code_2, label: 'QR okuma'),
                _FeaturePill(icon: Icons.link, label: 'otpauth://'),
                _FeaturePill(icon: Icons.lock_outline, label: 'Secure storage'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KutraColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: KutraColors.cyan),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: KutraColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualEntry extends StatelessWidget {
  const _ManualEntry({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KutraColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KutraColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(color: KutraColors.text),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.key, color: KutraColors.dim),
                hintText: 'otpauth://totp/Kutra:mail@domain.com?...',
                hintStyle: const TextStyle(color: KutraColors.dim),
                filled: true,
                fillColor: KutraColors.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: KutraColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: KutraColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: KutraColors.cyan),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 56,
            child: IconButton.filled(
              onPressed: onSubmit,
              icon: const Icon(Icons.add),
              tooltip: 'Ekle',
              style: IconButton.styleFrom(
                backgroundColor: KutraColors.cyan,
                foregroundColor: KutraColors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  const _OtpCard({
    required this.account,
    required this.now,
    required this.onRemove,
  });

  final OtpAccount account;
  final DateTime now;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    final remaining = account.period - (seconds % account.period);
    final code = TotpGenerator.codeFor(account, now);
    final progress = remaining / account.period;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KutraColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KutraColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KutraColors.border),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: KutraColors.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayIssuer,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: KutraColors.cyan,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.displayLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: KutraColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Sil',
                color: KutraColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _groupCode(code),
                  style: const TextStyle(
                    color: KutraColors.text,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kod kopyalandı.')),
                  );
                },
                icon: const Icon(Icons.copy),
                tooltip: 'Kopyala',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  foregroundColor: KutraColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: remaining <= 5
                        ? KutraColors.danger
                        : KutraColors.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 38,
                child: Text(
                  '${remaining}s',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: KutraColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _groupCode(String code) {
    if (code.length <= 4) return code;
    final midpoint = code.length ~/ 2;
    return '${code.substring(0, midpoint)} ${code.substring(midpoint)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KutraColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KutraColors.borderStrong),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3300D9F5),
                  blurRadius: 32,
                  spreadRadius: -18,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_clock,
              color: KutraColors.cyan,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Henüz hesap yok',
            style: TextStyle(
              color: KutraColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Başlamak için servisindeki otpauth QR kodunu okut veya bağlantıyı yapıştır.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KutraColors.muted,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('QR kod oku'),
        backgroundColor: KutraColors.black,
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Fener',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KutraColors.cyan, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x6600D9F5),
                    blurRadius: 32,
                    spreadRadius: -12,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 20,
            right: 20,
            bottom: 34,
            child: Text(
              'otpauth QR kodunu çerçevenin içine getir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KutraColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
