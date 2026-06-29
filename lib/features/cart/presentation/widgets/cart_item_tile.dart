import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/features/cart/domain/cart_item.dart';

// Widget แสดง 1 รายการสินค้าในตะกร้า
// ประกอบด้วย: checkbox เลือก / รูป / ชื่อ+variant / ราคา / qty stepper / ปุ่มลบ
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.resolveImageUrl,
    required this.onSelectChanged,
    required this.onQtyDecrement,
    required this.onQtyIncrement,
    required this.onDelete,
    this.updatingQty = false,
    this.deleting = false,
  });

  final CartItem item;
  final String Function(String? url) resolveImageUrl;
  final ValueChanged<bool> onSelectChanged;
  final VoidCallback onQtyDecrement;
  final VoidCallback onQtyIncrement;
  final VoidCallback onDelete;
  // true = แสดง spinner ใน qty stepper ระหว่าง API call
  final bool updatingQty;
  // true = แสดง spinner ในปุ่มลบ ระหว่าง API call
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = resolveImageUrl(item.imageUrl);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox เลือก item สำหรับ checkout
            Checkbox(
              value: item.isSelected,
              onChanged: deleting ? null : (v) => onSelectChanged(v ?? false),
            ),
            // รูปสินค้า
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: const Color(0xFFF0EEE8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _ImageFallback(),
                        )
                      : const _ImageFallback(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ส่วนขวา: ชื่อสินค้า / variant / ราคา / qty stepper
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
                  // variant label เช่น "สี: แดง | ขนาด: L"
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
                  // ราคา: แสดง original ขีดฆ่าถ้ามี discount
                  Row(
                    children: [
                      Text(
                        _formatPrice(item.effectiveUnitPrice),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          _formatPrice(item.unitPrice),
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QtyStepper(
                        qty: item.qty,
                        loading: updatingQty,
                        // qty ต่ำสุดคือ 1 — ถ้าต้องการลบให้ใช้ปุ่มลบ
                        onDecrement: item.qty > 1 ? onQtyDecrement : null,
                        onIncrement: onQtyIncrement,
                      ),
                      const Spacer(),
                      // ปุ่มลบ item ออกจากตะกร้า
                      IconButton(
                        onPressed: deleting ? null : onDelete,
                        icon: deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.delete,
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Qty stepper widget: [−] qty [+]
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.loading,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int qty;
  final bool loading;
  // null = disable ปุ่ม − (qty = 1 แล้ว)
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.remove, onTap: loading ? null : onDecrement),
          SizedBox(
            width: 34,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '$qty',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          _StepButton(icon: Icons.add, onTap: loading ? null : onIncrement),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).disabledColor,
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 28,
        color: Color(0xFFBBB5A8),
      ),
    );
  }
}

String _formatPrice(double value) {
  final rounded = value.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return '฿$buffer';
}
