class ProductDetailData {
  const ProductDetailData({
    required this.product,
    required this.images,
    required this.variants,
  });

  final ProductDetail product;
  final List<ProductImage> images;
  final List<ProductVariant> variants;

  factory ProductDetailData.fromJson(Map<String, dynamic> json) {
    return ProductDetailData(
      product: ProductDetail.fromJson(_asMap(json['product'])),
      images: _asList(json['images']).map(ProductImage.fromJson).toList(),
      variants: _asList(json['variants']).map(ProductVariant.fromJson).toList(),
    );
  }
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.brandName,
    required this.categoryName,
    required this.categoryId,
    required this.catalogId,
    required this.storeName,
    required this.thumbnail,
    required this.minPrice,
    required this.maxPrice,
    required this.hasPriceRange,
  });

  final int id;
  final String name;
  final String title;
  final String description;
  final String brandName;
  final String categoryName;
  final int categoryId;
  final int catalogId;
  final String storeName;
  final String? thumbnail;
  final double minPrice;
  final double maxPrice;
  final bool hasPriceRange;

  String get displayName => name.isNotEmpty ? name : title;

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    return ProductDetail(
      id: _asInt(json['p_id']),
      name: (json['name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['p_description'] ?? '').toString(),
      brandName: (json['b_name'] ?? '').toString(),
      categoryName: (json['cl_name'] ?? '').toString(),
      categoryId: _asInt(json['c_id']),
      catalogId: _asInt(json['ctl_id']),
      storeName: (json['st_company_name'] ?? '').toString(),
      thumbnail: json['thumbnail']?.toString(),
      minPrice: _asDouble(json['min_price']),
      maxPrice: _asDouble(json['max_price']),
      hasPriceRange: _asInt(json['has_price_range']) == 1,
    );
  }
}

class ProductImage {
  const ProductImage({
    required this.id,
    required this.url,
    required this.isPrimary,
  });

  final int id;
  final String url;
  final bool isPrimary;

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: _asInt(json['ip_id']),
      url: (json['ip_image_url'] ?? '').toString(),
      isPrimary: _asInt(json['is_primary']) == 1,
    );
  }
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.sku,
    required this.price,
    required this.discount,
    required this.isDefault,
    required this.imageUrl,
    required this.availableQty,
    required this.label,
    required this.unitName,
  });

  final int id;
  final String sku;
  final double price;
  final double discount;
  final bool isDefault;
  final String? imageUrl;
  final int availableQty;
  final String label;
  final String? unitName;

  bool get isOutOfStock => availableQty <= 0;

  double get finalPrice {
    if (discount <= 0) return price;
    return price - (price * discount / 100);
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: _asInt(json['pv_id']),
      sku: (json['pv_sku'] ?? '').toString(),
      price: _asDouble(json['pv_price']),
      discount: _asDouble(json['discount']),
      isDefault: _asInt(json['is_default']) == 1,
      imageUrl: json['image_url']?.toString(),
      availableQty: _asInt(json['available_qty']),
      label: (json['variant_label'] ?? '').toString(),
      unitName: json['unit_name']?.toString(),
    );
  }
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
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
