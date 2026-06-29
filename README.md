# Kutra Authenticator

Kutra Authenticator, `otpauth://totp` protokolünü destekleyen modern bir Flutter tabanlı iki faktörlü doğrulama uygulamasıdır. QR kod okuma, manuel otpauth bağlantısı ekleme, güvenli yerel saklama ve zaman bazlı tek kullanımlık kod üretimi sunar.

Uygulama Kutra web sitesinin koyu, cyan vurgulu ve minimal ürün tasarım dilini takip eder.

## Özellikler

- QR kod ile TOTP hesabı ekleme
- `otpauth://totp` bağlantılarını manuel ekleme
- SHA1, SHA256 ve SHA512 algoritmalarıyla TOTP üretimi
- 6, 7 ve 8 haneli doğrulama kodu desteği
- 10-120 saniye arası period desteği
- Kod kopyalama
- Hesap silme
- `flutter_secure_storage` ile cihazda güvenli saklama
- Android ve iOS kamera izni desteği

## Teknoloji

- Flutter
- Dart
- `mobile_scanner`
- `flutter_secure_storage`
- `crypto`

## Kurulum

Flutter SDK kurulu olmalıdır.

```bash
flutter pub get
```

## Çalıştırma

Bağlı cihaz veya emülatörde çalıştırmak için:

```bash
flutter run
```

Web sunucusu olarak çalıştırmak için:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5217
```

## Test ve Analiz

Birim testleri çalıştırmak için:

```bash
flutter test
```

Statik analiz için:

```bash
flutter analyze
```

## Otpauth Formatı

Desteklenen bağlantı formatı:

```text
otpauth://totp/Issuer:account@example.com?secret=BASE32SECRET&issuer=Issuer&algorithm=SHA1&digits=6&period=30
```

Zorunlu alan:

- `secret`

Opsiyonel alanlar:

- `issuer`
- `algorithm`
- `digits`
- `period`

## Güvenlik Notları

Hesap verileri cihaz üzerinde güvenli depolama alanında tutulur. Secret değerleri dış servise gönderilmez. QR koddan okunan veya manuel girilen veriler yalnızca cihazdaki TOTP kod üretimi için kullanılır.

## Lisans

Bu proje `LICENSE` dosyasında belirtilen lisans koşullarıyla dağıtılır.
