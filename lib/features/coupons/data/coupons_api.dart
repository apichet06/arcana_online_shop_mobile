import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/coupons/domain/coupon.dart';

class CouponsApi {
  CouponsApi({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  Future<List<Coupon>> fetchAvailableCoupons() async {
    final res = await _api.get('/coupons/available');
    final data = res['data'];
    if (data is! List) return const [];
    final coupons = data
        .whereType<Map<String, dynamic>>()
        .map(Coupon.fromAvailableJson)
        .toList();
    return _uniqueCoupons(coupons);
  }

  Future<List<Coupon>> fetchMyCoupons() async {
    final res = await _api.get('/coupons/me');
    final data = res['data'];
    if (data is! List) return const [];
    final coupons = data
        .whereType<Map<String, dynamic>>()
        .map(Coupon.fromUserJson)
        .toList();
    return _uniqueCoupons(coupons);
  }

  Future<void> claimCoupon(int couponId) async {
    await _api.post('/coupons/$couponId/claim');
  }

  Future<List<CouponProduct>> fetchCouponProducts(int couponId) async {
    final res = await _api.get('/coupons/available/$couponId/products');
    final data = res['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CouponProduct.fromJson)
        .toList();
  }

  List<Coupon> _uniqueCoupons(List<Coupon> coupons) {
    final byId = <int, Coupon>{};
    for (final coupon in coupons) {
      if (coupon.coId <= 0) continue;
      final existing = byId[coupon.coId];
      if (existing == null || _rank(coupon) > _rank(existing)) {
        byId[coupon.coId] = coupon;
      }
    }
    return byId.values.toList();
  }

  int _rank(Coupon coupon) {
    if (coupon.userCouponStatus == 'claimed') return 4;
    if (coupon.isClaimed) return 3;
    if (coupon.userCouponStatus == 'used') return 2;
    if (coupon.userCouponStatus == 'expired') return 1;
    return 0;
  }
}
