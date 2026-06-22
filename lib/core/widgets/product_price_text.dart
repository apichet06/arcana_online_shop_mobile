import 'package:flutter/material.dart';

class ProductPriceText extends StatelessWidget {
  const ProductPriceText({
    super.key,
    required this.minPrice,
    required this.maxPrice,
    required this.hasPriceRange,
  });

  final double minPrice;
  final double maxPrice;
  final bool hasPriceRange;

  @override
  Widget build(BuildContext context) {
    final price = hasPriceRange
        ? '${_format(minPrice)} - ${_format(maxPrice)}'
        : _format(minPrice);

    return Text(
      price,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _format(double value) {
    final rounded = value.round();
    final digits = rounded.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '฿$buffer';
  }
}
