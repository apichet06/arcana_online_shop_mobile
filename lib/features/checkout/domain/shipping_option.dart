class ShippingOption {
  const ShippingOption({
    required this.scId,
    required this.scCode,
    required this.scName,
    required this.price,
    required this.billedWeightG,
    required this.zoneCode,
  });

  final int scId;
  final String scCode;
  final String scName;
  final double? price;
  final int billedWeightG;
  final String zoneCode;

  factory ShippingOption.fromJson(Map<String, dynamic> json) {
    return ShippingOption(
      scId: _asInt(json['sc_id']),
      scCode: json['sc_code']?.toString() ?? '',
      scName: json['sc_name']?.toString() ?? '',
      price: json['price'] != null ? _asDouble(json['price']) : null,
      billedWeightG: _asInt(json['billed_weight_g']),
      zoneCode: json['zone_code']?.toString() ?? '',
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}
