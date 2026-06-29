// Model ที่อยู่จัดส่ง — map ตรงกับ response ของ GET /auth/me/addresses
class Address {
  const Address({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.provincesId,
    required this.districtsId,
    required this.subdistrictsId,
    required this.zipCode,
    required this.provinceName,
    required this.districtName,
    required this.subdistrictName,
    required this.isDefault,
  });

  final int id;
  final String recipientName;
  final String phone;
  final String addressLine;
  final int provincesId;
  final int districtsId;
  final int subdistrictsId;
  final String zipCode;
  final String provinceName;
  final String districtName;
  final String subdistrictName;
  final bool isDefault;

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: _asInt(json['locb_id']),
      recipientName: json['locb_recipient_name']?.toString() ?? '',
      phone: json['locb_phone']?.toString() ?? '',
      addressLine: json['locb_address']?.toString() ?? '',
      provincesId: _asInt(json['provinces_id']),
      districtsId: _asInt(json['districts_id']),
      subdistrictsId: _asInt(json['subdistricts_id']),
      zipCode: json['zip_code']?.toString() ?? '',
      provinceName: json['province_name']?.toString() ?? '',
      districtName: json['district_name']?.toString() ?? '',
      subdistrictName: json['subdistrict_name']?.toString() ?? '',
      isDefault: json['is_default'] == true,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// Input สำหรับ POST/PATCH — ไม่มี id เพราะ API รับจาก path parameter
class AddressInput {
  const AddressInput({
    required this.recipientName,
    required this.phone,
    required this.addressLine,
    required this.provincesId,
    required this.districtsId,
    required this.subdistrictsId,
    required this.zipCode,
    required this.isDefault,
  });

  final String recipientName;
  final String phone;
  final String addressLine;
  final int provincesId;
  final int districtsId;
  final int subdistrictsId;
  final String zipCode;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        'locb_recipient_name': recipientName,
        'locb_phone': phone,
        'locb_address': addressLine,
        'provinces_id': provincesId,
        'districts_id': districtsId,
        'subdistricts_id': subdistrictsId,
        'zip_code': zipCode,
        'is_default': isDefault,
      };
}
