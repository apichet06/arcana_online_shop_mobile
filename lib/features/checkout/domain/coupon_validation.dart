class CouponValidation {
  const CouponValidation({
    required this.coCode,
    required this.discountType,
    required this.discountValue,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.grandTotalAmount,
  });

  final String coCode;
  final String discountType;
  final double discountValue;
  final double subtotalAmount;
  final double discountAmount;
  final double grandTotalAmount;

  factory CouponValidation.fromJson(Map<String, dynamic> json) {
    final coupon = json['coupon'] as Map<String, dynamic>? ?? {};
    return CouponValidation(
      coCode: coupon['co_code']?.toString() ?? '',
      discountType: coupon['discount_type']?.toString() ?? '',
      discountValue: _asDouble(coupon['discount_value']),
      subtotalAmount: _asDouble(json['subtotal_amount']),
      discountAmount: _asDouble(json['discount_amount']),
      grandTotalAmount: _asDouble(json['grand_total_amount']),
    );
  }

  static double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}
