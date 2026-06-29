import 'dart:async';

import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/cart/application/cart_controller.dart';
import 'package:arcana_online_shop_mobile/features/cart/presentation/widgets/cart_item_tile.dart';
import 'package:arcana_online_shop_mobile/features/cart/presentation/widgets/cart_summary_bar.dart';
import 'package:arcana_online_shop_mobile/features/checkout/presentation/checkout_page.dart';

// หน้าตะกร้าสินค้า — แสดง item ทั้งหมดในตะกร้า
// รองรับ: เลือก/ยกเลิกเลือก, แก้จำนวน, ลบ, pull-to-refresh
class CartPage extends StatefulWidget {
  const CartPage({super.key, this.lgCode = 'th'});

  // lgCode ใช้ fetch ชื่อสินค้าตามภาษาที่แสดงอยู่
  final String lgCode;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartController _controller = CartController.instance;
  // ApiClient สำหรับ resolve URL รูปภาพจาก relative path
  final ApiClient _apiClient = ApiClient();

  // ติดตาม ci_id ที่กำลัง update qty อยู่ — disable stepper ชั่วคราว
  final Set<int> _updatingCiIds = {};
  // ติดตาม ci_id ที่กำลัง delete — disable controls ชั่วคราว
  final Set<int> _deletingCiIds = {};

  @override
  void initState() {
    super.initState();
    // โหลด cart ใหม่ทุกครั้งที่เปิดหน้า เพื่อให้ข้อมูลล่าสุดเสมอ
    unawaited(_controller.refresh(lgCode: widget.lgCode));
  }

  Future<void> _handleDelete(int ciId) async {
    setState(() => _deletingCiIds.add(ciId));
    try {
      await _controller.removeItem(ciId: ciId);
    } finally {
      if (mounted) setState(() => _deletingCiIds.remove(ciId));
    }
  }

  Future<void> _handleQtyDecrement(int ciId, int currentQty) async {
    if (currentQty <= 1) return;
    setState(() => _updatingCiIds.add(ciId));
    try {
      await _controller.updateQty(
        ciId: ciId,
        qty: currentQty - 1,
        lgCode: widget.lgCode,
      );
    } catch (_) {
      // silent — stepper จะ re-enable เมื่อ finally รัน
    } finally {
      if (mounted) setState(() => _updatingCiIds.remove(ciId));
    }
  }

  Future<void> _handleQtyIncrement(int ciId, int currentQty) async {
    setState(() => _updatingCiIds.add(ciId));
    try {
      await _controller.updateQty(
        ciId: ciId,
        qty: currentQty + 1,
        lgCode: widget.lgCode,
      );
    } catch (_) {
      // silent
    } finally {
      if (mounted) setState(() => _updatingCiIds.remove(ciId));
    }
  }

  Future<void> _handleSelectChanged(int ciId, bool isSelected) async {
    await _controller.toggleSelect(ciId: ciId, isSelected: isSelected);
  }

  // toggle เลือกทั้งหมด / ยกเลิกทั้งหมด
  // ถ้า allSelected → deselect all, ถ้าไม่ → select all
  Future<void> _handleSelectAll() async {
    final shouldSelectAll = !_controller.cart.allSelected;
    await _controller.selectAll(
      selected: shouldSelectAll,
      lgCode: widget.lgCode,
    );
  }

  void _handleCheckout() {
    final selectedItems =
        _controller.cart.items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          selectedCiIds: selectedItems.map((i) => i.ciId).toList(),
          selectedTotal: _controller.cart.selectedTotal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // AppBar title แสดงจำนวน item ใน cart แบบ realtime
        title: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final count = _controller.itemCount;
            return Text(count > 0 ? 'ตะกร้าสินค้า ($count)' : 'ตะกร้าสินค้า');
          },
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // แสดง spinner เฉพาะโหลดครั้งแรกที่ยังไม่มี items
          if (_controller.loading && _controller.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.items.isEmpty) {
            return const _EmptyCart();
          }

          return RefreshIndicator(
            onRefresh: () => _controller.refresh(lgCode: widget.lgCode),
            child: ListView.builder(
              // padding ด้านล่างเผื่อ summary bar ไม่บัง item สุดท้าย
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
              // +1 สำหรับ header row "เลือกทั้งหมด"
              itemCount: _controller.items.length + 1,
              itemBuilder: (context, index) {
                // index 0 = header "เลือกทั้งหมด"
                if (index == 0) {
                  return _SelectAllRow(
                    allSelected: _controller.cart.allSelected,
                    someSelected: _controller.cart.someSelected,
                    totalCount: _controller.items.length,
                    onToggle: _handleSelectAll,
                  );
                }
                final item = _controller.items[index - 1];
                return CartItemTile(
                  item: item,
                  resolveImageUrl: _apiClient.resolveAssetUrl,
                  onSelectChanged: (v) => _handleSelectChanged(item.ciId, v),
                  onQtyDecrement: () =>
                      _handleQtyDecrement(item.ciId, item.qty),
                  onQtyIncrement: () =>
                      _handleQtyIncrement(item.ciId, item.qty),
                  onDelete: () => _handleDelete(item.ciId),
                  updatingQty: _updatingCiIds.contains(item.ciId),
                  deleting: _deletingCiIds.contains(item.ciId),
                );
              },
            ),
          );
        },
      ),
      // Summary bar อยู่ด้านล่างเสมอ rebuild เมื่อ selected items เปลี่ยน
      bottomNavigationBar: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CartSummaryBar(
            selectedCount: _controller.cart.selectedCount,
            selectedTotal: _controller.cart.selectedTotal,
            onCheckout: _controller.cart.selectedCount > 0
                ? _handleCheckout
                : null,
          );
        },
      ),
    );
  }
}

// Header row "เลือกทั้งหมด" ที่ด้านบน ListView
// ใช้ tristate Checkbox: true = all, null = some, false = none
class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({
    required this.allSelected,
    required this.someSelected,
    required this.totalCount,
    required this.onToggle,
  });

  final bool allSelected;
  final bool someSelected;
  final int totalCount;
  // callback เมื่อกด — CartPage จัดการ toggle all selected
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // tristate: true = ทุกอัน, null = บางอัน (indeterminate), false = ไม่มี
    final checkValue = allSelected ? true : (someSelected ? null : false);

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              tristate: true,
              value: checkValue,
              onChanged: (_) => onToggle(),
            ),
            Text(
              'เลือกทั้งหมด ($totalCount)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Empty state เมื่อตะกร้าว่าง
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'ตะกร้าสินค้าว่างเปล่า',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'เพิ่มสินค้าที่ต้องการแล้วกลับมาที่นี่',
              textAlign: TextAlign.center,
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
