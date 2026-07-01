class OtpAccount {
  final String type;
  final String issuer;
  final String label;
  final String secret;
  final String algorithm;
  final int digits;
  final int period;
  final int counter;
  final Map<String, String> customParameters;

  const OtpAccount({
    this.type = 'totp',
    required this.issuer,
    required this.label,
    required this.secret,
    this.algorithm = 'SHA1',
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
    this.customParameters = const {},
  });

  OtpAccount copyWith({
    String? type,
    String? issuer,
    String? label,
    String? secret,
    String? algorithm,
    int? digits,
    int? period,
    int? counter,
    Map<String, String>? customParameters,
  }) {
    return OtpAccount(
      type: type ?? this.type,
      issuer: issuer ?? this.issuer,
      label: label ?? this.label,
      secret: secret ?? this.secret,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      counter: counter ?? this.counter,
      customParameters: customParameters ?? this.customParameters,
    );
  }

  String get displayIssuer => issuer.isEmpty ? 'Kutra' : issuer;

  String get displayLabel {
    if (label.isEmpty) return 'Yeni hesap';
    final issuerPrefix = '$issuer:';
    return label.startsWith(issuerPrefix)
        ? label.substring(issuerPrefix.length)
        : label;
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'issuer': issuer,
    'label': label,
    'secret': secret,
    'algorithm': algorithm,
    'digits': digits,
    'period': period,
    'counter': counter,
    if (customParameters.isNotEmpty) 'customParameters': customParameters,
  };

  factory OtpAccount.fromJson(Map<String, dynamic> json) => OtpAccount(
    type: json['type'] as String? ?? 'totp',
    issuer: json['issuer'] as String? ?? '',
    label: json['label'] as String? ?? '',
    secret: json['secret'] as String? ?? '',
    algorithm: json['algorithm'] as String? ?? 'SHA1',
    digits: json['digits'] as int? ?? 6,
    period: json['period'] as int? ?? 30,
    counter: json['counter'] as int? ?? 0,
    customParameters: json['customParameters'] != null
        ? Map<String, String>.from(json['customParameters'] as Map)
        : const {},
  );
}
