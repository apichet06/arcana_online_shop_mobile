import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/core/network/api_paths.dart';
import 'package:arcana_online_shop_mobile/features/profile/domain/profile_data.dart';

// จัดการ API call ที่เกี่ยวกับโปรไฟล์ผู้ใช้
// ApiClient ดูแล Authorization header และ token refresh ให้อัตโนมัติ
class ProfileApi {
  ProfileApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  // ดึงข้อมูลโปรไฟล์ของ user ที่ล็อกอินอยู่ (GET /auth/me)
  Future<ProfileData> fetchProfile() async {
    final res = await _client.get(ApiPaths.profile);
    final data = res['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response');
    }
    return ProfileData.fromJson(data);
  }

  // อัปเดตโปรไฟล์ (PATCH /auth/me) — ส่งเฉพาะ field ที่แก้ได้
  // birthday และ gender ส่ง null ได้เพื่อล้างค่า
  Future<ProfileData> updateProfile({
    required String username,
    String? birthday,
    String? gender,
  }) async {
    final body = <String, dynamic>{'u_username': username};
    body['u_birthday'] = birthday;
    body['u_gender'] = gender;

    final res = await _client.patch(ApiPaths.profile, data: body);
    final data = res['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response');
    }
    return ProfileData.fromJson(data);
  }
}
