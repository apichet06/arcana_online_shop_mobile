import 'dart:async';

import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/features/checkout/presentation/prompt_pay_dialog.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/address/data/address_api.dart';
import 'package:arcana_online_shop_mobile/features/address/domain/address.dart';
import 'package:arcana_online_shop_mobile/features/address/presentation/address_form_page.dart';
import 'package:arcana_online_shop_mobile/features/cart/application/cart_controller.dart';
import 'package:arcana_online_shop_mobile/features/cart/domain/cart_item.dart';
import 'package:arcana_online_shop_mobile/features/checkout/data/checkout_api.dart';
import 'package:arcana_online_shop_mobile/features/checkout/domain/coupon_validation.dart';
import 'package:arcana_online_shop_mobile/features/checkout/domain/shipping_option.dart';
import 'package:arcana_online_shop_mobile/features/coupons/data/coupons_api.dart';
import 'package:arcana_online_shop_mobile/features/coupons/domain/coupon.dart';
import 'package:arcana_online_shop_mobile/features/coupons/presentation/coupons_page.dart'
    show CouponCard;
import 'package:arcana_online_shop_mobile/features/orders/domain/order.dart';
import 'package:arcana_online_shop_mobile/features/orders/domain/order_status.dart';
import 'package:arcana_online_shop_mobile/features/orders/presentation/order_detail_page.dart';
import 'package:arcana_online_shop_mobile/features/orders/presentation/order_list_page.dart';
import 'package:arcana_online_shop_mobile/features/orders/data/orders_api.dart';
import 'package:arcana_online_shop_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:arcana_online_shop_mobile/features/payment_methods/domain/saved_payment_method.dart';
import 'package:arcana_online_shop_mobile/features/payment_methods/presentation/add_card_page.dart';

final _baht = NumberFormat('#,##0.00', 'th');
String _fmt(double v) => '฿${_baht.format(v)}';

