class Product {
  const Product({
    required this.id,
    required this.name,
    required this.title,
    required this.imageUrl,
    required this.minPrice,
    required this.maxPrice,
    required this.discount,
    required this.categoryId,
    required this.catalogId,
    required this.brandName,
    required this.hasPriceRange,
    required this.isOutOfStock,
    required this.rating,
    required this.reviewCount,
  });

  final int id;
  final String name;
  final String title;
  final String? imageUrl;
  final double minPrice;
  final double maxPrice;
  final double discount;
  final int categoryId;
  final int catalogId;
  final String brandName;
  final bool hasPriceRange;
  final bool isOutOfStock;
  final double? rating;
  final int reviewCount;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _asInt(json['p_id']),
      name: (json['name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      imageUrl: json['ip_image_url']?.toString(),
      minPrice: _asDouble(json['min_price']),
      maxPrice: _asDouble(json['max_price']),
      discount: _asDouble(json['discount']),
      categoryId: _asInt(json['c_id']),
      catalogId: _asInt(json['ctl_id']),
      brandName: (json['b_name'] ?? '').toString(),
      hasPriceRange: _asInt(json['has_price_range']) == 1,
      isOutOfStock: _asInt(json['is_out_of_stock']) == 1,
      rating: _asNullableDouble(json['avg_rating'] ?? json['rating']),
      reviewCount: _asInt(json['review_count'] ?? json['reviewCount']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
