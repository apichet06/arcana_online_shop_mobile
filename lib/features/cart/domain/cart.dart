import 'package:arcana_online_shop_mobile/features/cart/domain/cart_item.dart';

// Domain model สำหรับตะกร้าสินค้าทั้งใบ
// ตรงกับ CartDTO ฝั่ง API
class Cart {
  const Cart({
    required this.cartId,
    required this.status,
    required this.items,
    required this.totalAmount,
    required this.itemCount,
  });

  final int cartId;
  final String status;
  final List<CartItem> items;
  // รวมทุก item ไม่ว่าจะ selected หรือไม่ (มาจาก server)
  final double totalAmount;
  // จำนวน item ทั้งหมดใน cart (ใช้แสดง badge)
  final int itemCount;

  // ราคารวมเฉพาะ item ที่ is_selected = true (ใช้แสดงใน summary bar)
  double get selectedTotal {
    return items
        .where((item) => item.isSelected)
        .fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  // จำนวน item ที่เลือกสำหรับ checkout
  int get selectedCount => items.where((item) => item.isSelected).length;

  // true = ทุก item ถูกเลือก (checkbox หลักแสดง ✓)
  bool get allSelected => items.isNotEmpty && items.every((i) => i.isSelected);

  // true = เลือกบางส่วน (checkbox หลักแสดง indeterminate −)
  bool get someSelected => items.any((i) => i.isSelected) && !allSelected;

  bool get isEmpty => items.isEmpty;

  // สร้าง Cart ใหม่จาก items ที่เปลี่ยน พร้อม recalculate totals
  // ใช้ใน optimistic updates (remove / toggleSelect)
  Cart withItems(List<CartItem> newItems) {
    final total = newItems.fold(0.0, (s, i) => s + i.lineTotal);
    return Cart(
      cartId: cartId,
      status: status,
      items: newItems,
      totalAmount: total,
      itemCount: newItems.length,
    );
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(CartItem.fromJson)
            .toList()
        : const <CartItem>[];

    return Cart(
      cartId: _asInt(json['cart_id']),
      status: (json['status'] as String?) ?? 'active',
      items: items,
      totalAmount: _asDouble(json['total_amount']),
      itemCount: _asInt(json['item_count']),
    );
  }

  // ใช้เป็น initial state ก่อนโหลดข้อมูลจาก API
  static const Cart empty = Cart(
    cartId: 0,
    status: 'active',
    items: [],
    totalAmount: 0,
    itemCount: 0,
  );
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  return int.tryParse(value.toString()) ?? 0;
}

double _asDouble(dynamic value) {
  if (value == null) return 0.0;
  return double.tryParse(value.toString()) ?? 0.0;
}
