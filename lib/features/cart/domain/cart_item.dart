// Domain model สำหรับ 1 รายการสินค้าในตะกร้า
// ตรงกับ CartItemDetailDTO ฝั่ง API
class CartItem {
  const CartItem({
    required this.ciId,
    required this.cartId,
    required this.pvId,
    required this.qty,
    required this.unitPrice,
    required this.discountAmount,
    required this.lineTotal,
    required this.isSelected,
    this.sku,
    this.variantLabel,
    this.imageUrl,
    required this.productId,
    required this.catalogId,
    this.productName,
    required this.storeId,
    this.storeName,
  });

  final int ciId;
  final int cartId;
  final int pvId;
  final int qty;
  final double unitPrice;
  final double discountAmount;
  // ราคารวม qty ชิ้น (คำนวณจาก server)
  final double lineTotal;
  // true = เลือกสำหรับ checkout
  final bool isSelected;
  final String? sku;
  final String? variantLabel;
  final String? imageUrl;
  final int productId;
  final int catalogId;
  final String? productName;
  final int storeId;
  final String? storeName;

  // ราคาต่อหน่วยหลังหักส่วนลด
  double get effectiveUnitPrice => unitPrice - discountAmount;
  bool get hasDiscount => discountAmount > 0;

  // ชื่อแสดงผล — ใช้ชื่อสินค้าตามภาษาที่ fetch มา
  String get displayName => productName ?? '';

  // ชื่อ variant เช่น "สี: แดง | ขนาด: L" หรือ SKU ถ้าไม่มี label
  String get displayVariant => variantLabel ?? sku ?? '';

  CartItem copyWith({int? qty, double? lineTotal, bool? isSelected}) {
    return CartItem(
      ciId: ciId,
      cartId: cartId,
      pvId: pvId,
      qty: qty ?? this.qty,
      unitPrice: unitPrice,
      discountAmount: discountAmount,
      lineTotal: lineTotal ?? this.lineTotal,
      isSelected: isSelected ?? this.isSelected,
      sku: sku,
      variantLabel: variantLabel,
      imageUrl: imageUrl,
      productId: productId,
      catalogId: catalogId,
      productName: productName,
      storeId: storeId,
      storeName: storeName,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      ciId: _asInt(json['ci_id']),
      cartId: _asInt(json['cart_id']),
      pvId: _asInt(json['pv_id']),
      qty: _asInt(json['qty']),
      unitPrice: _asDouble(json['unit_price']),
      discountAmount: _asDouble(json['discount_amount']),
      lineTotal: _asDouble(json['line_total']),
      isSelected: _asInt(json['is_selected']) == 1,
      sku: json['pv_sku'] as String?,
      variantLabel: json['variant_label'] as String?,
      imageUrl: json['image_url'] as String?,
      productId: _asInt(json['p_id']),
      catalogId: _asInt(json['ctl_id']),
      productName: json['p_name'] as String?,
      storeId: _asInt(json['st_id']),
      storeName: json['st_company_name'] as String?,
    );
  }
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  return int.tryParse(value.toString()) ?? 0;
}

double _asDouble(dynamic value) {
  if (value == null) return 0.0;
  return double.tryParse(value.toString()) ?? 0.0;
}
