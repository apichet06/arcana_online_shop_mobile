import 'dart:async';

import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import 'package:arcana_online_shop_mobile/features/auth/presentation/login_page.dart';
import 'package:arcana_online_shop_mobile/features/coupons/data/coupons_api.dart';
import 'package:arcana_online_shop_mobile/features/coupons/domain/coupon.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/data/product_shop_repository.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product_detail.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/presentation/product_variant_page.dart';
import 'package:arcana_online_shop_mobile/features/storefront/domain/storefront_language.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({
    super.key,
    this.api,
    this.language = StorefrontLanguage.thai,
  });

  final CouponsApi? api;
  final StorefrontLanguage language;

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  late final CouponsApi _api = widget.api ?? CouponsApi();
  List<Coupon> _coupons = const [];
  bool _loading = true;
  String? _error;
  int? _claimingId;

  @override
  void initState() {
    super.initState();
    AuthSession.instance.addListener(_loadCoupons);
    unawaited(_loadCoupons());
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_loadCoupons);
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final coupons = await _api.fetchAvailableCoupons();
      if (!mounted) return;
      setState(() {
        _coupons = coupons;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'โหลดคูปองไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  Future<void> _claim(Coupon coupon) async {
    if (!AuthSession.instance.isLoggedIn) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    setState(() => _claimingId = coupon.coId);
    try {
      await _api.claimCoupon(coupon.coId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เก็บคูปองสำเร็จ')));
      await _loadCoupons();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เก็บคูปองไม่สำเร็จ'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  void _showCouponDetails(Coupon coupon) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CouponDetailSheet(
        coupon: coupon,
        api: _api,
        language: widget.language,
        claiming: _claimingId == coupon.coId,
        onClaim: () => _claim(coupon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คูปองส่วนลด')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCoupons,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.local_offer_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _loadCoupons,
              child: const Text('ลองใหม่'),
            ),
          ),
        ],
      );
    }

    if (_coupons.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.confirmation_number_outlined,
            size: 54,
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          Text(
            'ยังไม่มีคูปองที่รับได้',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _coupons.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final coupon = _coupons[index];
        return CouponCard(
          coupon: coupon,
          claiming: _claimingId == coupon.coId,
          onTap: () => _showCouponDetails(coupon),
          onClaim: () => _claim(coupon),
        );
      },
    );
  }
}

class _CouponDetailSheet extends StatefulWidget {
  const _CouponDetailSheet({
    required this.coupon,
    required this.api,
    required this.language,
    required this.claiming,
    required this.onClaim,
  });

  final Coupon coupon;
  final CouponsApi api;
  final StorefrontLanguage language;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  State<_CouponDetailSheet> createState() => _CouponDetailSheetState();
}

class _CouponDetailSheetState extends State<_CouponDetailSheet> {
  final ProductShopRepository _productRepository = ProductShopRepository();
  List<CouponProduct> _products = const [];
  bool _loadingProducts = false;
  int? _openingProductId;
  String? _productError;

