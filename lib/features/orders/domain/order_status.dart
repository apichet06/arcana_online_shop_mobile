import 'package:flutter/material.dart';

import 'order.dart';

class OrderStatusCode {
  const OrderStatusCode._();

  static const String pending = 'PENDING';
  static const String confirmed = 'CONFIRMED';
  static const String processing = 'PROCESSING';
  static const String packed = 'PACKED';
  static const String readyToShip = 'READY_TO_SHIP';
  static const String delivered = 'DELIVERED';
  static const String received = 'RECEIVED';
  static const String autoReceived = 'AUTO_RECEIVED';
  static const String reviewed = 'REVIEWED';
  static const String cancelled = 'CANCELLED';
  static const String refunded = 'REFUNDED';
  static const String returnRequested = 'RETURN_REQUESTED';
  static const String returnRequestedCompleted = 'RETURN_REQUESTED_COMPLETED';
}

String getOrderStatusCode(Order order) {
  final code = order.statusCode;
  if (code != null && code.isNotEmpty) return code;

  // Fallback for older API responses without status_code
  switch (order.status) {
    case 'pending': return OrderStatusCode.pending;
    case 'paid': return OrderStatusCode.confirmed;
    case 'packing': return OrderStatusCode.processing;
    case 'shipped': return OrderStatusCode.readyToShip;
    case 'delivered':
    case 'completed': return OrderStatusCode.delivered;
    case 'cancelled': return OrderStatusCode.cancelled;
    case 'refunded': return OrderStatusCode.refunded;
    default: return OrderStatusCode.confirmed;
  }
}

String getOrderStatusLabel(Order order) {
  final label = order.statusLabel;
  if (label != null && label.isNotEmpty) return label;

  final code = getOrderStatusCode(order);
  switch (code) {
    case OrderStatusCode.pending: return 'รอชำระเงิน';
    case OrderStatusCode.confirmed: return 'ชำระเงินแล้ว';
    case OrderStatusCode.processing: return 'กำลังเตรียมสินค้า';
    case OrderStatusCode.packed: return 'แพ็คสินค้าแล้ว';
    case OrderStatusCode.readyToShip: return 'พร้อมส่ง';
    case OrderStatusCode.delivered: return 'จัดส่งแล้ว';
    case OrderStatusCode.received:
    case OrderStatusCode.autoReceived: return 'รับสินค้าแล้ว';
    case OrderStatusCode.reviewed: return 'รีวิวแล้ว';
    case OrderStatusCode.cancelled: return 'ยกเลิกแล้ว';
    case OrderStatusCode.refunded: return 'คืนเงินแล้ว';
    case OrderStatusCode.returnRequested: return 'ขอคืนสินค้า';
    case OrderStatusCode.returnRequestedCompleted: return 'คืนสินค้าเสร็จสิ้น';
    default: return order.status;
  }
}

Color getOrderStatusColor(Order order) {
  final code = getOrderStatusCode(order);
  switch (code) {
    case OrderStatusCode.pending: return Colors.amber.shade700;
    case OrderStatusCode.confirmed: return Colors.blue.shade700;
    case OrderStatusCode.processing:
    case OrderStatusCode.packed: return Colors.purple.shade700;
    case OrderStatusCode.readyToShip: return Colors.indigo.shade700;
    case OrderStatusCode.delivered:
    case OrderStatusCode.received:
    case OrderStatusCode.autoReceived:
    case OrderStatusCode.reviewed: return Colors.green.shade700;
    case OrderStatusCode.cancelled: return Colors.red.shade700;
    case OrderStatusCode.refunded:
    case OrderStatusCode.returnRequested:
    case OrderStatusCode.returnRequestedCompleted: return Colors.grey.shade700;
    default: return Colors.grey.shade700;
  }
}

Color getOrderStatusBgColor(Order order) {
  final code = getOrderStatusCode(order);
  switch (code) {
    case OrderStatusCode.pending: return Colors.amber.shade50;
    case OrderStatusCode.confirmed: return Colors.blue.shade50;
    case OrderStatusCode.processing:
    case OrderStatusCode.packed: return Colors.purple.shade50;
    case OrderStatusCode.readyToShip: return Colors.indigo.shade50;
    case OrderStatusCode.delivered:
    case OrderStatusCode.received:
    case OrderStatusCode.autoReceived:
    case OrderStatusCode.reviewed: return Colors.green.shade50;
    case OrderStatusCode.cancelled: return Colors.red.shade50;
    case OrderStatusCode.refunded:
    case OrderStatusCode.returnRequested:
    case OrderStatusCode.returnRequestedCompleted: return Colors.grey.shade100;
    default: return Colors.grey.shade100;
  }
}
