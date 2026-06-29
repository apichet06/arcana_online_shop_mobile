import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/orders/data/orders_api.dart';
import 'package:arcana_online_shop_mobile/features/orders/domain/order.dart';
import 'package:arcana_online_shop_mobile/features/orders/domain/order_status.dart';
import 'order_detail_page.dart';

final _baht = NumberFormat('#,##0.00', 'th');
String _formatPrice(double amount) => '฿${_baht.format(amount)}';

String _formatDate(String isoDate) {
  try {
    final dt = DateTime.parse(isoDate).toLocal();
    return DateFormat('d MMM yyyy', 'th').format(dt);
  } catch (_) {
    return isoDate;
  }
}

// Tab definitions — ตรงกับ ORDER_TABS ในเว็บ
class _OrderTab {
  const _OrderTab({required this.key, required this.label});
  final String key;
  final String label;
}

const _orderTabs = [
  _OrderTab(key: 'all', label: 'ทั้งหมด'),
  _OrderTab(key: 'to_pay', label: 'ที่ต้องชำระ'),
  _OrderTab(key: 'to_ship', label: 'ที่ต้องจัดส่ง'),
  _OrderTab(key: 'to_receive', label: 'ที่ต้องได้รับ'),
  _OrderTab(key: 'completed', label: 'สำเร็จ'),
  _OrderTab(key: 'cancelled', label: 'ยกเลิก'),
  _OrderTab(key: 'refund', label: 'คืนเงิน'),
];

// จับ order ใส่ tab key — logic เดียวกับ getOrderTabKey ในเว็บ
String _getTabKey(Order order) {
  final code = getOrderStatusCode(order);
  final refund = order.refundStatus;

  if (code == OrderStatusCode.refunded ||
      refund == 'pending' ||
      refund == 'succeeded' ||
      refund == 'failed') { return 'refund'; }
  if ([
    OrderStatusCode.received,
    OrderStatusCode.autoReceived,
    OrderStatusCode.reviewed,
  ].contains(code) || order.status == 'completed') { return 'completed'; }
  if (code == OrderStatusCode.pending) { return 'to_pay'; }
  if ([
    OrderStatusCode.confirmed,
    OrderStatusCode.processing,
    OrderStatusCode.packed,
  ].contains(code)) { return 'to_ship'; }
  if ([
    OrderStatusCode.readyToShip,
    OrderStatusCode.delivered,
  ].contains(code) || order.status == 'delivered') { return 'to_receive'; }
  if (code == OrderStatusCode.cancelled) { return 'cancelled'; }
  return 'all';
}

