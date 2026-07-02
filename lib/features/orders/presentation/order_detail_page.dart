import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/cart/application/cart_controller.dart';
import 'package:arcana_online_shop_mobile/features/checkout/presentation/checkout_page.dart';
import 'package:arcana_online_shop_mobile/features/checkout/data/checkout_api.dart';
import 'package:arcana_online_shop_mobile/features/checkout/presentation/prompt_pay_dialog.dart';
import 'package:arcana_online_shop_mobile/features/orders/data/orders_api.dart';
import 'package:arcana_online_shop_mobile/features/orders/domain/order.dart';
import 'package:arcana_online_shop_mobile/features/orders/domain/order_status.dart';
import 'package:arcana_online_shop_mobile/features/orders/presentation/order_list_page.dart';

final _baht = NumberFormat('#,##0.00', 'th');
String _formatPrice(double amount) => '฿${_baht.format(amount)}';

// รองรับทั้ง ISO 8601 และ JS Date.toString()
// เช่น "Thu Jun 04 2026 12:59:28 GMT+0700 (เวลาอินโดจีน)"
DateTime _parseDate(String raw) {
  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso.toLocal();
  try {
    // ตัด "(timezone name)" ออก แล้วลบ GMT prefix ก่อน offset
    final stripped = raw
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .replaceFirst('GMT', '')
        .trim();
    return DateFormat(
      'EEE MMM dd yyyy HH:mm:ss Z',
      'en',
    ).parse(stripped).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

String _formatDate(String raw) {
  final dt = _parseDate(raw);
  return DateFormat('d MMMM yyyy HH:mm', 'th').format(dt);
}

String _formatDateShort(String raw) {
  final dt = _parseDate(raw);
  return DateFormat('d MMM yy HH:mm', 'th').format(dt);
}

// ลำดับ flow ปกติ — เหมือน DEFAULT_ORDER_FLOW ในเว็บ
const _defaultOrderFlow = [
  OrderStatusCode.pending,
  OrderStatusCode.confirmed,
  OrderStatusCode.processing,
  OrderStatusCode.packed,
  OrderStatusCode.readyToShip,
  OrderStatusCode.delivered,
  OrderStatusCode.received,
];

const _terminalStatuses = [
  OrderStatusCode.cancelled,
  OrderStatusCode.refunded,
  OrderStatusCode.returnRequested,
  OrderStatusCode.returnRequestedCompleted,
];

const _flowLabels = <String, String>{
  OrderStatusCode.pending: 'รอชำระ',
  OrderStatusCode.confirmed: 'ชำระแล้ว',
  OrderStatusCode.processing: 'เตรียมสินค้า',
  OrderStatusCode.packed: 'แพ็คแล้ว',
  OrderStatusCode.readyToShip: 'พร้อมส่ง',
  OrderStatusCode.delivered: 'จัดส่งแล้ว',
  OrderStatusCode.received: 'รับสินค้า',
};

const _flowIcons = <String, IconData>{
  OrderStatusCode.pending: Icons.receipt_long_outlined,
  OrderStatusCode.confirmed: Icons.account_balance_wallet_outlined,
  OrderStatusCode.processing: Icons.inventory_2_outlined,
  OrderStatusCode.packed: Icons.archive_outlined,
  OrderStatusCode.readyToShip: Icons.local_shipping_outlined,
  OrderStatusCode.delivered: Icons.check_circle_outline,
  OrderStatusCode.received: Icons.done_all,
};

const _cancelReasons = [
  'สั่งซื้อผิดรายการ',
  'ต้องการเปลี่ยนที่อยู่จัดส่ง',
  'ต้องการเปลี่ยนวิธีชำระเงิน',
  'พบราคาหรือโปรโมชันที่ดีกว่า',
  'ไม่ต้องการสินค้าแล้ว',
  'อื่นๆ',
];

class _RefundRequestPayload {
  const _RefundRequestPayload({
    required this.reason,
    required this.returnTracking,
    required this.imagePaths,
  });

  final String reason;
  final String returnTracking;
  final List<String> imagePaths;
}

String _formatRefundRemark(String? remark) {
  final value = remark?.trim();
  if (value == null || value.isEmpty) return '';
  return value
      .split('|')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map((part) {
        final failedRefundPattern = RegExp(
          r'^Omise (failed_refund|refund failed):',
          caseSensitive: false,
        );
        if (failedRefundPattern.hasMatch(part)) {
          return 'คืนเงินผ่านระบบไม่สำเร็จ';
        }
        if (RegExp(r'^Omise refund:', caseSensitive: false).hasMatch(part)) {
          return 'คืนเงินผ่านระบบสำเร็จ';
        }
        if (part.contains("charge can't be refund")) {
          return 'คืนเงินผ่านระบบไม่สำเร็จ';
        }
        if (part.contains('ต้องโอนคืนลูกค้าแบบ Manual')) {
          return 'ร้านค้าต้องโอนคืนด้วยตนเอง';
        }
        return part.replaceAll('Manual', 'ด้วยตนเอง');
      })
      .join(' · ');
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.order, required this.api});

  final Order order;
  final OrdersApi api;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage>
    with WidgetsBindingObserver {
  late Order _order;
  late final ApiClient _client;
  List<OrderItem> _items = [];
  bool _loadingItems = true;
  String? _itemLoadError;
  bool _cancelling = false;
  bool _requestingRefund = false;
  bool _confirmingReceived = false;
  bool _paying = false;
  bool _reordering = false;
  bool _refreshingOrder = false;
  bool _reviewing = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _order = widget.order;
    _client = ApiClient();
    if ((_order.items ?? []).isNotEmpty) {
      _items = _order.items!;
      _loadingItems = false;
    } else {
      _loadItems();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrder());
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshOrder(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOrder();
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      _loadingItems = true;
      _itemLoadError = null;
    });
    try {
      final items = await widget.api.fetchOrderItems(_order.orId, 'th');
      if (!mounted) return;
      setState(() {
        _items = items;
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itemLoadError = e.toString();
        _loadingItems = false;
      });
    }
  }

  Future<void> _refreshOrder() async {
    if (_refreshingOrder) return;
    _refreshingOrder = true;
    try {
      final latestOrder = await widget.api.fetchOrderDetail(_order.orId, 'th');
      if (!mounted) return;
      final latestItems = latestOrder.items;
      setState(() {
        _order = latestOrder.copyWith(items: latestItems ?? _items);
        if (latestItems != null) {
          _items = latestItems;
          _loadingItems = false;
          _itemLoadError = null;
        }
      });
    } catch (_) {
      // The current order still reflects that the payment window has expired.
    } finally {
      _refreshingOrder = false;
    }
  }

  void _markPaymentExpired() {
    setState(
      () => _order = _order.copyWith(
        status: 'cancelled',
        statusCode: OrderStatusCode.cancelled,
        statusLabel: 'ยกเลิกแล้ว',
        items: _items,
      ),
    );
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

  Future<bool> _isCurrentOrderPaymentConfirmed() async {
    try {
      await CheckoutApi().syncPromptPayCharge(_order.orId);
    } catch (_) {
      // The webhook may have already synced the payment, or the order may no
      // longer have a pending PromptPay charge. Refresh below decides the UI.
    }
    await _refreshOrder();
    return _isOrderPaymentConfirmed(_order);
  }

  void _navigateToOrderList() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderListPage()),
    );
  }

  Future<void> _showCancelDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (result == null || !mounted) return;
    await _doCancel(result);
  }

  Future<void> _doCancel(String reason) async {
    setState(() => _cancelling = true);
    try {
      final updated = await widget.api.cancelOrder(_order.orId, reason);
      if (!mounted) return;
      setState(() {
        _order = updated.copyWith(items: _items);
        _cancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยกเลิกคำสั่งซื้อเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ยกเลิกไม่สำเร็จ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRefundDialog() async {
    final result = await showDialog<_RefundRequestPayload>(
      context: context,
      builder: (_) => _RefundRequestDialog(
        isDelivered: getOrderStatusCode(_order) == OrderStatusCode.delivered,
      ),
    );
    if (result == null || !mounted) return;
    await _doRequestRefund(result);
  }

  Future<void> _doRequestRefund(_RefundRequestPayload payload) async {
    setState(() => _requestingRefund = true);
    try {
      final updated = await widget.api.requestRefund(
        _order.orId,
        reason: payload.reason,
        returnTracking: payload.returnTracking,
        imagePaths: payload.imagePaths,
      );
      if (!mounted) return;
      setState(() {
        _order = updated.copyWith(items: _items);
        _requestingRefund = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งคำขอคืนเงินแล้ว รอร้านค้าตรวจสอบ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _requestingRefund = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งคำขอคืนเงินไม่สำเร็จ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _isPaymentExpired {
    final exp = _order.paymentExpiresAt;
    if (exp == null) return true;
    final expiry = _parseDate(exp);
    return !expiry.isAfter(DateTime.now());
  }

  Future<void> _handlePayPromptPay() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final checkoutApi = CheckoutApi();
      final payment = await checkoutApi.payExistingOrderPromptPay(
        orderId: _order.orId,
      );
      if (!mounted) return;
      if (payment.qrCodeUri != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PromptPayDialog(
            qrCodeUri: payment.qrCodeUri!,
            grandTotal: _order.grandTotal,
            expiresAt: _order.paymentExpiresAt,
            onDone: () => Navigator.of(context).pop(),
            isPaymentConfirmed: _isCurrentOrderPaymentConfirmed,
            onPaymentConfirmed: () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ชำระเงินสำเร็จ'),
                  backgroundColor: Colors.green,
                ),
              );
              _navigateToOrderList();
            },
            onExpired: () async {
              await _refreshOrder();
              if (!mounted) return;
              _markPaymentExpired();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QR หมดอายุ คำสั่งซื้อถูกยกเลิกแล้ว'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สร้าง QR ไม่สำเร็จ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _doConfirmReceived() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันรับสินค้า'),
        content: const Text('คุณได้รับสินค้าครบถ้วนแล้วใช่ไหม?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _confirmingReceived = true);
    try {
      final updated = await widget.api.confirmReceived(_order.orId);
      if (!mounted) return;
      setState(() {
        _order = updated.copyWith(items: _items);
        _confirmingReceived = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยืนยันรับสินค้าเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirmingReceived = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReviewDialog() async {
    if (_reviewing) return;
    if (_items.isEmpty) {
      await _loadItems();
      if (!mounted || _items.isEmpty) return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรายการสินค้าสำหรับรีวิว')),
      );
      return;
    }

    setState(() => _reviewing = true);
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewDialog(
        api: widget.api,
        items: _items,
        resolveImageUrl: _client.resolveAssetUrl,
      ),
    );
    if (!mounted) return;
    setState(() => _reviewing = false);

    if (completed == true) {
      await _refreshOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกรีวิวเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _reorder() async {
    if (_reordering) return;
    if (_items.isEmpty) {
      await _loadItems();
      if (!mounted || _items.isEmpty) return;
    }

    setState(() => _reordering = true);
    try {
      final existingCiIds = CartController.instance.items
          .map((item) => item.ciId)
          .toSet();

      for (final item in _items) {
        await CartController.instance.addItem(pvId: item.pvId, qty: item.qty);
      }

      if (!mounted) return;
      final repeatedItems = CartController.instance.items
          .where((item) => !existingCiIds.contains(item.ciId))
          .toList();
      final repeatedPvIds = _items.map((item) => item.pvId).toSet();
      final checkoutItems = repeatedItems.isNotEmpty
          ? repeatedItems
          : CartController.instance.items
                .where((item) => repeatedPvIds.contains(item.pvId))
                .toList();
      final selectedCiIds = checkoutItems.map((item) => item.ciId).toList();

      if (selectedCiIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่มสินค้าซ้ำไม่สำเร็จ')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutPage(
            selectedCiIds: selectedCiIds,
            selectedTotal: checkoutItems.fold<double>(
              0,
              (sum, item) => sum + item.lineTotal,
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ซื้อซ้ำไม่สำเร็จ กรุณาลองใหม่')),
      );
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusCode = getOrderStatusCode(_order);
    final canCancel = statusCode == OrderStatusCode.pending;
    final canRequestRefund =
        {
          OrderStatusCode.confirmed,
          OrderStatusCode.processing,
          OrderStatusCode.packed,
          OrderStatusCode.delivered,
        }.contains(statusCode) &&
        _order.refundStatus == null;
    final canConfirmReceived = statusCode == OrderStatusCode.delivered;
    final canPayPromptPay =
        statusCode == OrderStatusCode.pending && !_isPaymentExpired;
    final canReorder =
        {
          OrderStatusCode.cancelled,
          OrderStatusCode.received,
          OrderStatusCode.autoReceived,
          OrderStatusCode.reviewed,
        }.contains(statusCode) &&
        (_items.isNotEmpty || !_loadingItems);
    final canReview =
        {
          OrderStatusCode.received,
          OrderStatusCode.autoReceived,
        }.contains(statusCode) &&
        !_loadingItems &&
        _items.isNotEmpty;

    return PopScope<Order>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_order);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _order.orderNo != null
                ? 'คำสั่งซื้อ ${_order.orderNo}'
                : 'รายละเอียดคำสั่งซื้อ',
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshOrder,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Header: สถานะ + วันที่ + ยอดรวม
                _SectionCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: getOrderStatusBgColor(_order),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                getOrderStatusLabel(_order),
                                style: TextStyle(
                                  color: getOrderStatusColor(_order),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(_order.createdAt),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ยอดรวม',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _formatPrice(_order.grandTotal),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ความคืบหน้าคำสั่งซื้อ
                _OrderProgressSection(order: _order),
                const SizedBox(height: 12),

                // รายการสินค้า
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        icon: Icons.shopping_bag_outlined,
                        label: 'รายการสินค้า (${_order.itemCount})',
                      ),
                      const SizedBox(height: 12),
                      if (_loadingItems)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_itemLoadError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Text(
                                'โหลดรายการสินค้าไม่สำเร็จ',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _loadItems,
                                child: const Text('ลองใหม่'),
                              ),
                            ],
                          ),
                        )
                      else if (_items.isEmpty)
                        const Text('ไม่พบรายการสินค้า')
                      else
                        ...List.generate(_items.length, (i) {
                          final item = _items[i];
                          final hasDivider = i < _items.length - 1;
                          return Column(
                            children: [
                              _OrderItemRow(
                                item: item,
                                resolveImageUrl: _client.resolveAssetUrl,
                              ),
                              if (hasDivider) const Divider(height: 16),
                            ],
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ที่อยู่จัดส่ง
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        icon: Icons.location_on_outlined,
                        label: 'ที่อยู่จัดส่ง',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'จัดส่งให้ ${_order.shippingName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_order.shippingPhone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _order.shippingPhone!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _buildAddressText(_order),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Timeline การจัดส่ง
                _ShipmentTimelineCard(order: _order),

                // สรุปยอดชำระ
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        icon: Icons.receipt_outlined,
                        label: 'สรุปยอดชำระ',
                      ),
                      const SizedBox(height: 10),
                      if (_order.subtotalAmount != null)
                        _PriceLine(
                          label: 'ราคาสินค้า',
                          value: _formatPrice(_order.subtotalAmount!),
                        ),
                      if (_order.discountAmount != null &&
                          _order.discountAmount! > 0)
                        _PriceLine(
                          label: 'ส่วนลด',
                          value: '-${_formatPrice(_order.discountAmount!)}',
                          valueColor: Colors.green.shade700,
                        ),
                      if (_order.couponCode != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_offer_outlined,
                                size: 14,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'คูปอง ${_order.couponCode}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_order.couponDiscountAmount != null &&
                                  _order.couponDiscountAmount! > 0)
                                Text(
                                  '-${_formatPrice(_order.couponDiscountAmount!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (_order.shippingFee != null)
                        _PriceLine(
                          label: _buildShippingLabel(_order),
                          value: _formatPrice(_order.shippingFee!),
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
                            _formatPrice(_order.grandTotal),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                if (_order.refundStatus != null) ...[
                  const SizedBox(height: 12),
                  _RefundStatusNotice(order: _order),
                ],
                if (canPayPromptPay ||
                    canCancel ||
                    canRequestRefund ||
                    canConfirmReceived ||
                    canReview ||
                    canReorder) ...[
                  const SizedBox(height: 20),
                  if (canReorder)
                    FilledButton.icon(
                      onPressed: _reordering ? null : _reorder,
                      icon: _reordering
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.replay_outlined),
                      label: Text(
                        _reordering ? 'กำลังเพิ่มสินค้า...' : 'ซื้อซ้ำ',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  if (canReorder &&
                      (canPayPromptPay ||
                          canConfirmReceived ||
                          canReview ||
                          canCancel ||
                          canRequestRefund))
                    const SizedBox(height: 10),
                  if (canReview)
                    FilledButton.icon(
                      onPressed: _reviewing ? null : _showReviewDialog,
                      icon: _reviewing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.star_outline),
                      label: Text(_reviewing ? 'กำลังเปิดรีวิว...' : 'รีวิวสินค้า'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (canReview &&
                      (canPayPromptPay ||
                          canConfirmReceived ||
                          canCancel ||
                          canRequestRefund))
                    const SizedBox(height: 10),
                  if (canPayPromptPay)
                    FilledButton.icon(
                      onPressed: _paying ? null : _handlePayPromptPay,
                      icon: _paying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.qr_code_2_outlined),
                      label: Text(
                        _paying ? 'กำลังสร้าง QR...' : 'ชำระด้วย PromptPay',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.purple.shade700,
                      ),
                    ),
                  if (canPayPromptPay &&
                      (canConfirmReceived || canCancel || canRequestRefund))
                    const SizedBox(height: 10),
                  if (canConfirmReceived)
                    FilledButton.icon(
                      onPressed: _confirmingReceived
                          ? null
                          : _doConfirmReceived,
                      icon: _confirmingReceived
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _confirmingReceived
                            ? 'กำลังยืนยัน...'
                            : 'ยืนยันรับสินค้า',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.green.shade600,
                      ),
                    ),
                  if (canConfirmReceived && (canCancel || canRequestRefund))
                    const SizedBox(height: 10),
                  if (canRequestRefund)
                    OutlinedButton.icon(
                      onPressed: _requestingRefund ? null : _showRefundDialog,
                      icon: _requestingRefund
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.undo_outlined),
                      label: Text(
                        _requestingRefund
                            ? 'กำลังส่งคำขอ...'
                            : statusCode == OrderStatusCode.delivered
                            ? 'ขอคืนเงิน/คืนสินค้า'
                            : 'ขอยกเลิก/คืนเงิน',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: Colors.amber.shade800,
                        side: BorderSide(color: Colors.amber.shade300),
                      ),
                    ),
                  if (canCancel) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _cancelling ? null : _showCancelDialog,
                      icon: _cancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined),
                      label: Text(
                        _cancelling ? 'กำลังยกเลิก...' : 'ยกเลิกคำสั่งซื้อ',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildAddressText(Order order) {
    final area = [
      order.shippingSubdistrictName,
      order.shippingDistrictName,
      order.shippingProvinceName,
      order.shippingZipCode,
    ].where((s) => s != null && s.isNotEmpty).join(' ');

    return [order.shippingAddress, area].where((s) => s.isNotEmpty).join(' ');
  }

  String _buildShippingLabel(Order order) {
    final carrier = order.shippingCarrierName ?? order.carrierName;
    if (carrier != null && carrier.isNotEmpty) return 'ค่าจัดส่ง ($carrier)';
    return 'ค่าจัดส่ง';
  }
}

// ─── Order progress stepper ──────────────────────────────────────────────────

class _OrderProgressSection extends StatelessWidget {
  const _OrderProgressSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final statusCode = getOrderStatusCode(order);
    final statusLabel = getOrderStatusLabel(order);
    final isTerminal = _terminalStatuses.contains(statusCode);

    if (isTerminal) {
      return _TerminalStatusCard(
        statusCode: statusCode,
        statusLabel: statusLabel,
      );
    }

    // map AUTO_RECEIVED / REVIEWED → RECEIVED สำหรับ active index
    final flowCode =
        (statusCode == OrderStatusCode.autoReceived ||
            statusCode == OrderStatusCode.reviewed)
        ? OrderStatusCode.received
        : statusCode;
    final activeIndex = _defaultOrderFlow.indexOf(flowCode);
    final safeActive = activeIndex >= 0 ? activeIndex : 0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'ความคืบหน้าคำสั่งซื้อ',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สถานะล่าสุด: $statusLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(_defaultOrderFlow.length, (index) {
                final code = _defaultOrderFlow[index];
                final isDone = index < safeActive;
                final isCurrent = index == safeActive;
                final isLast = index == _defaultOrderFlow.length - 1;
                final icon = _flowIcons[code] ?? Icons.circle_outlined;
                final label = _flowLabels[code] ?? code;
                final activeColor = Colors.green.shade600;
                final inactiveColor = Theme.of(
                  context,
                ).colorScheme.outlineVariant;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isDone || isCurrent)
                                  ? Colors.green.shade50
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              border: Border.all(
                                color: (isDone || isCurrent)
                                    ? activeColor
                                    : inactiveColor,
                                width: 2.5,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 22,
                              color: (isDone || isCurrent)
                                  ? activeColor
                                  : inactiveColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: (isDone || isCurrent)
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: (isDone || isCurrent)
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (isCurrent)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'กำลังดำเนินการ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Container(
                          width: 20,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isDone ? activeColor : inactiveColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalStatusCard extends StatelessWidget {
  const _TerminalStatusCard({
    required this.statusCode,
    required this.statusLabel,
  });

  final String statusCode;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final (icon, bgColor, borderColor, textColor) = switch (statusCode) {
      OrderStatusCode.cancelled => (
        Icons.cancel_outlined,
        Colors.red.shade50,
        Colors.red.shade200,
        Colors.red.shade800,
      ),
      OrderStatusCode.refunded => (
        Icons.undo_outlined,
        Colors.grey.shade100,
        Colors.grey.shade300,
        Colors.grey.shade800,
      ),
      OrderStatusCode.returnRequested => (
        Icons.assignment_return_outlined,
        Colors.orange.shade50,
        Colors.orange.shade200,
        Colors.orange.shade800,
      ),
      _ => (
        Icons.check_circle_outline,
        Colors.grey.shade100,
        Colors.grey.shade300,
        Colors.grey.shade800,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'คำสั่งซื้อนี้จบกระบวนการแล้ว',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shipment timeline ───────────────────────────────────────────────────────

class _ShipmentTimelineCard extends StatelessWidget {
  const _ShipmentTimelineCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final events = order.shipmentEvents ?? [];
    final hasTracking = order.trackingNo != null;
    final hasCarrier = (order.carrierName ?? order.shippingCarrierName) != null;

    // ไม่แสดงถ้าไม่มีข้อมูลขนส่งเลย
    if (!hasTracking && events.isEmpty) return const SizedBox.shrink();

    final sorted = [...events]
      ..sort((a, b) {
        int toMs(String s) {
          try {
            return DateTime.parse(s).millisecondsSinceEpoch;
          } catch (_) {
            return 0;
          }
        }

        return toMs(b.occurredAt).compareTo(toMs(a.occurredAt));
      });

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: Colors.cyan.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: Colors.cyan.shade800,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'การจัดส่ง',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.cyan.shade800,
                    ),
                  ),
                  if (sorted.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${sorted.length} เหตุการณ์',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.cyan.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // แถว 2: carrier + tracking (ถ้ามี)
            if (hasCarrier || hasTracking)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                color: Colors.cyan.shade50,
                child: Row(
                  children: [
                    if (hasCarrier) ...[
                      Icon(
                        Icons.directions_car_outlined,
                        size: 13,
                        color: Colors.cyan.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.carrierName ?? order.shippingCarrierName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.cyan.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (hasTracking)
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.trackingNo!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.cyan.shade800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // สถานะการจัดส่ง
                  if (sorted.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          'สถานะการจัดส่ง',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        Text(
                          'ล่าสุด ${_formatDateShort(sorted.first.occurredAt)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      sorted.length,
                      (i) => _ShipmentEventItem(
                        event: sorted[i],
                        isFirst: i == 0,
                        isLast: i == sorted.length - 1,
                      ),
                    ),
                  ] else ...[
                    // รอข้อมูลจากขนส่ง
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.cyan.shade100,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                            color: Colors.cyan.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'รอข้อมูลจากขนส่ง',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.cyan.shade800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'ระบบจะดึงสถานะมาแสดงที่นี่เมื่อมีข้อมูลอัปเดต',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.cyan.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShipmentEventItem extends StatelessWidget {
  const _ShipmentEventItem({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final ShipmentEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: isFirst ? 14 : 10,
                  height: isFirst ? 14 : 10,
                  margin: EdgeInsets.only(top: isFirst ? 2 : 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst
                        ? Colors.cyan.shade500
                        : Colors.grey.shade300,
                    border: isFirst
                        ? Border.all(color: Colors.cyan.shade200, width: 3)
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isFirst
                          ? Colors.cyan.shade700
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateShort(event.occurredAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isFirst
                          ? Colors.cyan.shade600
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (event.description != null &&
                      event.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
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

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item, required this.resolveImageUrl});

  final OrderItem item;
  final String Function(String? value) resolveImageUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveImageUrl(item.imageUrl);
    final hasDiscount =
        item.originalLineTotal != null &&
        item.originalLineTotal! > item.lineTotal;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _PlaceholderThumb(size: 68),
                )
              : _PlaceholderThumb(size: 68),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (item.variantName != null && item.variantName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.variantName!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'x${item.qty}  ·  ${_formatPrice(item.unitPrice)}/ชิ้น',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (hasDiscount)
              Text(
                _formatPrice(item.originalLineTotal!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              _formatPrice(item.lineTotal),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        size: size * 0.4,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _RefundStatusNotice extends StatelessWidget {
  const _RefundStatusNotice({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final status = order.refundStatus;
    if (status == null) return const SizedBox.shrink();

    final remark = _formatRefundRemark(order.refundRemark);
    final config = switch (status) {
      'pending' => (
        Icons.hourglass_top_outlined,
        Colors.amber.shade50,
        Colors.amber.shade200,
        Colors.amber.shade800,
        'ส่งคำขอคืนเงินแล้ว รอร้านค้าตรวจสอบ',
      ),
      'failed' => (
        Icons.error_outline,
        Colors.red.shade50,
        Colors.red.shade200,
        Colors.red.shade700,
        'คำขอคืนเงิน/คืนสินค้าไม่ผ่านการอนุมัติ',
      ),
      'succeeded' => (
        Icons.check_circle_outline,
        Colors.green.shade50,
        Colors.green.shade200,
        Colors.green.shade700,
        'คืนเงิน/คืนสินค้าเรียบร้อยแล้ว',
      ),
      _ => (
        Icons.info_outline,
        Colors.grey.shade100,
        Colors.grey.shade300,
        Colors.grey.shade700,
        'สถานะคืนเงิน: $status',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: config.$2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: config.$3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(config.$1, size: 18, color: config.$4),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.$5,
                  style: TextStyle(
                    color: config.$4,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (remark.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'เหตุผล/หมายเหตุ: $remark',
                    style: TextStyle(
                      color: config.$4.withValues(alpha: 0.86),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.api,
    required this.items,
    required this.resolveImageUrl,
  });

  final OrdersApi api;
  final List<OrderItem> items;
  final String Function(String? value) resolveImageUrl;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _messageController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  int _step = 0;
  int _productScore = 5;
  int _deliveryScore = 5;
  bool _submitting = false;
  String? _messageErrorText;

  OrderItem get _item => widget.items[_step];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _messageController.clear();
    _images.clear();
    _productScore = 5;
    _deliveryScore = 5;
    _messageErrorText = null;
  }

  Future<void> _showImageSourceSheet() async {
    if (_images.length >= 5 || _submitting) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ถ่ายรูป'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกรูปจากเครื่อง'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;
    if (source == ImageSource.camera) {
      await _pickFromCamera();
    } else {
      await _pickFromGallery();
    }
  }

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _images.add(picked);
      _trimImages();
    });
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _images.addAll(picked.take(5 - _images.length));
      _trimImages();
    });
  }

  void _trimImages() {
    if (_images.length > 5) {
      _images.removeRange(5, _images.length);
    }
  }

  Future<void> _submitCurrent() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _messageErrorText = 'กรุณาเขียนรีวิวสินค้า');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.api.submitReview(
        pvId: _item.pvId,
        oiId: _item.oiId,
        message: message,
        productScore: _productScore,
        deliveryScore: _deliveryScore,
        imagePaths: _images.map((image) => image.path).toList(),
      );
      if (!mounted) return;

      final nextStep = _step + 1;
      if (nextStep < widget.items.length) {
        setState(() {
          _step = nextStep;
          _resetForm();
          _submitting = false;
        });
      } else {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกรีวิวไม่สำเร็จ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = widget.resolveImageUrl(_item.imageUrl);
    final total = widget.items.length;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      title: Row(
        children: [
          Icon(Icons.star_outline, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text('รีวิวสินค้า ${_step + 1}/$total')),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const _PlaceholderThumb(size: 58),
                          )
                        : const _PlaceholderThumb(size: 58),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if ((_item.variantName ?? '').isNotEmpty)
                          Text(
                            _item.variantName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _StarSelector(
                label: 'คะแนนสินค้า',
                value: _productScore,
                onChanged: (value) => setState(() => _productScore = value),
              ),
              const SizedBox(height: 12),
              _StarSelector(
                label: 'คะแนนการจัดส่ง',
                value: _deliveryScore,
                onChanged: (value) => setState(() => _deliveryScore = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'แบ่งปันความคิดเห็นเกี่ยวกับสินค้านี้',
                  errorText: _messageErrorText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_messageErrorText != null) {
                    setState(() => _messageErrorText = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'รูปภาพประกอบ',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '  (${_images.length}/5)',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...List.generate(_images.length, (index) {
                    final image = _images[index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(image.path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton.filled(
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _images.removeAt(index)),
                            icon: const Icon(Icons.close, size: 14),
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_images.length < 5)
                    InkWell(
                      onTap: _submitting ? null : _showImageSourceSheet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.outlineVariant),
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'เพิ่มรูป',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'รูปภาพไม่บังคับ แนบได้สูงสุด 5 รูป',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('ปิด'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submitCurrent,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined, size: 18),
          label: Text(
            _submitting
                ? 'กำลังส่ง...'
                : _step + 1 < total
                ? 'ส่งและรีวิวถัดไป'
                : 'ส่งรีวิว',
          ),
        ),
      ],
    );
  }
}

class _StarSelector extends StatelessWidget {
  const _StarSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final score = index + 1;
            return IconButton(
              onPressed: () => onChanged(score),
              icon: Icon(
                score <= value ? Icons.star : Icons.star_border,
                color: Colors.amber.shade600,
              ),
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            );
          }),
        ),
      ],
    );
  }
}

// ─── Cancel dialog ───────────────────────────────────────────────────────────

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  String _selectedReason = _cancelReasons.first;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: Colors.red),
          SizedBox(width: 8),
          Text('ยกเลิกคำสั่งซื้อ'),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'กรุณาเลือกเหตุผลในการยกเลิก',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            ..._cancelReasons.map((reason) {
              return ListTile(
                leading: Transform.scale(
                  scale: 0.9,
                  child: Radio<String>(
                    value: reason,
                    // ignore: deprecated_member_use
                    groupValue: _selectedReason,
                    // ignore: deprecated_member_use
                    onChanged: (v) => setState(() => _selectedReason = v!),
                    activeColor: Colors.red.shade700,
                  ),
                ),
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                onTap: () => setState(() => _selectedReason = reason),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              );
            }),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('กลับ'),
        ),
        FilledButton(
          onPressed: () {
            final note = _noteController.text.trim();
            final reason = note.isNotEmpty
                ? '$_selectedReason - $note'
                : _selectedReason;
            Navigator.of(context).pop(reason);
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          child: const Text('ยืนยันยกเลิก'),
        ),
      ],
    );
  }
}

class _RefundRequestDialog extends StatefulWidget {
  const _RefundRequestDialog({required this.isDelivered});

  final bool isDelivered;

  @override
  State<_RefundRequestDialog> createState() => _RefundRequestDialogState();
}

class _RefundRequestDialogState extends State<_RefundRequestDialog> {
  final _reasonController = TextEditingController();
  final _trackingController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  String? _errorText;
  String? _imageErrorText;
  String? _trackingErrorText;

  @override
  void dispose() {
    _reasonController.dispose();
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceSheet() async {
    if (_images.length >= 3) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ถ่ายรูป'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกรูปจากเครื่อง'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;
    if (source == ImageSource.camera) {
      await _pickFromCamera();
    } else {
      await _pickFromGallery();
    }
  }

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _images.add(picked);
      _imageErrorText = null;
      _trimImages();
    });
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _images.addAll(picked.take(3 - _images.length));
      _imageErrorText = null;
      _trimImages();
    });
  }

  void _trimImages() {
    if (_images.length > 3) {
      _images.removeRange(3, _images.length);
    }
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    final tracking = _trackingController.text.trim();
    if (reason.length < 5) {
      setState(() => _errorText = 'กรุณาระบุเหตุผลอย่างน้อย 5 ตัวอักษร');
      return;
    }
    if (_images.isEmpty) {
      setState(() => _imageErrorText = 'กรุณาแนบรูปถ่ายประกอบอย่างน้อย 1 รูป');
      return;
    }
    if (tracking.length < 3) {
      setState(() => _trackingErrorText = 'กรุณาระบุเลข Tracking พัสดุที่ส่งคืน');
      return;
    }
    Navigator.of(context).pop(
      _RefundRequestPayload(
        reason: reason,
        returnTracking: tracking,
        imagePaths: _images.map((image) => image.path).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageBorderColor = _imageErrorText == null
        ? colorScheme.outlineVariant
        : colorScheme.error;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      title: Row(
        children: [
          Icon(Icons.undo_outlined, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isDelivered ? 'ขอคืนสินค้า/คืนเงิน' : 'ขอยกเลิก/คืนเงิน',
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isDelivered
                    ? 'ใช้สำหรับกรณีสินค้าเสียหาย ไม่ครบ หรือไม่สมบูรณ์ ร้านค้าจะตรวจสอบก่อนดำเนินการ'
                    : 'ส่งคำขอยกเลิกและคืนเงินให้ร้านค้าตรวจสอบก่อนดำเนินการ',
                style: TextStyle(
                  color: Colors.amber.shade800,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'รายละเอียดปัญหาสินค้าที่ได้รับ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                      'สินค้าเสียหายหรือไม่สมบูรณ์ ต้องการคืนสินค้าและขอคืนเงิน',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'รูปถ่ายประกอบ *',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '  (${_images.length}/3)',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...List.generate(_images.length, (index) {
                    final image = _images[index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(image.path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton.filled(
                            onPressed: () {
                              setState(() {
                                _images.removeAt(index);
                                if (_images.isNotEmpty) {
                                  _imageErrorText = null;
                                }
                              });
                            },
                            icon: const Icon(Icons.close, size: 14),
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (_images.length < 3)
                    InkWell(
                      onTap: _showImageSourceSheet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: imageBorderColor),
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'เพิ่มรูป',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_imageErrorText != null) ...[
                Text(
                  _imageErrorText!,
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                'รูปถ่ายสินค้าที่เสียหายหรือไม่สมบูรณ์ ขนาดไม่เกิน 5MB ต่อรูป',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'เลข Tracking พัสดุที่ส่งคืน *',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _trackingController,
                decoration: InputDecoration(
                  hintText: 'กรอกเลขพัสดุที่ส่งคืนสินค้า',
                  errorText: _trackingErrorText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_trackingErrorText != null) {
                    setState(() => _trackingErrorText = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                'ต้องส่งเลข Tracking ให้ร้านค้าตรวจสอบและยืนยันรับสินค้าคืนก่อนดำเนินการคืนเงิน',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('กลับ'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('ส่งคำขอ'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
