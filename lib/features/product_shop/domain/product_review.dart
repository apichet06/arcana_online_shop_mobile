class ProductReviewsData {
  const ProductReviewsData({
    required this.reviews,
    required this.summary,
    required this.total,
  });

  final List<ProductReview> reviews;
  final ProductReviewSummary summary;
  final int total;

  factory ProductReviewsData.fromJson(Map<String, dynamic> json) {
    final reviews = json['reviews'];
    return ProductReviewsData(
      reviews: reviews is List
          ? reviews
                .whereType<Map<String, dynamic>>()
                .map(ProductReview.fromJson)
                .toList()
          : const [],
      summary: ProductReviewSummary.fromJson(_asMap(json['summary'])),
      total: _asInt(json['total']),
    );
  }
}

class ProductReviewSummary {
  const ProductReviewSummary({
    required this.total,
    required this.avgProductScore,
    required this.avgDeliveryScore,
  });

  final int total;
  final double avgProductScore;
  final double avgDeliveryScore;

  factory ProductReviewSummary.fromJson(Map<String, dynamic> json) {
    return ProductReviewSummary(
      total: _asInt(json['total']),
      avgProductScore: _asDouble(json['avg_product_score']),
      avgDeliveryScore: _asDouble(json['avg_delivery_score']),
    );
  }
}

class ProductReview {
  const ProductReview({
    required this.id,
    required this.username,
    required this.message,
    required this.productScore,
    required this.deliveryScore,
    required this.createdAt,
    required this.images,
  });

  final int id;
  final String username;
  final String message;
  final int productScore;
  final int deliveryScore;
  final String createdAt;
  final List<String> images;

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    return ProductReview(
      id: _asInt(json['ed_id']),
      username: (json['u_username'] ?? '').toString(),
      message: (json['massages'] ?? '').toString(),
      productScore: _asInt(json['product_score']),
      deliveryScore: _asInt(json['delivery_score']),
      createdAt: (json['create_at'] ?? '').toString(),
      images: images is List ? images.map((value) => value.toString()).toList() : const [],
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  return const {};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
