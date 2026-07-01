import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart' show Share;

import 'models/otp_account.dart';
import 'services/account_store.dart';
import 'services/backup_service.dart';
import 'services/otp_gen.dart';
import 'services/otp_parser.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const _LockGate(),
    );
  }
}

class _LockGate extends StatefulWidget {
  const _LockGate();

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  final _store = SecureAccountStore();
  final _auth = LocalAuthentication();
  bool _locked = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final enabled = await _store.getBiometricEnabled();
    if (!enabled) {
      if (!mounted) return;
      setState(() => _locked = false);
      return;
    }
    await _authenticate();
  }

  Future<void> _authenticate() async {
    final available = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    if (!available) {
      if (!mounted) return;
      setState(() => _locked = false);
      return;
    }
    try {
      final success = await _auth.authenticate(
        localizedReason: 'Kutra Authenticator\'ı açmak için kimlik doğrulaması yapın.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (success) {
        setState(() => _locked = false);
      } else {
        setState(() => _denied = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _locked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_denied) {
      return Scaffold(
        backgroundColor: KutraColors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint, color: KutraColors.danger, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Kimlik doğrulaması gerekiyor',
                  style: TextStyle(color: KutraColors.text, fontSize: 20, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Uygulamaya erişmek için biyometrik doğrulama yapmalısınız.',
                  style: TextStyle(color: KutraColors.muted, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _denied = false);
                    _authenticate();
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Tekrar dene'),
                  style: FilledButton.styleFrom(
                    backgroundColor: KutraColors.cyan,
                    foregroundColor: KutraColors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_locked) {
      return Scaffold(
        backgroundColor: KutraColors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(colors: [KutraColors.cyan, KutraColors.purple]),
                ),
                child: const Text('K', style: TextStyle(color: KutraColors.black, fontSize: 32, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 16),
              const Text('Kutra', style: TextStyle(color: KutraColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: KutraColors.cyan)),
            ],
          ),
        ),
      );
    }
    return const AuthenticatorHome();
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

  Future<void> _saveAccounts() => _store.save(_accounts);

  Future<void> _addFromUri(String value) async {
    final account = OtpAuthParser.parse(value);
    setState(() => _accounts.add(account));
    await _saveAccounts();
  }

  Future<void> _remove(OtpAccount account) async {
    setState(() => _accounts.remove(account));
    await _saveAccounts();
  }

  Future<void> _advanceHotp(OtpAccount account) async {
    final idx = _accounts.indexOf(account);
    if (idx < 0) return;
    final updated = account.copyWith(counter: account.counter + 1);
    setState(() => _accounts[idx] = updated);
    await _saveAccounts();
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

  Future<void> _exportAccounts() async {
    final json = BackupService.exportJson(_accounts);
    await Share.share(json, subject: 'Kutra Authenticator Yedek');
  }

  Future<void> _importAccounts() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      final json = utf8.decode(bytes);
      final imported = BackupService.importJson(json);
      if (imported.isEmpty) {
        _showMessage('Dosyada hesap bulunamadı.');
        return;
      }
      setState(() => _accounts.addAll(imported));
      await _saveAccounts();
      if (!mounted) return;
      _showMessage('${imported.length} hesap içe aktarıldı.');
    } catch (e) {
      _showMessage('İçe aktarma başarısız: $e');
    }
  }

  Future<void> _exportEncryptedBackup() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KutraColors.panel,
        title: const Text('Şifreli Yedek Oluştur', style: TextStyle(color: KutraColors.text)),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: KutraColors.text),
          decoration: const InputDecoration(
            hintText: 'Yedek şifresi',
            hintStyle: TextStyle(color: KutraColors.dim),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oluştur')),
        ],
      ),
    );
    if (confirmed != true || passwordController.text.isEmpty) return;
    try {
      final encrypted = BackupService.exportEncrypted(_accounts, passwordController.text);
      await Share.share(encrypted, subject: 'Kutra Şifreli Yedek');
      if (!mounted) return;
      _showMessage('Şifreli yedek paylaşıldı.');
    } catch (e) {
      _showMessage('Yedek oluşturma başarısız: $e');
    }
  }

  Future<void> _importEncryptedBackup() async {
    final passwordController = TextEditingController();
    late final String encryptedData;
    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (pickResult == null || pickResult.files.isEmpty) return;
      final bytes = pickResult.files.first.bytes;
      if (bytes == null) return;
      encryptedData = utf8.decode(bytes).trim();
    } catch (_) {
      _showMessage('Dosya okunamadı.');
      return;
    }
    if (encryptedData.isEmpty) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KutraColors.panel,
        title: const Text('Şifreli Yedeği Geri Yükle', style: TextStyle(color: KutraColors.text)),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: KutraColors.text),
          decoration: const InputDecoration(
            hintText: 'Yedek şifresi',
            hintStyle: TextStyle(color: KutraColors.dim),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri Yükle')),
        ],
      ),
    );
    if (confirmed != true || passwordController.text.isEmpty) return;
    try {
      final imported = BackupService.importEncrypted(encryptedData, passwordController.text);
      setState(() => _accounts
        ..clear()
        ..addAll(imported));
      await _saveAccounts();
      if (!mounted) return;
      _showMessage('${imported.length} hesap geri yüklendi.');
    } catch (e) {
      _showMessage('Geri yükleme başarısız: ${e is FormatException ? e.message : e}');
    }
  }

  Future<void> _showSettings() async {
    final biometricEnabled = await _store.getBiometricEnabled();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: KutraColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 32, height: 4,
              decoration: BoxDecoration(color: KutraColors.dim, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Ayarlar', style: TextStyle(color: KutraColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined, color: KutraColors.cyan),
              title: const Text('Dışa Aktar (JSON)', style: TextStyle(color: KutraColors.text)),
              onTap: () { Navigator.pop(ctx); _exportAccounts(); },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined, color: KutraColors.cyan),
              title: const Text('İçe Aktar (JSON)', style: TextStyle(color: KutraColors.text)),
              onTap: () { Navigator.pop(ctx); _importAccounts(); },
            ),
            const Divider(color: KutraColors.border, height: 1),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: KutraColors.purple),
              title: const Text('Şifreli Yedek Oluştur', style: TextStyle(color: KutraColors.text)),
              onTap: () { Navigator.pop(ctx); _exportEncryptedBackup(); },
            ),
            ListTile(
              leading: const Icon(Icons.lock_open, color: KutraColors.purple),
              title: const Text('Şifreli Yedeği Geri Yükle', style: TextStyle(color: KutraColors.text)),
              onTap: () { Navigator.pop(ctx); _importEncryptedBackup(); },
            ),
            const Divider(color: KutraColors.border, height: 1),
            StatefulBuilder(
              builder: (ctx, setInnerState) => SwitchListTile(
                secondary: Icon(
                  Icons.fingerprint,
                  color: biometricEnabled ? KutraColors.cyan : KutraColors.dim,
                ),
                title: const Text('Biyometrik Kilit', style: TextStyle(color: KutraColors.text)),
                value: biometricEnabled,
                activeColor: KutraColors.cyan,
                onChanged: (value) async {
                  await _store.setBiometricEnabled(value);
                  setInnerState(() {});
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;
          final hp = isDesktop ? 40.0 : 16.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hp, isDesktop ? 20 : 8, hp, 8),
                      child: _Header(
                        onScan: _openScanner,
                        onSettings: _showSettings,
                        isDesktop: isDesktop,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hp, 0, hp, 16),
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
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(onScan: _openScanner),
                    )
                  else if (isDesktop)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(hp, 0, hp, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final account = _accounts[index];
                            return _OtpCard(
                              account: account,
                              now: _now,
                              onRemove: () => _remove(account),
                              onAdvance: account.type == 'hotp'
                                  ? () => _advanceHotp(account)
                                  : null,
                              compact: true,
                            );
                          },
                          childCount: _accounts.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(hp, 0, hp, 80),
                      sliver: SliverList.separated(
                        itemCount: _accounts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final account = _accounts[index];
                          return _OtpCard(
                            account: account,
                            now: _now,
                            onRemove: () => _remove(account),
                            onAdvance: account.type == 'hotp'
                                ? () => _advanceHotp(account)
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _accounts.isNotEmpty && !_loading
          ? FloatingActionButton(
              onPressed: _openScanner,
              backgroundColor: KutraColors.cyan,
              foregroundColor: KutraColors.black,
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onScan,
    required this.onSettings,
    this.isDesktop = false,
  });

  final VoidCallback onScan;
  final VoidCallback onSettings;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _DesktopHeader(
        onScan: onScan,
        onSettings: onSettings,
      );
    }
    return _MobileHeader(
      onScan: onScan,
      onSettings: onSettings,
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.onScan,
    required this.onSettings,
  });

  final VoidCallback onScan;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [KutraColors.cyan, KutraColors.purple]),
          ),
          child: const Text('K', style: TextStyle(color: KutraColors.black, fontSize: 20, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Kutra',
            style: TextStyle(
              color: KutraColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Ayarlar',
          color: KutraColors.muted,
        ),
        IconButton.filled(
          onPressed: onScan,
          icon: const Icon(Icons.qr_code_scanner, size: 22),
          tooltip: 'QR kod oku',
          style: IconButton.styleFrom(
            backgroundColor: KutraColors.cyan,
            foregroundColor: KutraColors.black,
            minimumSize: const Size(40, 40),
          ),
        ),
      ],
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.onScan,
    required this.onSettings,
  });

  final VoidCallback onScan;
  final VoidCallback onSettings;

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
          color: KutraColors.panel.withAlpha(199),
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
                IconButton(
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Ayarlar',
                  color: KutraColors.muted,
                ),
                const SizedBox(width: 4),
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
              'Sınırların ötesinde güvenlik: QR kodu okut veya otpauth bağlantısını yapıştır, TOTP/HOTP kodlarını cihazında güvenli alanda sakla.',
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
                _FeaturePill(icon: Icons.smart_button, label: 'HOTP / TOTP'),
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
        color: Colors.white.withAlpha(13),
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
  const _ManualEntry({
    required this.controller,
    required this.onSubmit,
  });

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
              onSubmitted: (_) => onSubmit(),
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
    this.onAdvance,
    this.compact = false,
  });

  final OtpAccount account;
  final DateTime now;
  final VoidCallback onRemove;
  final VoidCallback? onAdvance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isHotp = account.type == 'hotp';

    String code;
    double? progress;
    int? remaining;

    if (isHotp) {
      code = HotpGenerator.codeFor(account);
    } else {
      final seconds = now.millisecondsSinceEpoch ~/ 1000;
      remaining = account.period - (seconds % account.period);
      code = TotpGenerator.codeFor(account, now);
      progress = remaining / account.period;
    }

    final codeFontSize = compact
        ? 26.0
        : code.length > 8 ? 26.0 : 34.0;

    return Dismissible(
      key: ValueKey('otp_${account.secret}_${account.type}_${account.counter}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: KutraColors.danger.withAlpha(40),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: KutraColors.danger, size: 28),
      ),
      confirmDismiss: (_) async {
        onRemove();
        return false;
      },
      child: Container(
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: BoxDecoration(
          color: KutraColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: KutraColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 32 : 36,
                  height: compact ? 32 : 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: KutraColors.border),
                  ),
                  child: Icon(
                    isHotp ? Icons.smart_button_outlined : Icons.shield_outlined,
                    color: KutraColors.cyan,
                    size: compact ? 18 : 22,
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayIssuer,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: KutraColors.cyan,
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      Text(
                        account.displayLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: KutraColors.muted,
                          fontSize: compact ? 12 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isHotp)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: KutraColors.purple.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KutraColors.purple.withAlpha(80)),
                    ),
                    child: Text(
                      'HOTP',
                      style: TextStyle(
                        color: KutraColors.purple,
                        fontSize: compact ? 9 : 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.delete_outline, size: compact ? 18 : 22),
                  tooltip: 'Sil',
                  color: KutraColors.muted,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                  _groupCode(code),
                  style: TextStyle(
                    color: KutraColors.text,
                    fontSize: codeFontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                ),
                if (isHotp)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton.filled(
                      onPressed: onAdvance,
                      icon: const Icon(Icons.skip_next, size: 22),
                      tooltip: 'Sonraki kod',
                      style: IconButton.styleFrom(
                        backgroundColor: KutraColors.purple,
                        foregroundColor: KutraColors.black,
                        minimumSize: const Size(40, 40),
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
                  icon: Icon(Icons.copy, size: compact ? 18 : 22),
                  tooltip: 'Kopyala',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(15),
                    foregroundColor: KutraColors.text,
                    minimumSize: const Size(40, 40),
                  ),
                ),
              ],
            ),
            if (!isHotp) ...[
              SizedBox(height: compact ? 8 : 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: compact ? 5 : 6,
                        backgroundColor: Colors.white.withAlpha(20),
                        color: remaining! <= 5
                            ? KutraColors.danger
                            : KutraColors.cyan,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${remaining}s',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: KutraColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(height: compact ? 8 : 10),
              Row(
                children: [
                  Icon(Icons.replay, size: 13, color: KutraColors.dim),
                  const SizedBox(width: 4),
                  Text(
                    'Adım ${account.counter}',
                    style: TextStyle(
                      color: KutraColors.dim,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _groupCode(String code) {
    return code;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onScan});

  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
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
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Henüz hesap yok',
            style: TextStyle(
              color: KutraColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Başlamak için servisindeki otpauth QR kodunu okut veya bağlantıyı yapıştır.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: KutraColors.muted,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onScan != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QR Kod Okut'),
              style: FilledButton.styleFrom(
                backgroundColor: KutraColors.cyan,
                foregroundColor: KutraColors.black,
              ),
            ),
          ],
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
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('QR kod oku'),
        backgroundColor: Colors.transparent,
        foregroundColor: KutraColors.text,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Fener',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth < constraints.maxHeight
              ? constraints.maxWidth * 0.75
              : constraints.maxHeight * 0.55;
          return Stack(
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              Center(
                child: Container(
                  width: size,
                  height: size,
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
              Positioned(
                left: 20,
                right: 20,
                bottom: 34,
                child: Text(
                  'otpauth QR kodunu çerçevenin içine getir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KutraColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: isDesktop ? 16 : 14,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
