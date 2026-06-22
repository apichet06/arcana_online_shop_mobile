import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/core/widgets/product_price_text.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.imageUrl,
    this.onTap,
  });

  final Product product;
  final String imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF0EEE8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _ImageFallback(),
                      )
                    else
                      const _ImageFallback(),
                    if (product.isOutOfStock)
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name.isNotEmpty ? product.name : product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ProductRating(
                    rating: product.rating,
                    reviewCount: product.reviewCount,
                  ),
                  const SizedBox(height: 8),
                  ProductPriceText(
                    minPrice: product.minPrice,
                    maxPrice: product.maxPrice,
                    hasPriceRange: product.hasPriceRange,
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

class _ProductRating extends StatelessWidget {
  const _ProductRating({
    required this.rating,
    required this.reviewCount,
  });

  final double? rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final value = rating ?? 0;
    final filledStars = value.floor().clamp(0, 5);

    return Row(
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            Icons.star,
            size: 13,
            color: star <= filledStars
                ? const Color(0xFFF59E0B)
                : const Color(0xFFE2E8F0),
          ),
        const SizedBox(width: 6),
        Text(
          value.toStringAsFixed(1),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($reviewCount)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.shopping_bag_outlined, size: 42),
    );
  }
}
