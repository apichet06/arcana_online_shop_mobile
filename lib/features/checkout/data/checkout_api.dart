import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/checkout/domain/coupon_validation.dart';
import 'package:arcana_online_shop_mobile/features/checkout/domain/shipping_option.dart';
import 'package:arcana_online_shop_mobile/features/orders/domain/order.dart';

class CheckoutApi {
  CheckoutApi() : _api = ApiClient();

  final ApiClient _api;

  Future<List<ShippingOption>> fetchShippingOptions({
    required int locbId,
    required List<int> selectedCiIds,
  }) async {
    final res = await _api.get(
      '/orders/shipping-options',
      queryParameters: {
        'locb_id': locbId.toString(),
        'selected_ci_ids': selectedCiIds.join(','),
      },
    );
    final data = res['data'];
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(ShippingOption.fromJson).toList();
  }

  Future<CouponValidation> validateCoupon(String coCode) async {
    final res = await _api.post('/coupons/validate', data: {'co_code': coCode});
    return CouponValidation.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<CheckoutPayment> payExistingOrderPromptPay({
    required int orderId,
  }) async {
    final res = await _api.post('/payments/omise/charge', data: {
      'order_ids': [orderId],
      'payment_method': 'promptpay',
    });
    return CheckoutPayment.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<CheckoutPayment> syncPromptPayCharge(int orderId) async {
    final res = await _api.post('/payments/omise/orders/$orderId/sync');
    return CheckoutPayment.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<CheckoutResult> checkout({
    required int locbId,
    String? coCode,
    int? shippingScId,
    required String paymentMethod,
    String? omiseToken,
    String? omiseSource,
    int? savedPaymentMethodId,
    bool saveCard = false,
    required List<int> selectedCiIds,
  }) async {
    final body = <String, dynamic>{
      'locb_id': locbId,
      'payment_method': paymentMethod,
      'selected_ci_ids': selectedCiIds,
    };
    if (coCode != null && coCode.isNotEmpty) body['co_code'] = coCode;
    if (shippingScId != null) body['shipping_sc_id'] = shippingScId;
    if (omiseToken != null) body['omise_token'] = omiseToken;
    if (omiseSource != null) body['omise_source'] = omiseSource;
    if (savedPaymentMethodId != null) body['saved_payment_method_id'] = savedPaymentMethodId;
    if (saveCard) body['save_card'] = true;
    final res = await _api.post('/orders/checkout', data: body);
    return CheckoutResult.fromJson(res['data'] as Map<String, dynamic>);
  }
}

class CheckoutResult {
  const CheckoutResult({required this.orders, required this.payment});

  final List<Order> orders;
  final CheckoutPayment payment;

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    final rawOrders = json['orders'] as List?;
    return CheckoutResult(
      orders: rawOrders
              ?.whereType<Map<String, dynamic>>()
              .map(Order.fromJson)
              .toList() ??
          [],
      payment: CheckoutPayment.fromJson(
          json['payment'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class CheckoutPayment {
  const CheckoutPayment({
    required this.paymentStatus,
    this.authorizeUri,
    this.qrCodeUri,
    required this.amountTotal,
  });

  final String paymentStatus;
  final String? authorizeUri;
  final String? qrCodeUri;
  final double amountTotal;

  factory CheckoutPayment.fromJson(Map<String, dynamic> json) {
    return CheckoutPayment(
      paymentStatus: json['payment_status']?.toString() ?? '',
      authorizeUri: json['authorize_uri'] as String?,
      qrCodeUri: json['qr_code_uri'] as String?,
      amountTotal: _asDouble(json['amount_total']),
    );
  }

  static double _asDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}
