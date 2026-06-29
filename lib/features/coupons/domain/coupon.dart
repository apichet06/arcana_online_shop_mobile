class Coupon {
  const Coupon({
    required this.coId,
    required this.coCode,
    required this.discountType,
    required this.discountValue,
    required this.maxDiscountAmount,
    required this.startAt,
    required this.endAt,
    required this.minOrderAmount,
    required this.active,
    required this.storeId,
    this.websiteKey,
    this.productIds = const [],
    this.isClaimed = false,
    this.userCouponStatus,
    this.claimedAt,
    this.usedAt,
  });

  final int coId;
  final String coCode;
  final String discountType;
  final double discountValue;
  final double? maxDiscountAmount;
  final String startAt;
  final String endAt;
  final double minOrderAmount;
  final int active;
  final int storeId;
  final String? websiteKey;
  final List<int> productIds;
  final bool isClaimed;
  final String? userCouponStatus;
  final String? claimedAt;
  final String? usedAt;

  bool get isPercent => discountType == 'percent';
  bool get isClaimable => active == 1 && !isClaimed && !isExpired;
  bool get isUsable =>
      active == 1 && userCouponStatus == 'claimed' && !isExpired;
  bool get isExpired {
    final end = _parseDate(endAt);
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  String get discountLabel {
    if (isPercent) {
      final maxText = maxDiscountAmount != null && maxDiscountAmount! > 0
          ? ' สูงสุด ฿${_formatCompact(maxDiscountAmount!)}'
          : '';
      return 'ลด ${_formatCompact(discountValue)}%$maxText';
    }
    return 'ลด ฿${_formatCompact(discountValue)}';
  }

  String get minOrderLabel => 'ขั้นต่ำ ฿${_formatCompact(minOrderAmount)}';

  String get endDateLabel {
    final date = _parseDate(endAt);
    if (date == null) return endAt.isEmpty ? '-' : endAt;
    final local = date.toLocal();
    final yyyy = local.year + 543;
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_thaiShortMonths[local.month - 1]} $yyyy $hh:$min น.';
  }

  String get endDateShortLabel {
    final date = _parseDate(endAt);
    if (date == null) return endAt.isEmpty ? '-' : _shortFallback(endAt);
    final local = date.toLocal();
    final yy = ((local.year + 543) % 100).toString().padLeft(2, '0');
    return '${local.day} ${_thaiShortMonths[local.month - 1]} $yy';
  }

  String get stateLabel {
    if (userCouponStatus == 'used') return 'ใช้แล้ว';
    if (userCouponStatus == 'cancelled') return 'ยกเลิก';
    if (userCouponStatus == 'expired' || isExpired) return 'หมดอายุ';
    if (isClaimed || userCouponStatus == 'claimed') return 'เก็บแล้ว';
    return 'รับได้';
  }

  factory Coupon.fromAvailableJson(Map<String, dynamic> json) {
    return Coupon(
      coId: _asInt(json['co_id']),
      coCode: json['co_code']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: _asDouble(json['discount_value']),
      maxDiscountAmount: _asDoubleNullable(json['max_discount_amount']),
      startAt: json['co_datetime_start']?.toString() ?? '',
      endAt: json['co_datetime_end']?.toString() ?? '',
      minOrderAmount: _asDouble(json['min_order_amount']),
      active: _asInt(json['active']),
      storeId: _asInt(json['st_id']),
      websiteKey: json['website_key']?.toString(),
      productIds: _asIntList(json['product_ids']),
      isClaimed: json['is_claimed'] == true,
      userCouponStatus: json['user_coupon_status']?.toString(),
    );
  }

  factory Coupon.fromUserJson(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    return Coupon(
      coId: _asInt(json['co_id']),
      coCode: json['co_code']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      discountValue: _asDouble(json['discount_value']),
      maxDiscountAmount: _asDoubleNullable(json['max_discount_amount']),
      startAt: json['co_datetime_start']?.toString() ?? '',
      endAt: json['co_datetime_end']?.toString() ?? '',
      minOrderAmount: _asDouble(json['min_order_amount']),
      active: _asInt(json['active']),
      storeId: _asInt(json['st_id']),
      isClaimed: status != null,
      userCouponStatus: status,
      claimedAt: json['claimed_at']?.toString(),
      usedAt: json['used_at']?.toString(),
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
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double? _asDoubleNullable(Object? v) {
    if (v == null) return null;
    return _asDouble(v);
  }

  static List<int> _asIntList(Object? v) {
    if (v is! List) return const [];
    return v.map(_asInt).where((id) => id > 0).toList();
  }

  static const List<String> _thaiShortMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  static DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final normalized = trimmed.replaceFirst(' ', 'T');
    final normalizedDate = DateTime.tryParse(normalized);
    if (normalizedDate != null) return normalizedDate;

    final withoutFraction = normalized.replaceFirst(RegExp(r'\.\d{1,6}$'), '');
    return DateTime.tryParse(withoutFraction) ?? _parseEnglishDate(trimmed);
  }

  static DateTime? _parseEnglishDate(String raw) {
    final match = RegExp(
      r'^(?:[A-Za-z]{3}\s+)?([A-Za-z]{3})\s+(\d{1,2})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(raw);
    if (match == null) return null;

    final month = _englishMonthMap[match.group(1)?.toLowerCase()];
    if (month == null) return null;

    return DateTime(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(2)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.tryParse(match.group(6) ?? '') ?? 0,
    );
  }

  static String _shortFallback(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length <= 14) return trimmed;
    return '${trimmed.substring(0, 14)}...';
  }

  static String _formatCompact(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  static const Map<String, int> _englishMonthMap = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
}

class CouponProduct {
  const CouponProduct({
    required this.couponId,
    required this.productId,
    required this.productCode,
    required this.productName,
  });

  final int couponId;
  final int productId;
  final String? productCode;
  final String? productName;

  factory CouponProduct.fromJson(Map<String, dynamic> json) {
    return CouponProduct(
      couponId: Coupon._asInt(json['co_id']),
      productId: Coupon._asInt(json['p_id']),
      productCode: json['p_code']?.toString(),
      productName: json['p_name']?.toString(),
    );
  }
}
