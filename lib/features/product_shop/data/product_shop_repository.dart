import 'package:arcana_online_shop_mobile/features/product_shop/data/product_shop_api.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product_detail.dart';
import 'package:arcana_online_shop_mobile/features/product_shop/domain/product_review.dart';
import 'package:arcana_online_shop_mobile/features/storefront/domain/storefront_category.dart';
import 'package:arcana_online_shop_mobile/features/storefront/domain/storefront_type.dart';

class ProductShopRepository {
  ProductShopRepository({ProductShopApi? api}) : _api = api ?? ProductShopApi();

  final ProductShopApi _api;

  Future<StorefrontData> getStorefront({
    required StorefrontType type,
    String languageCode = 'th',
    int? categoryId,
    String keyword = '',
    String sort = 'all',
    int page = 1,
    int limit = 10,
  }) async {
    final catalogId = type.catalogId;
    final categoriesFuture = _api.getCategories(
      languageCode: languageCode,
      catalogId: catalogId,
    );
    final productsFuture = _api.getProducts(
      languageCode: languageCode,
      catalogId: catalogId,
      categoryId: categoryId,
      keyword: keyword,
      sort: sort,
      page: page,
      limit: limit,
    );

    return StorefrontData(
      categories: await categoriesFuture,
      productPage: await productsFuture,
    );
  }

  Future<ProductPage> getProducts({
    required StorefrontType type,
    required String languageCode,
    int? categoryId,
    String keyword = '',
    String sort = 'all',
    int page = 1,
    int limit = 10,
  }) {
    return _api.getProducts(
      languageCode: languageCode,
      catalogId: type.catalogId,
      categoryId: categoryId,
      keyword: keyword,
      sort: sort,
      page: page,
      limit: limit,
    );
  }

  Future<ProductDetailData> getProductById({
    required int productId,
    required String languageCode,
  }) {
    return _api.getProductById(
      languageCode: languageCode,
      productId: productId,
    );
  }

  Future<ProductReviewsData> getReviews({
    required int variantId,
    int page = 1,
    int limit = 5,
  }) {
    return _api.getReviews(
      variantId: variantId,
      page: page,
      limit: limit,
    );
  }

  Future<List<Product>> getRelatedProducts({
    required StorefrontType type,
    required String languageCode,
    required int categoryId,
    required int excludeProductId,
    int limit = 8,
  }) async {
    final page = await getProducts(
      type: type,
      languageCode: languageCode,
      categoryId: categoryId,
      page: 1,
      limit: limit,
    );

    return page.items
        .where((product) => product.id != excludeProductId)
        .toList();
  }

  String resolveAssetUrl(String? value) => _api.resolveAssetUrl(value);
}

class StorefrontData {
  const StorefrontData({required this.categories, required this.productPage});

  final List<StorefrontCategory> categories;
  final ProductPage productPage;
}
