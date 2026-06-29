import 'package:flutter/material.dart';

// Summary bar ด้านล่างหน้า CartPage
// แสดงจำนวน item ที่เลือก, ราคารวม, และปุ่มสั่งซื้อ
class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({
    super.key,
    required this.selectedCount,
    required this.selectedTotal,
    required this.onCheckout,
  });

  // จำนวน item ที่ is_selected = true
  final int selectedCount;
  // ราคารวมเฉพาะ item ที่เลือก
  final double selectedTotal;
  // null = ปุ่มสั่งซื้อ disabled (ไม่มี item เลือก)
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              // ซ้าย: จำนวนและราคารวมที่เลือก
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'เลือกแล้ว $selectedCount ชิ้น',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPrice(selectedTotal),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              // ขวา: ปุ่มสั่งซื้อ — disable เมื่อไม่มี item ที่เลือก
              FilledButton(
                onPressed: onCheckout,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 44),
                ),
                child: const Text(
                  'สั่งซื้อ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
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
