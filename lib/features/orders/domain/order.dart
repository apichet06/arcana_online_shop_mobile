class OrderItem {
  const OrderItem({
    required this.oiId,
    required this.pvId,
    this.imageUrl,
    required this.productName,
    this.variantName,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.originalUnitPrice,
    this.originalLineTotal,
    this.discountAmount,
    this.storeName,
  });

  final int oiId;
  final int pvId;
  final String? imageUrl;
  final String productName;
  final String? variantName;
  final int qty;
  final double unitPrice;
  final double lineTotal;
  final double? originalUnitPrice;
  final double? originalLineTotal;
  final double? discountAmount;
  final String? storeName;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      oiId: _toInt(json['oi_id']),
      pvId: _toInt(json['pv_id']),
      imageUrl: json['image_url'] as String?,
      productName: json['product_name'] as String? ?? '',
      variantName: json['variant_name'] as String?,
      qty: _toInt(json['qty']),
      unitPrice: _toDouble(json['unit_price']),
      lineTotal: _toDouble(json['line_total']),
      originalUnitPrice: _toDoubleNullable(json['original_unit_price']),
      originalLineTotal: _toDoubleNullable(json['original_line_total']),
      discountAmount: _toDoubleNullable(json['discount_amount']),
      storeName: json['store_name'] as String? ?? json['st_company_name'] as String?,
    );
  }
}

class ShipmentEvent {
  const ShipmentEvent({
    this.status,
    required this.title,
    this.description,
    this.location,
    required this.occurredAt,
  });

  final String? status;
  final String title;
  final String? description;
  final String? location;
  final String occurredAt;

  factory ShipmentEvent.fromJson(Map<String, dynamic> json) {
    return ShipmentEvent(
      status: json['status'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      location: json['location'] as String?,
      occurredAt: json['occurred_at'] as String? ?? '',
    );
  }
}

class Order {
  const Order({
    required this.orId,
    this.orderNo,
    required this.status,
    this.statusCode,
    this.statusLabel,
    this.refundStatus,
    this.refundRemark,
    required this.grandTotal,
    this.subtotalAmount,
    this.discountAmount,
    this.couponDiscountAmount,
    this.couponCode,
    this.shippingFee,
    required this.shippingName,
    required this.shippingAddress,
    this.shippingPhone,
    this.shippingZipCode,
    this.shippingProvinceName,
    this.shippingDistrictName,
    this.shippingSubdistrictName,
    this.shippingCarrierName,
    this.carrierName,
    this.trackingNo,
    this.trackingUrl,
    this.shipmentEvents,
    this.paymentExpiresAt,
    required this.createdAt,
    required this.itemCount,
    this.items,
  });

  final int orId;
  final String? orderNo;
  // Legacy status field ('pending', 'paid', 'packing', etc.)
  final String status;
  // Normalized status code ('PENDING', 'CONFIRMED', 'PROCESSING', etc.)
  final String? statusCode;
  final String? statusLabel;
  final String? refundStatus; // 'pending' | 'succeeded' | 'failed'
  final String? refundRemark;
  final double grandTotal;
  final double? subtotalAmount;
  final double? discountAmount;
  final double? couponDiscountAmount;
  final String? couponCode;
  final double? shippingFee;
  final String shippingName;
  final String shippingAddress;
  final String? shippingPhone;
  final String? shippingZipCode;
  final String? shippingProvinceName;
  final String? shippingDistrictName;
  final String? shippingSubdistrictName;
  final String? shippingCarrierName;
  final String? carrierName;
  final String? trackingNo;
  final String? trackingUrl;
  final List<ShipmentEvent>? shipmentEvents;
  final String? paymentExpiresAt;
  final String createdAt;
  final int itemCount;
  final List<OrderItem>? items;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orId: _toInt(json['or_id']),
      orderNo: json['order_no'] as String?,
      status: json['status'] as String? ?? '',
      statusCode: json['status_code'] as String?,
      statusLabel: json['status_label'] as String?,
      refundStatus: json['refund_status'] as String?,
      refundRemark: json['refund_remark'] as String?,
      grandTotal: _toDouble(json['grand_total']),
      subtotalAmount: _toDoubleNullable(json['subtotal_amount'] ?? json['subtotal']),
      discountAmount: _toDoubleNullable(json['discount_amount'] ?? json['discount_total']),
      couponDiscountAmount: _toDoubleNullable(json['coupon_discount_amount']),
      couponCode: json['coupon_code'] as String?,
      shippingFee: _toDoubleNullable(json['shipping_fee'] ?? json['shipping_amount']),
      shippingName: json['shipping_name'] as String? ?? '',
      shippingAddress: json['shipping_address'] as String? ?? '',
      shippingPhone: json['shipping_phone'] as String?,
      shippingZipCode: json['shipping_zip_code'] as String?,
      shippingProvinceName: json['shipping_province_name'] as String?,
      shippingDistrictName: json['shipping_district_name'] as String?,
      shippingSubdistrictName: json['shipping_subdistrict_name'] as String?,
      shippingCarrierName: json['shipping_carrier_name'] as String?,
      carrierName: json['carrier_name'] as String?,
      trackingNo: json['tracking_no'] as String?,
      trackingUrl: json['tracking_url'] as String?,
      shipmentEvents: (json['shipment_events'] as List<dynamic>?)
          ?.map((e) => ShipmentEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      paymentExpiresAt: json['payment_expires_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      itemCount: _toInt(json['item_count']),
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Order copyWith({
    String? status,
    String? statusCode,
    String? statusLabel,
    List<OrderItem>? items,
  }) {
    return Order(
      orId: orId,
      orderNo: orderNo,
      status: status ?? this.status,
      statusCode: statusCode ?? this.statusCode,
      statusLabel: statusLabel ?? this.statusLabel,
      refundStatus: refundStatus,
      refundRemark: refundRemark,
      grandTotal: grandTotal,
      subtotalAmount: subtotalAmount,
      discountAmount: discountAmount,
      couponDiscountAmount: couponDiscountAmount,
      couponCode: couponCode,
      shippingFee: shippingFee,
      shippingName: shippingName,
      shippingAddress: shippingAddress,
      shippingPhone: shippingPhone,
      shippingZipCode: shippingZipCode,
      shippingProvinceName: shippingProvinceName,
      shippingDistrictName: shippingDistrictName,
      shippingSubdistrictName: shippingSubdistrictName,
      shippingCarrierName: shippingCarrierName,
      carrierName: carrierName,
      trackingNo: trackingNo,
      trackingUrl: trackingUrl,
      shipmentEvents: shipmentEvents,
      paymentExpiresAt: paymentExpiresAt,
      createdAt: createdAt,
      itemCount: itemCount,
      items: items ?? this.items,
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  return double.tryParse(value.toString()) ?? 0.0;
}

double? _toDoubleNullable(dynamic value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  return int.tryParse(value.toString()) ?? 0;
}