enum _PayMode { promptPay, savedCard }

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.selectedCiIds,
    required this.selectedTotal,
  });

  // ci_id ของ cart items ที่เลือกไว้
  final List<int> selectedCiIds;
  // ราคารวมก่อนส่วนลดและค่าจัดส่ง (คำนวณจาก cart)
  final double selectedTotal;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  // ─── Address ────────────────────────────────────────────────────────────────
  List<Address> _addresses = [];
  bool _addrLoading = true;
  Address? _selectedAddress;

  // ─── Shipping ────────────────────────────────────────────────────────────────
  List<ShippingOption> _shippingOptions = [];
  bool _shippingLoading = false;
  String? _shippingError;
  ShippingOption? _selectedShipping;

  // ─── Coupon ──────────────────────────────────────────────────────────────────
  CouponValidation? _coupon;
  bool _couponValidating = false;
  String? _couponError;
  List<Coupon> _myCoupons = const [];
  bool _myCouponsLoading = false;

  // ─── Payment ─────────────────────────────────────────────────────────────────
  List<SavedPaymentMethod> _savedCards = [];
  _PayMode _payMode = _PayMode.promptPay;
  int? _selectedCardId;

  // ─── Order placement ─────────────────────────────────────────────────────────
  bool _placing = false;

  // ─── APIs ────────────────────────────────────────────────────────────────────
  late final AddressApi _addressApi;
  final CheckoutApi _checkoutApi = CheckoutApi();
  final CouponsApi _couponsApi = CouponsApi();
  final PaymentMethodsApi _pmApi = PaymentMethodsApi();
  final OrdersApi _ordersApi = OrdersApi(client: ApiClient());
  final ApiClient _assetClient = ApiClient();

  // ─── Computed totals ─────────────────────────────────────────────────────────
  double get _discount => _coupon?.discountAmount ?? 0;
  double get _shippingFee => _selectedShipping?.price ?? 0;
  double get _grandTotal => widget.selectedTotal - _discount + _shippingFee;
  List<CartItem> get _selectedCartItems {
    final selectedIds = widget.selectedCiIds.toSet();
    return CartController.instance.items
        .where((item) => selectedIds.contains(item.ciId))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _addressApi = AddressApi(client: ApiClient());
    unawaited(_loadInitial());
    unawaited(_refreshCartSnapshot());
  }

  Future<void> _refreshCartSnapshot() async {
    await CartController.instance.refresh();
    if (mounted) setState(() {});
  }

  Future<void> _loadInitial() async {
    await Future.wait([_loadAddresses(), _loadCards(), _loadMyCoupons()]);
  }

  Future<void> _loadAddresses() async {
    setState(() => _addrLoading = true);
    try {
      final list = await _addressApi.fetchAddresses();
      if (!mounted) return;
      Address? defaultAddr;
      if (list.isNotEmpty) {
        defaultAddr = list.firstWhere(
          (a) => a.isDefault,
          orElse: () => list.first,
        );
      }
      setState(() {
        _addresses = list;
        _addrLoading = false;
        if (defaultAddr != null) {
          _selectedAddress = defaultAddr;
          unawaited(_loadShipping(defaultAddr));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _addrLoading = false);
    }
  }

  Future<void> _loadCards() async {
    try {
      final cards = await _pmApi.listMethods();
      if (!mounted) return;
      setState(() {
        _savedCards = cards;
        if (cards.isNotEmpty) {
          final defaultCard = cards.firstWhere(
            (c) => c.isDefault,
            orElse: () => cards.first,
          );
          _payMode = _PayMode.savedCard;
          _selectedCardId = defaultCard.upmId;
        }
      });
    } catch (_) {
      // ถ้าดึงบัตรไม่ได้ ยังใช้ PromptPay ได้
    }
  }

  Future<void> _loadShipping(Address addr) async {
    setState(() {
      _shippingLoading = true;
      _shippingError = null;
      _shippingOptions = [];
      _selectedShipping = null;
    });
    try {
      final options = await _checkoutApi.fetchShippingOptions(
        locbId: addr.id,
        selectedCiIds: widget.selectedCiIds,
      );
      if (!mounted) return;
      final available = options.where((o) => o.price != null).toList();
      setState(() {
        _shippingOptions = available;
        _shippingLoading = false;
        if (available.isNotEmpty) {
          _selectedShipping = available.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shippingLoading = false;
        _shippingError = 'โหลดวิธีจัดส่งไม่สำเร็จ';
      });
    }
  }

  Future<void> _loadMyCoupons() async {
    setState(() => _myCouponsLoading = true);
    try {
      final coupons = await _couponsApi.fetchMyCoupons();
      if (!mounted) return;
      setState(() {
        _myCoupons = coupons;
        _myCouponsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _myCouponsLoading = false);
    }
  }

  Future<void> _applyCouponCode(String coCode) async {
    final code = coCode.trim();
    if (code.isEmpty) return;

    setState(() {
      _couponValidating = true;
      _couponError = null;
      _coupon = null;
    });
    try {
      final result = await _checkoutApi.validateCoupon(code);
      if (!mounted) return;
      setState(() {
        _coupon = result;
        _couponValidating = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _couponError = e.message;
        _couponValidating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _couponError = 'ตรวจสอบคูปองไม่สำเร็จ';
        _couponValidating = false;
      });
    }
  }

  void _clearCoupon() {
    setState(() {
      _coupon = null;
      _couponError = null;
    });
  }

  Future<void> _pickCoupon() async {
    if (_myCoupons.isEmpty && !_myCouponsLoading) {
      await _loadMyCoupons();
    }
    if (!mounted) return;

    final picked = await showModalBottomSheet<Coupon>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CouponPickerSheet(
        coupons: _myCoupons.where((coupon) => coupon.isUsable).toList(),
        selectedCode: _coupon?.coCode,
        loading: _myCouponsLoading,
        onRefresh: _loadMyCoupons,
      ),
    );

    if (picked != null) {
      await _applyCouponCode(picked.coCode);
    }
  }

  Future<void> _pickAddress() async {
    if (_addresses.isEmpty) return;

    final picked = await showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddressPickerSheet(
        addresses: _addresses,
        selected: _selectedAddress,
        onAddNew: () async {
          Navigator.of(context).pop();
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddressFormPage(api: _addressApi, existing: null),
            ),
          );
          if (added == true) unawaited(_loadAddresses());
        },
      ),
    );

    if (picked != null && picked.id != _selectedAddress?.id) {
      setState(() {
        _selectedAddress = picked;
        _coupon = null;
      });
      unawaited(_loadShipping(picked));
    }
  }

  Future<void> _pickShipping() async {
    if (_shippingOptions.isEmpty) return;

    final picked = await showModalBottomSheet<ShippingOption>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ShippingPickerSheet(
        options: _shippingOptions,
        selected: _selectedShipping,
      ),
    );

    if (picked != null && picked.scId != _selectedShipping?.scId) {
      setState(() => _selectedShipping = picked);
    }
  }

  Future<void> _addCard() async {
    final added = await Navigator.push<SavedPaymentMethod>(
      context,
      MaterialPageRoute(builder: (_) => const AddCardPage()),
    );
    if (added != null && mounted) {
      setState(() {
        _savedCards = [..._savedCards, added];
        _payMode = _PayMode.savedCard;
        _selectedCardId = added.upmId;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_placing) return;

    if (_selectedAddress == null) {
      _showSnack('กรุณาเลือกที่อยู่จัดส่ง', isError: true);
      return;
    }
    if (_selectedShipping == null && _shippingOptions.isNotEmpty) {
      _showSnack('กรุณาเลือกวิธีจัดส่ง', isError: true);
      return;
    }
    if (_payMode == _PayMode.savedCard && _selectedCardId == null) {
      _showSnack('กรุณาเลือกบัตรชำระเงิน', isError: true);
      return;
    }

    setState(() => _placing = true);
    try {
      CheckoutResult result;

      if (_payMode == _PayMode.promptPay) {
        result = await _checkoutApi.checkout(
          locbId: _selectedAddress!.id,
          coCode: _coupon?.coCode,
          shippingScId: _selectedShipping?.scId,
          paymentMethod: 'promptpay',
          selectedCiIds: widget.selectedCiIds,
        );
      } else {
        result = await _checkoutApi.checkout(
          locbId: _selectedAddress!.id,
          coCode: _coupon?.coCode,
          shippingScId: _selectedShipping?.scId,
          paymentMethod: 'card',
          savedPaymentMethodId: _selectedCardId,
          selectedCiIds: widget.selectedCiIds,
        );
      }

      if (!mounted) return;
      await CartController.instance.refresh();
      if (!mounted) return;

      _handleCheckoutResult(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('เกิดข้อผิดพลาด กรุณาลองใหม่', isError: true);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _handleCheckoutResult(CheckoutResult result) {
    final payment = result.payment;

    if (payment.qrCodeUri != null && payment.qrCodeUri!.isNotEmpty) {
      _showPromptPayDialog(payment.qrCodeUri!, result.orders);
      return;
    }

    if (payment.authorizeUri != null && payment.authorizeUri!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AuthorizeWebView(
            url: payment.authorizeUri!,
            orders: result.orders,
            ordersApi: _ordersApi,
          ),
        ),
      );
      return;
    }

    // ชำระเงินสำเร็จทันที (saved card ที่ไม่ต้อง 3DS)
    _navigateToOrder(result.orders);
  }

  Future<List<Order>> _fetchLatestOrders(List<Order> orders) async {
    final orderIds = orders.map((order) => order.orId).toSet();
    if (orderIds.isEmpty) return orders;

    try {
      final latestOrders = await _ordersApi.fetchOrders('th');
      final latestById = {
        for (final order in latestOrders)
          if (orderIds.contains(order.orId)) order.orId: order,
      };
      return [for (final order in orders) latestById[order.orId] ?? order];
    } catch (_) {
      return orders;
    }
  }

  List<Order> _markOrdersPaymentExpired(List<Order> orders) {
    return [
      for (final order in orders)
        order.copyWith(
          status: 'cancelled',
          statusCode: OrderStatusCode.cancelled,
          statusLabel: 'ยกเลิกแล้ว',
        ),
    ];
  }

  bool _isOrderPaymentConfirmed(Order order) {
    return {
      OrderStatusCode.confirmed,
      OrderStatusCode.processing,
      OrderStatusCode.packed,
      OrderStatusCode.readyToShip,
      OrderStatusCode.delivered,
      OrderStatusCode.received,
      OrderStatusCode.autoReceived,
      OrderStatusCode.reviewed,
    }.contains(getOrderStatusCode(order));
  }

  Future<bool> _hasAnyOrderPaymentConfirmed(List<Order> orders) async {
    for (final order in orders) {
      try {
        await _checkoutApi.syncPromptPayCharge(order.orId);
      } catch (_) {
        // Webhook may already have handled it, or the order may no longer have
        // a pending PromptPay payment. Fetching latest orders below is still the
        // source of truth for the UI.
      }
    }

    final latestOrders = await _fetchLatestOrders(orders);
    return latestOrders.any(_isOrderPaymentConfirmed);
  }

  void _showPromptPayDialog(String qrUri, List<Order> orders) {
    final expiresAt = orders.isNotEmpty ? orders.first.paymentExpiresAt : null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PromptPayDialog(
        qrCodeUri: qrUri,
        grandTotal: _grandTotal,
        expiresAt: expiresAt,
        doneLabel: 'ไปการซื้อของฉัน',
        onDone: () {
          Navigator.of(context).pop();
          _navigateToOrderList();
        },
        isPaymentConfirmed: () => _hasAnyOrderPaymentConfirmed(orders),
        onPaymentConfirmed: () {
          if (!mounted) return;
          _showSnack('ชำระเงินสำเร็จ');
          _navigateToOrderList();
        },
        onExpired: () async {
          final latestOrders = await _fetchLatestOrders(orders);
          if (!mounted) return;
          _showSnack('QR หมดอายุ คำสั่งซื้อถูกยกเลิกแล้ว', isError: true);
          _navigateToOrder(_markOrdersPaymentExpired(latestOrders));
        },
      ),
    );
  }

  void _navigateToOrderList() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderListPage()),
    );
  }

  void _navigateToOrder(List<Order> orders) {
    if (orders.isEmpty) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(order: orders.first, api: _ordersApi),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สั่งซื้อสินค้า')),
      body: SafeArea(
        child: _addrLoading
            ? const Center(child: CircularProgressIndicator())
            : _addresses.isEmpty
            ? _NoAddressPlaceholder(
                onAdd: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddressFormPage(api: _addressApi, existing: null),
                    ),
                  );
                  if (added == true) unawaited(_loadAddresses());
                },
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _AddressSection(
                    address: _selectedAddress,
                    onTap: _pickAddress,
                  ),
                  const SizedBox(height: 12),
                  _CheckoutItemsSection(
                    items: _selectedCartItems,
                    resolveImageUrl: _assetClient.resolveAssetUrl,
                  ),
                  const SizedBox(height: 12),
                  _ShippingSection(
                    options: _shippingOptions,
                    loading: _shippingLoading,
                    error: _shippingError,
                    selected: _selectedShipping,
                    onChange: _pickShipping,
                    onRetry: _selectedAddress != null
                        ? () => _loadShipping(_selectedAddress!)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _CouponSection(
                    coupon: _coupon,
                    validating: _couponValidating,
                    error: _couponError,
                    onClear: _clearCoupon,
                    onPickCoupon: _pickCoupon,
                  ),
                  const SizedBox(height: 12),
                  _PaymentSection(
                    savedCards: _savedCards,
                    payMode: _payMode,
                    selectedCardId: _selectedCardId,
                    onSelectPromptPay: () =>
                        setState(() => _payMode = _PayMode.promptPay),
                    onSelectCard: (id) => setState(() {
                      _payMode = _PayMode.savedCard;
                      _selectedCardId = id;
                    }),
                    onAddCard: _addCard,
                  ),
                  const SizedBox(height: 12),
                  _SummarySection(
                    subtotal: widget.selectedTotal,
                    discount: _discount,
                    shippingFee: _shippingFee,
                    grandTotal: _grandTotal,
                    couponCode: _coupon?.coCode,
                    shippingName: _selectedShipping?.scName,
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _ConfirmBar(
        grandTotal: _grandTotal,
        placing: _placing,
        enabled: _selectedAddress != null && !_placing,
        onConfirm: _placeOrder,
      ),
    );
  }
}