// search logic เดียวกับ orderMatchesSearch ในเว็บ
bool _orderMatchesSearch(Order order, String term) {
  if (term.isEmpty) return true;
  final compactTerm = term.replaceAll(RegExp(r'[\s\-_#/]+'), '');

  String norm(Object? v) =>
      (v?.toString() ?? '').trim().toLowerCase().replaceAll(',', '');
  String compact(String v) => v.replaceAll(RegExp(r'[\s\-_#/]+'), '');

  final fields = <String?>[
    order.orId.toString(),
    order.orderNo,
    order.status,
    order.statusCode,
    order.statusLabel,
    order.refundStatus,
    order.refundRemark,
    order.grandTotal.toString(),
    order.couponCode,
    order.shippingName,
    order.shippingPhone,
    order.shippingAddress,
    order.shippingSubdistrictName,
    order.shippingDistrictName,
    order.shippingProvinceName,
    order.shippingZipCode,
    order.carrierName,
    order.shippingCarrierName,
    order.trackingNo,
    order.createdAt,
    order.itemCount.toString(),
    ...?order.items?.expand((item) => <String?>[
          item.productName,
          item.variantName,
          item.storeName,
        ]),
  ];

  return fields.any((f) {
    final n = norm(f);
    return n.contains(term) || compact(n).contains(compactTerm);
  });
}

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final OrdersApi _api;
  final TextEditingController _searchController = TextEditingController();
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _orderTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _api = OrdersApi(client: ApiClient());
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) setState(() {});
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var orders = await _api.fetchOrders('th');
      final synced = await _syncPendingPromptPayOrders(orders);
      if (synced) {
        orders = await _api.fetchOrders('th');
      }
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _syncPendingPromptPayOrders(List<Order> orders) async {
    final pendingOrders = orders.where((order) {
      return getOrderStatusCode(order) == OrderStatusCode.pending;
    }).toList();
    if (pendingOrders.isEmpty) return false;

    var syncedAny = false;
    for (final order in pendingOrders) {
      try {
        await _api.syncPromptPayCharge(order.orId);
        syncedAny = true;
      } catch (_) {
        // Not every pending order is guaranteed to have a pending PromptPay
        // charge. Ignore individual sync failures and keep the list usable.
      }
    }
    return syncedAny;
  }

  int get _activeOrdersCount {
    return _orders
        .where((o) => !['completed', 'cancelled', 'refund'].contains(_getTabKey(o)))
        .length;
  }

  List<Order> get _filteredOrders {
    final tabKey = _orderTabs[_tabController.index].key;
    final byTab =
        tabKey == 'all' ? _orders : _orders.where((o) => _getTabKey(o) == tabKey).toList();
    if (_searchQuery.isEmpty) return byTab;
    final term = _searchQuery.trim().toLowerCase();
    return byTab.where((o) => _orderMatchesSearch(o, term)).toList();
  }

  int _countForTab(String key) {
    if (key == 'all') return _orders.length;
    return _orders.where((o) => _getTabKey(o) == key).length;
  }

  void _updateOrder(int index, Order updated) {
    final filtered = _filteredOrders;
    if (index >= filtered.length) return;
    final orId = filtered[index].orId;
    final globalIndex = _orders.indexWhere((o) => o.orId == orId);
    if (globalIndex != -1) {
      setState(() => _orders[globalIndex] = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('การซื้อของฉัน'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: _loading
              ? const SizedBox.shrink()
              : TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: colorScheme.primary,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  dividerColor: colorScheme.outlineVariant,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: _orderTabs.map((tab) {
                    final count = _countForTab(tab.key);
                    return Tab(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tab.label),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _tabController.index ==
                                      _orderTabs.indexOf(tab)
                                  ? colorScheme.primary.withValues(alpha: 0.15)
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _tabController.index ==
                                        _orderTabs.indexOf(tab)
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : Column(
                    children: [
                      _buildSummary(),
                      _buildSearchBar(),
                      Expanded(
                        child: _orders.isEmpty
                            ? _buildEmptyAll()
                            : _buildTabContent(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummary() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.receipt_long_outlined,
                  label: 'ทั้งหมด',
                  value: '${_orders.length}',
                  color: colorScheme.primary,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: colorScheme.outlineVariant,
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.local_shipping_outlined,
                  label: 'กำลังดำเนินการ',
                  value: '$_activeOrdersCount',
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SearchBar(
        controller: _searchController,
        hintText: 'ค้นหาเลขคำสั่งซื้อ สินค้า ร้านค้า...',
        leading: Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 20),
        trailing: _searchQuery.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ]
            : null,
        onChanged: (value) => setState(() => _searchQuery = value),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 14, color: colorScheme.onSurface),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final filtered = _filteredOrders;
    final isSearching = _searchQuery.trim().isNotEmpty;

    if (filtered.isEmpty && isSearching) {
      return _buildEmptySearch(_searchQuery.trim());
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'ไม่มีรายการในหมวดนี้',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'ลองเลือกหมวดอื่นเพื่อดูคำสั่งซื้อของคุณ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _tabController.animateTo(0),
                child: const Text('ดูรายการทั้งหมด'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = filtered[index];
          return _OrderCard(
            order: order,
            index: index + 1,
            onTap: () => _openDetail(context, index, order),
          );
        },
      ),
    );
  }

  Widget _buildEmptySearch(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'ไม่พบคำสั่งซื้อที่ตรงกับ "$query"',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'ลองค้นหาด้วยเลขคำสั่งซื้อ ชื่อสินค้า หรือชื่อร้านค้า',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('ล้างคำค้นหา'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    int index,
    Order order,
  ) async {
    final updated = await Navigator.of(context).push<Order>(
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(order: order, api: _api),
      ),
    );
    if (updated != null) {
      _updateOrder(index, updated);
    }
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 40),
            const SizedBox(height: 12),
            const Text('โหลดคำสั่งซื้อไม่สำเร็จ'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadOrders,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAll() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีคำสั่งซื้อ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'คำสั่งซื้อของคุณจะปรากฏที่นี่',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.index,
    required this.onTap,
  });

  final Order order;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = getOrderStatusColor(order);
    final statusBg = getOrderStatusBgColor(order);
    final statusLabel = getOrderStatusLabel(order);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // สีขีดบนสุดตามสถานะ
            Container(height: 4, color: statusColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (order.orderNo != null)
                              Text(
                                order.orderNo!,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(order.createdAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${order.itemCount} รายการ',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatPrice(order.grandTotal),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  // Preview items ที่มีมาจาก list API
                  if (order.items != null && order.items!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...order.items!.take(2).map((item) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.fiber_manual_record,
                                size: 6,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${item.productName}${item.variantName != null ? ' (${item.variantName})' : ''} x${item.qty}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        )),
                    if ((order.items?.length ?? 0) > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          '+${order.items!.length - 2} รายการเพิ่มเติม',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
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