  @override
  void initState() {
    super.initState();
    if (widget.coupon.productIds.isNotEmpty) {
      unawaited(_loadProducts());
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productError = null;
    });
    try {
      final products = await widget.api.fetchCouponProducts(widget.coupon.coId);
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productError = e is ApiException
            ? e.message
            : 'โหลดรายการสินค้าไม่สำเร็จ';
        _loadingProducts = false;
      });
    }
  }

  Future<void> _openProduct(CouponProduct product) async {
    if (_openingProductId != null) return;
    setState(() => _openingProductId = product.productId);

    try {
      final data = await _productRepository.getProductById(
        productId: product.productId,
        languageCode: widget.language.code,
      );
      if (!mounted) return;

      final productSummary = _productFromDetail(data);
      final imageUrl = _productRepository.resolveAssetUrl(
        productSummary.imageUrl,
      );
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProductVariantPage(
            product: productSummary,
            language: widget.language,
            initialImageUrl: imageUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'เปิดสินค้าไม่สำเร็จ'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingProductId = null);
    }
  }

  Product _productFromDetail(ProductDetailData data) {
    final detail = data.product;
    String? primaryImage;
    for (final image in data.images) {
      if (image.isPrimary && image.url.isNotEmpty) {
        primaryImage = image.url;
        break;
      }
    }
    if (primaryImage == null) {
      for (final image in data.images) {
        if (image.url.isNotEmpty) {
          primaryImage = image.url;
          break;
        }
      }
    }

    ProductVariant? defaultVariant;
    for (final variant in data.variants) {
      if (variant.isDefault) {
        defaultVariant = variant;
        break;
      }
    }
    final allOutOfStock =
        data.variants.isNotEmpty &&
        data.variants.every((variant) => variant.isOutOfStock);

    return Product(
      id: detail.id,
      name: detail.name,
      title: detail.title,
      imageUrl: detail.thumbnail ?? primaryImage,
      minPrice: detail.minPrice,
      maxPrice: detail.maxPrice,
      discount: defaultVariant?.discount ?? 0,
      categoryId: detail.categoryId,
      catalogId: detail.catalogId,
      brandName: detail.brandName,
      hasPriceRange: detail.hasPriceRange,
      isOutOfStock: allOutOfStock,
      rating: null,
      reviewCount: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text('รายละเอียดคูปอง', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'ปิด',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.local_offer_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coupon.discountLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              coupon.minOrderLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DetailLine(
                  icon: Icons.confirmation_number_outlined,
                  label: 'สถานะ',
                  value: coupon.stateLabel,
                ),
                _DetailLine(
                  icon: Icons.calendar_today_outlined,
                  label: 'วันหมดอายุ',
                  value: coupon.endDateLabel,
                ),
                _DetailLine(
                  icon: Icons.shopping_bag_outlined,
                  label: 'เงื่อนไขสินค้า',
                  value: coupon.productIds.isEmpty
                      ? 'ใช้ได้กับสินค้าทุกชิ้นในตะกร้าที่เข้าเงื่อนไข'
                      : 'ใช้ได้กับสินค้าเฉพาะ ${coupon.productIds.length} รายการ',
                ),
                const SizedBox(height: 16),
                Text('สินค้าที่ใช้ได้', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                _buildProducts(context),
                const SizedBox(height: 18),
                if (!coupon.isClaimed)
                  FilledButton.icon(
                    onPressed: widget.claiming ? null : widget.onClaim,
                    icon: widget.claiming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(widget.claiming ? 'กำลังเก็บ...' : 'เก็บคูปอง'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(coupon.stateLabel),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProducts(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.coupon.productIds.isEmpty) {
      return Text(
        'ไม่จำกัดสินค้าเฉพาะ ระบบจะตรวจสอบยอดขั้นต่ำและสินค้าในตะกร้าให้อัตโนมัติเมื่อเลือกใช้คูปอง',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (_loadingProducts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_productError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _productError!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
          TextButton(onPressed: _loadProducts, child: const Text('ลองใหม่')),
        ],
      );
    }

    if (_products.isEmpty) {
      return Text(
        'ไม่พบรายการสินค้า',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        for (final product in _products)
          ListTile(
            onTap: () => _openProduct(product),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined, size: 20),
            title: Text(product.productName ?? 'สินค้าไม่มีชื่อ'),
            subtitle: product.productCode != null
                ? Text(product.productCode!)
                : null,
            trailing: _openingProductId == product.productId
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
          ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CouponCard extends StatelessWidget {
  const CouponCard({
    super.key,
    required this.coupon,
    this.claiming = false,
    this.compact = false,
    this.selected = false,
    this.onClaim,
    this.onTap,
    this.trailing,
  });

  final Coupon coupon;
  final bool claiming;
  final bool compact;
  final bool selected;
  final VoidCallback? onClaim;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateColor = _stateColor(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 42 : 48,
                height: compact ? 42 : 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_offer_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            coupon.discountLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coupon.minOrderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'หมดอายุ ${coupon.endDateShortLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _CouponChip(
                            label: coupon.stateLabel,
                            color: stateColor,
                          ),
                          _CouponChip(
                            label: coupon.productIds.isEmpty
                                ? 'ใช้ได้กับสินค้าที่เข้าเงื่อนไข'
                                : 'สินค้าเฉพาะ ${coupon.productIds.length} รายการ',
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? _buildAction(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (coupon.isClaimed) {
      return Text(
        coupon.stateLabel,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      );
    }

    return FilledButton(
      onPressed: claiming || onClaim == null ? null : onClaim,
      style: FilledButton.styleFrom(
        minimumSize: const Size(72, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: claiming
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('เก็บ'),
    );
  }

  Color _stateColor(BuildContext context) {
    if (coupon.userCouponStatus == 'used' || coupon.isExpired) {
      return Colors.grey;
    }
    if (coupon.isClaimed) return Theme.of(context).colorScheme.primary;
    return Colors.green.shade700;
  }
}

class _CouponChip extends StatelessWidget {
  const _CouponChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
