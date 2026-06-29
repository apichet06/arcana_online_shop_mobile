import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/core/network/api_paths.dart';
import 'package:arcana_online_shop_mobile/features/cart/domain/cart.dart';

// Data layer สำหรับ cart — เรียก REST API ของ /api/cart
class CartApi {
  const CartApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  // ดึงตะกร้าพร้อม item ทั้งหมด รวมชื่อสินค้าตามภาษาที่กำหนด
  Future<Cart> fetchCart({String lgCode = 'th'}) async {
    final res = await _client.get(
      ApiPaths.cart,
      queryParameters: {'lg_code': lgCode},
    );
    final data = res['data'];
    if (data is Map<String, dynamic>) return Cart.fromJson(data);
    // ถ้า response format ไม่ตรง fallback เป็น empty cart
    return Cart.empty;
  }

  // เพิ่มสินค้าลงตะกร้า — server จะ +qty อัตโนมัติถ้า pv_id ซ้ำกัน
  Future<void> addItem({required int pvId, required int qty}) async {
    await _client.post(
      ApiPaths.cartItems,
      data: {'pv_id': pvId, 'qty': qty},
    );
  }

  // แก้ไขจำนวนสินค้าใน cart item — server recalculate line_total ให้
  Future<void> updateItemQty({required int ciId, required int qty}) async {
    await _client.put(
      ApiPaths.cartItem(ciId),
      data: {'qty': qty},
    );
  }

  // toggle เลือก/ยกเลิกเลือก item สำหรับคำนวณ checkout total
  Future<void> toggleItemSelect({
    required int ciId,
    required bool isSelected,
  }) async {
    await _client.put(
      ApiPaths.cartItemSelect(ciId),
      data: {'is_selected': isSelected ? 1 : 0},
    );
  }

  // ลบ cart item — server ลบ Carts row ด้วยถ้าเหลือ item 0 ชิ้น
  Future<void> removeItem({required int ciId}) async {
    await _client.delete(ApiPaths.cartItem(ciId));
  }
}
