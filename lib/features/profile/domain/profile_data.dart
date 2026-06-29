// Model ข้อมูลโปรไฟล์ผู้ใช้ — map ตรงกับ response ของ GET /auth/me
class ProfileData {
  const ProfileData({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    this.birthday,
    this.gender,
    required this.provider,
  });

  final int id;
  final String username;
  final String email;
  final String? avatar;   // path หรือ URL รูปโปรไฟล์ อาจเป็น null
  final String? birthday; // รูปแบบ ISO date string เช่น "1999-12-31"
  final String? gender;   // 'MALE' | 'FEMALE' | 'OTHER' | null
  final String provider;  // วิธีล็อกอิน เช่น 'google', 'facebook', 'email'

  // แปลง JSON จาก API เป็น ProfileData
  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: _asInt(json['u_id']),
      username: json['u_username']?.toString() ?? '',
      email: json['u_email']?.toString() ?? '',
      avatar: json['u_avatar']?.toString(),
      birthday: json['u_birthday']?.toString(),
      gender: json['u_gender']?.toString(),
      provider: json['u_provider']?.toString() ?? '',
    );
  }

  // สร้าง copy ที่แก้ได้เฉพาะ field ที่ PATCH ได้ (email/id/provider เปลี่ยนไม่ได้)
  ProfileData copyWith({
    String? username,
    String? birthday,
    String? gender,
  }) {
    return ProfileData(
      id: id,
      username: username ?? this.username,
      email: email,
      avatar: avatar,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      provider: provider,
    );
  }

  // API บางครั้งส่ง u_id เป็น String หรือ double — แปลงให้เป็น int เสมอ
  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
