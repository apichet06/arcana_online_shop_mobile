import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/core/network/api_paths.dart';
import 'package:arcana_online_shop_mobile/features/address/domain/address.dart';

// จัดการ API call ทั้งหมดของที่อยู่จัดส่ง
class AddressApi {
  AddressApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  // ดึงรายการที่อยู่ทั้งหมดของ user (GET /auth/me/addresses)
  Future<List<Address>> fetchAddresses() async {
    final res = await _client.get(ApiPaths.addresses);
    final data = res['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(Address.fromJson).toList();
  }

  // เพิ่มที่อยู่ใหม่ (POST /auth/me/addresses)
  Future<void> addAddress(AddressInput input) async {
    await _client.post(ApiPaths.addresses, data: input.toJson());
  }

  // แก้ไขที่อยู่ (PATCH /auth/me/addresses/:id)
  Future<void> updateAddress(int id, AddressInput input) async {
    await _client.patch(ApiPaths.addressById(id), data: input.toJson());
  }

  // ตั้งเป็นที่อยู่หลัก (PATCH /auth/me/addresses/:id/default)
  Future<void> setDefault(int id) async {
    await _client.patch(ApiPaths.addressSetDefault(id));
  }

  // ลบที่อยู่ (DELETE /auth/me/addresses/:id)
  // หมายเหตุ: API ไม่อนุญาตลบที่อยู่หลัก — ตรวจสอบจาก UI ก่อนเรียก
  Future<void> deleteAddress(int id) async {
    await _client.delete(ApiPaths.addressById(id));
  }
}
