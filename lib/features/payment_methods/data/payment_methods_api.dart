import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:arcana_online_shop_mobile/config/app_config.dart';
import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/core/network/api_paths.dart';
import 'package:arcana_online_shop_mobile/features/payment_methods/domain/saved_payment_method.dart';

class PaymentMethodsApi {
  PaymentMethodsApi() : _api = ApiClient();

  final ApiClient _api;

  Future<List<SavedPaymentMethod>> listMethods() async {
    final res = await _api.get(ApiPaths.paymentMethods);
    final data = res['data'] as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(SavedPaymentMethod.fromJson)
        .toList();
  }

  Future<SavedPaymentMethod> addCard({
    required String omiseToken,
    bool makeDefault = true,
  }) async {
    final res = await _api.post('${ApiPaths.paymentMethods}/omise-card', data: {
      'omise_token': omiseToken,
      'make_default': makeDefault,
    });
    return SavedPaymentMethod.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<SavedPaymentMethod> setDefault(int upmId) async {
    final res = await _api.patch(ApiPaths.paymentMethodSetDefault(upmId));
    return SavedPaymentMethod.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteMethod(int upmId) async {
    await _api.delete(ApiPaths.paymentMethodById(upmId));
  }

  // ส่งข้อมูลบัตรตรงไป Omise vault เพื่อแลก token — Arcana ไม่เห็นเลขบัตรหรือ CVV
  Future<String> createOmiseToken({
    required String cardName,
    required String cardNumber,
    required int expirationMonth,
    required int expirationYear,
    required String securityCode,
  }) async {
    final publicKey = AppConfig.omisePublicKey;
    if (publicKey == null || publicKey.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        message: 'ยังไม่ได้ตั้งค่า Omise public key',
      );
    }

    final credentials = base64Encode(utf8.encode('$publicKey:'));
    final dio = Dio();

    try {
      final response = await dio.post<Map<String, dynamic>>(
        'https://vault.omise.co/tokens',
        data: {
          'card[name]': cardName,
          'card[number]': cardNumber.replaceAll(' ', ''),
          'card[expiration_month]': expirationMonth,
          'card[expiration_year]': expirationYear,
          'card[security_code]': securityCode,
        },
        options: Options(
          headers: {'Authorization': 'Basic $credentials'},
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      final token = (response.data?['id'] as String?)?.trim();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 0,
          message: 'Omise ไม่ส่ง token กลับมา กรุณาลองใหม่',
        );
      }
      return token;
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = 'สร้าง token ไม่สำเร็จ กรุณาตรวจสอบข้อมูลบัตร';
      if (data is Map && data['message'] != null) {
        msg = data['message'].toString();
      }
      throw ApiException(statusCode: e.response?.statusCode ?? 0, message: msg);
    }
  }
}