// ─── Section: Address ──────────────────────────────────────────────────────────

class _AddressSection extends StatelessWidget {
  const _AddressSection({required this.address, required this.onTap});

  final Address? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.location_on_outlined,
            label: 'ที่อยู่จัดส่ง',
            action: TextButton(onPressed: onTap, child: const Text('เปลี่ยน')),
          ),
          const SizedBox(height: 8),
          if (address == null)
            const Text('ยังไม่ได้เลือกที่อยู่')
          else ...[
            Text(
              address!.recipientName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(address!.phone, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '${address!.addressLine} ${address!.subdistrictName} ${address!.districtName} ${address!.provinceName} ${address!.zipCode}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Section: Checkout items ──────────────────────────────────────────────────

class _CheckoutItemsSection extends StatelessWidget {
  const _CheckoutItemsSection({
    required this.items,
    required this.resolveImageUrl,
  });

  final List<CartItem> items;
  final String Function(String? url) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.shopping_bag_outlined,
            label: 'รายการสินค้า (${items.length})',
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'ไม่พบรายการสินค้าที่เลือก',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            ...List.generate(items.length, (index) {
              final item = items[index];
              return Column(
                children: [
                  _CheckoutItemRow(
                    item: item,
                    imageUrl: resolveImageUrl(item.imageUrl),
                  ),
                  if (index < items.length - 1) const Divider(height: 18),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({required this.item, required this.imageUrl});

  final CartItem item;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: const Color(0xFFF0EEE8),
            child: SizedBox(
              width: 58,
              height: 58,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _ItemImageFallback(),
                    )
                  : const _ItemImageFallback(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.displayVariant.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.displayVariant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '${_fmt(item.effectiveUnitPrice)} x ${item.qty}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _fmt(item.lineTotal),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ItemImageFallback extends StatelessWidget {
  const _ItemImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 24,
        color: Color(0xFFBBB5A8),
      ),
    );
  }
}

// ─── Section: Shipping ────────────────────────────────────────────────────────

class _ShippingSection extends StatelessWidget {
  const _ShippingSection({
    required this.options,
    required this.loading,
    required this.error,
    required this.selected,
    required this.onChange,
    required this.onRetry,
  });

  final List<ShippingOption> options;
  final bool loading;
  final String? error;
  final ShippingOption? selected;
  final VoidCallback onChange;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.local_shipping_outlined,
            label: 'วิธีจัดส่ง',
            action: !loading && error == null && options.isNotEmpty
                ? TextButton(onPressed: onChange, child: const Text('เปลี่ยน'))
                : null,
          ),
          const SizedBox(height: 8),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Column(
              children: [
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('ลองใหม่')),
              ],
            )
          else if (options.isEmpty)
            const Text('ไม่มีบริการจัดส่งสำหรับที่อยู่นี้')
          else if (selected == null)
            TextButton.icon(
              onPressed: onChange,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('เลือกวิธีจัดส่ง'),
            )
          else
            InkWell(
              onTap: onChange,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected!.scName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'ระบบเลือกให้ สามารถเปลี่ยนได้',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      selected!.price != null
                          ? _fmt(selected!.price!)
                          : 'ไม่มีอัตราค่าส่ง',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Section: Coupon ──────────────────────────────────────────────────────────

class _CouponSection extends StatelessWidget {
  const _CouponSection({
    required this.coupon,
    required this.validating,
    required this.error,
    required this.onClear,
    required this.onPickCoupon,
  });

  final CouponValidation? coupon;
  final bool validating;
  final String? error;
  final VoidCallback onClear;
  final VoidCallback onPickCoupon;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.local_offer_outlined,
            label: 'คูปองส่วนลด',
            action: coupon != null && !validating
                ? TextButton(
                    onPressed: onPickCoupon,
                    child: const Text('เปลี่ยน'),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          if (validating)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (coupon != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คูปอง ${coupon!.coCode}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'ลด ${_fmt(coupon!.discountAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.green.shade700,
                    onPressed: onClear,
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: onPickCoupon,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.confirmation_number_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'เลือกคูปองส่วนลด',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Section: Payment method ──────────────────────────────────────────────────

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.savedCards,
    required this.payMode,
    required this.selectedCardId,
    required this.onSelectPromptPay,
    required this.onSelectCard,
    required this.onAddCard,
  });

  final List<SavedPaymentMethod> savedCards;
  final _PayMode payMode;
  final int? selectedCardId;
  final VoidCallback onSelectPromptPay;
  final ValueChanged<int> onSelectCard;
  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    final selectedPaymentValue = switch (payMode) {
      _PayMode.promptPay => 'promptPay',
      _PayMode.savedCard =>
        selectedCardId != null ? 'card:$selectedCardId' : null,
    };

    return _SectionCard(
      child: RadioGroup<String>(
        groupValue: selectedPaymentValue,
        onChanged: (value) {
          if (value == null) return;
          if (value == 'promptPay') {
            onSelectPromptPay();
            return;
          }

          final cardId = int.tryParse(value.replaceFirst('card:', ''));
          if (cardId != null) onSelectCard(cardId);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(icon: Icons.payment_outlined, label: 'วิธีชำระเงิน'),
            const SizedBox(height: 4),
            // PromptPay
            RadioListTile<String>(
              value: 'promptPay',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Icon(
                    Icons.qr_code_2_outlined,
                    size: 20,
                    color: const Color.fromARGB(255, 3, 16, 128),
                  ),
                  const SizedBox(width: 6),
                  const Text('PromptPay (QR Code)'),
                ],
              ),
            ),
            // Saved cards
            ...savedCards.map(
              (card) => RadioListTile<String>(
                value: 'card:${card.upmId}',
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(
                      Icons.credit_card_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.displayLabel),
                          if (card.expiryLabel.isNotEmpty)
                            Text(
                              'หมดอายุ ${card.expiryLabel}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Add card button
            TextButton.icon(
              onPressed: onAddCard,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('เพิ่มบัตรใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section: Summary ─────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.grandTotal,
    this.couponCode,
    this.shippingName,
  });

  final double subtotal;
  final double discount;
  final double shippingFee;
  final double grandTotal;
  final String? couponCode;
  final String? shippingName;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: Icons.receipt_outlined, label: 'สรุปยอดชำระ'),
          const SizedBox(height: 10),
          _PriceLine(label: 'ราคาสินค้า', value: _fmt(subtotal)),
          if (discount > 0)
            _PriceLine(
              label: 'ส่วนลดคูปอง${couponCode != null ? ' ($couponCode)' : ''}',
              value: '-${_fmt(discount)}',
              valueColor: Colors.green.shade700,
            ),
          _PriceLine(
            label: shippingName != null
                ? 'ค่าจัดส่ง ($shippingName)'
                : 'ค่าจัดส่ง',
            value: _fmt(shippingFee),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Text(
                'ยอดรวมสุทธิ',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                _fmt(grandTotal),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom confirm bar ───────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.grandTotal,
    required this.placing,
    required this.enabled,
    required this.onConfirm,
  });

  final double grandTotal;
  final bool placing;
  final bool enabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ยอดรวม', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  _fmt(grandTotal),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: enabled ? onConfirm : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: placing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'ยืนยันสั่งซื้อ',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Coupon picker sheet ─────────────────────────────────────────────────────

class _CouponPickerSheet extends StatelessWidget {
  const _CouponPickerSheet({
    required this.coupons,
    required this.selectedCode,
    required this.loading,
    required this.onRefresh,
  });

  final List<Coupon> coupons;
  final String? selectedCode;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.4,
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
                Text(
                  'เลือกคูปองของฉัน',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => onRefresh(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'รีเฟรช',
                ),
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
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : coupons.isEmpty
                ? ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 46,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ยังไม่มีคูปองที่พร้อมใช้',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'กดเก็บคูปองจากหน้าแรกก่อน แล้วกลับมาเลือกใช้ที่นี่',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: coupons.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final coupon = coupons[index];
                      return CouponCard(
                        coupon: coupon,
                        selected: coupon.coCode == selectedCode,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(coupon),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Shipping picker sheet ───────────────────────────────────────────────────

class _ShippingPickerSheet extends StatelessWidget {
  const _ShippingPickerSheet({required this.options, required this.selected});

  final List<ShippingOption> options;
  final ShippingOption? selected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      maxChildSize: 0.85,
      minChildSize: 0.35,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'เลือกวิธีจัดส่ง',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
            child: ListView.separated(
              controller: scrollCtrl,
              itemCount: options.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final option = options[i];
                final isSelected = option.scId == selected?.scId;

                return ListTile(
                  onTap: () => Navigator.of(context).pop(option),
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    option.scName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: option.zoneCode.isNotEmpty
                      ? Text('โซน ${option.zoneCode}')
                      : null,
                  trailing: Text(
                    option.price != null
                        ? _fmt(option.price!)
                        : 'ไม่มีอัตราค่าส่ง',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Address picker sheet ─────────────────────────────────────────────────────

class _AddressPickerSheet extends StatelessWidget {
  const _AddressPickerSheet({
    required this.addresses,
    required this.selected,
    required this.onAddNew,
  });

  final List<Address> addresses;
  final Address? selected;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'เลือกที่อยู่จัดส่ง',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAddNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('เพิ่มใหม่'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: addresses.length,
              itemBuilder: (_, i) {
                final addr = addresses[i];
                final isSelected = addr.id == selected?.id;
                return ListTile(
                  onTap: () => Navigator.of(context).pop(addr),
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    '${addr.recipientName}  ${addr.phone}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${addr.addressLine} ${addr.subdistrictName} ${addr.districtName} ${addr.provinceName} ${addr.zipCode}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: addr.isDefault
                      ? Chip(
                          label: const Text('หลัก'),
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          side: BorderSide.none,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3DS WebView page ─────────────────────────────────────────────────────────

class _AuthorizeWebView extends StatefulWidget {
  const _AuthorizeWebView({
    required this.url,
    required this.orders,
    required this.ordersApi,
  });

  final String url;
  final List<Order> orders;
  final OrdersApi ordersApi;

  @override
  State<_AuthorizeWebView> createState() => _AuthorizeWebViewState();
}

class _AuthorizeWebViewState extends State<_AuthorizeWebView> {
  late final WebViewController _wvc;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            // Omise redirect กลับมาที่ arcana-callback หลังยืนยัน 3DS
            final url = change.url ?? '';
            if (!_done && url.contains('arcana') && url.contains('callback')) {
              _done = true;
              _finish();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _finish() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (widget.orders.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(
            order: widget.orders.first,
            api: widget.ordersApi,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ยืนยันการชำระเงิน'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: _wvc),
    );
  }
}

// ─── No address placeholder ───────────────────────────────────────────────────

class _NoAddressPlaceholder extends StatelessWidget {
  const _NoAddressPlaceholder({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีที่อยู่จัดส่ง',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'กรุณาเพิ่มที่อยู่ก่อนสั่งซื้อ',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มที่อยู่'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label, this.action});

  final IconData icon;
  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        if (action != null) ...[const Spacer(), action!],
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
