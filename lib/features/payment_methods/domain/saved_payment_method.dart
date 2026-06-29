class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.upmId,
    required this.cardBrand,
    required this.cardLast4,
    required this.cardName,
    required this.expirationMonth,
    required this.expirationYear,
    required this.isDefault,
  });

  final int upmId;
  final String? cardBrand;
  final String cardLast4;
  final String? cardName;
  final int? expirationMonth;
  final int? expirationYear;
  final bool isDefault;

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) {
    return SavedPaymentMethod(
      upmId: json['upm_id'] as int,
      cardBrand: json['card_brand'] as String?,
      cardLast4: json['card_last4'] as String,
      cardName: json['card_name'] as String?,
      expirationMonth: json['expiration_month'] as int?,
      expirationYear: json['expiration_year'] as int?,
      isDefault: json['is_default'] == true,
    );
  }

  String get displayLabel =>
      '${cardBrand ?? 'Card'} ●●●● $cardLast4';

  String get expiryLabel {
    if (expirationMonth == null || expirationYear == null) return '';
    final mm = expirationMonth!.toString().padLeft(2, '0');
    final yy = expirationYear!.toString().substring(2);
    return '$mm/$yy';
  }

  SavedPaymentMethod copyWith({bool? isDefault}) {
    return SavedPaymentMethod(
      upmId: upmId,
      cardBrand: cardBrand,
      cardLast4: cardLast4,
      cardName: cardName,
      expirationMonth: expirationMonth,
      expirationYear: expirationYear,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
