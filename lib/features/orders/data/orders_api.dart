import 'package:dio/dio.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/core/network/api_paths.dart';
import 'package:arcana_online_shop_mobile/features/orders/domain/order.dart';

class OrdersApi {
  // ignore: prefer_initializing_formals — public named param 'client' maps to private field '_client'
  const OrdersApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<Order>> fetchOrders(String lgCode) async {
    final res = await _client.get(
      ApiPaths.orders,
      queryParameters: {'lg_code': lgCode},
    );
    final data = res['data'];
    if (data is List) {
      return data
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<OrderItem>> fetchOrderItems(int orderId, String lgCode) async {
    final res = await _client.get(
      ApiPaths.orderById(orderId),
      queryParameters: {'lg_code': lgCode},
    );
    final data = res['data'];
    if (data is List) {
      return data
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<Order> fetchOrderDetail(int orderId, String lgCode) async {
    final res = await _client.get(
      ApiPaths.orderById(orderId),
      queryParameters: {'lg_code': lgCode},
    );
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> syncPromptPayCharge(int orderId) async {
    await _client.post('/payments/omise/orders/$orderId/sync');
  }

  Future<Order> cancelOrder(int orderId, String reason) async {
    final res = await _client.patch(
      ApiPaths.cancelOrder(orderId),
      data: {'reason': reason},
      queryParameters: {'lg_code': 'th'},
    );
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> requestRefund(
    int orderId, {
    required String reason,
    String returnTracking = '',
    List<String> imagePaths = const [],
  }) async {
    final formData = FormData.fromMap({
      'reason': reason,
      'return_tracking': returnTracking,
    });
    for (final path in imagePaths) {
      formData.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(path, filename: _fileName(path)),
        ),
      );
    }

    final res = await _client.post(
      ApiPaths.refundRequest(orderId),
      data: formData,
      queryParameters: {'lg_code': 'th'},
    );
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Order> confirmReceived(int orderId) async {
    final res = await _client.patch(
      ApiPaths.confirmOrderReceived(orderId),
      queryParameters: {'lg_code': 'th'},
    );
    return Order.fromJson(res['data'] as Map<String, dynamic>);
  }
}

String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;
