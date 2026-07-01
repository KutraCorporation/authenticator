# Kutra Authenticator

A privacy-first, cross-platform authentication system built for modern applications.

Kutra Authenticator is not just a login system — it is a secure identity layer designed for offline-first usage, encrypted backups, and full OTPAuth compatibility.

## 🚀 Vision

Replace fragmented authentication apps with a unified, open, and secure identity ecosystem.

## ⚙️ Core Features

- 🔐 OTPAuth-compatible TOTP generator (RFC 6238)
- 📱 Cross-platform support (Flutter: Android, iOS, Windows, macOS, Linux)
- 🧠 Offline-first architecture (no mandatory cloud dependency)
- 🔑 Secure local encrypted storage
- 📷 QR code scanning and provisioning support
- 🔄 Import / export encrypted vault
- 🌐 Optional cloud sync (end-to-end encrypted)

## 🧩 Architecture

- Flutter (UI layer)
- TypeScript SDK (web integration)
- Dart OTPAuth parser (core library)

## 🔐 Security Model

- Secrets never leave device unencrypted
- AES-256 encrypted local storage
- Optional device-to-device encrypted sync via mDNS or cloud relay
- No tracking, no telemetry

## 📲 Supported Platforms

- Android (APK / AAB)
- iOS (IPA)
- Windows (EXE)
- macOS (DMG)
- Linux (AppImage / Flatpak)

## 🛠️ Installation

```bash
git clone https://github.com/KutraCorporation/authenticator.git
cd authenticator
flutter pub get
flutter run
```

## 🤝 Contributing

Kutra is open-source. Contributors can extend:

OTPAuth parsing engine
encryption modules
platform integrations

##  License
Open-source (MIT / Apache 2.0 depending on module)

> Built with privacy, simplicity, and developer freedom in mind.<br/>Kutra Corporation — Beyond Limits.