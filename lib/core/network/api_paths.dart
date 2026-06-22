class ApiPaths {
  const ApiPaths._();

  static String categoriesByLanguage(String languageCode) =>
      '/categorys/lgcode/$languageCode';

  static String productShop(String languageCode) => '/productShop/$languageCode';

  static String productById(String languageCode, int productId) =>
      '/productShop/$languageCode/$productId';

  static const String reviews = '/reviews';
}
