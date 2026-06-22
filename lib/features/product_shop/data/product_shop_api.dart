import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/core/network/api_paths.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product_detail.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product_review.dart';
import 'package:arcana_online_shop_mobile/features/storefront/domain/storefront_category.dart';

class ProductShopApi {
  ProductShopApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<StorefrontCategory>> getCategories({
    required String languageCode,
    required int catalogId,
  }) async {
    final response = await _client.get(
      ApiPaths.categoriesByLanguage(languageCode),
      queryParameters: {'ctl_id': catalogId.toString()},
    );

    final rows = response['data'];
    if (rows is! List) return const [];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(StorefrontCategory.fromJson)
        .toList();
  }

  Future<ProductPage> getProducts({
    required String languageCode,
    required int catalogId,
    int? categoryId,
    String keyword = '',
    String sort = 'all',
    int page = 1,
    int limit = 10,
  }) async {
    final trimmedKeyword = keyword.trim();
    final response = await _client.get(
      ApiPaths.productShop(languageCode),
      queryParameters: {
        'ctl_id': catalogId.toString(),
        'category': categoryId?.toString(),
        if (trimmedKeyword.isNotEmpty) 'keyword': trimmedKeyword,
        if (sort != 'all') 'sort': sort,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    final data = response['data'];
    final rows = data is Map<String, dynamic> ? data['items'] : data;
    final paginationJson = data is Map<String, dynamic>
        ? data['pagination']
        : null;
    final pagination = ProductPagination.fromJson(
      paginationJson is Map<String, dynamic> ? paginationJson : const {},
    );

    if (rows is! List) {
      return ProductPage(items: const [], pagination: pagination);
    }

    return ProductPage(
      items: rows
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList(),
      pagination: pagination,
    );
  }

  Future<ProductDetailData> getProductById({
    required String languageCode,
    required int productId,
  }) async {
    final response = await _client.get(
      ApiPaths.productById(languageCode, productId),
    );

    final data = response['data'];
    return ProductDetailData.fromJson(
      data is Map<String, dynamic> ? data : const {},
    );
  }

  Future<ProductReviewsData> getReviews({
    required int variantId,
    int page = 1,
    int limit = 5,
  }) async {
    final response = await _client.get(
      ApiPaths.reviews,
      queryParameters: {
        'pv_id': variantId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    final data = response['data'];
    return ProductReviewsData.fromJson(
      data is Map<String, dynamic> ? data : const {},
    );
  }

  String resolveAssetUrl(String? value) => _client.resolveAssetUrl(value);
}

class ProductPage {
  const ProductPage({required this.items, required this.pagination});

  final List<Product> items;
  final ProductPagination pagination;
}

class ProductPagination {
  const ProductPagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int limit;
  final int totalPages;

  factory ProductPagination.fromJson(Map<String, dynamic> json) {
    return ProductPagination(
      total: _asInt(json['total']),
      page: _asInt(json['page'], fallback: 1),
      limit: _asInt(json['limit'], fallback: 10),
      totalPages: _asInt(json['totalPages'], fallback: 1),
    );
  }

  bool get hasNextPage => page < totalPages;

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
