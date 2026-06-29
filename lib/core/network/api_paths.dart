class ApiPaths {
  const ApiPaths._();

  static String categoriesByLanguage(String languageCode) =>
      '/categorys/lgcode/$languageCode';

  static String productShop(String languageCode) =>
      '/productShop/$languageCode';

  static String productById(String languageCode, int productId) =>
      '/productShop/$languageCode/$productId';

  static const String reviews = '/reviews';

  static const String myNotifications = '/notifications/me';

  static String markMyNotificationRead(int notificationId) =>
      '/notifications/me/$notificationId/read';

  static const String markAllMyNotificationsRead = '/notifications/me/read-all';

  static const String profile = '/auth/me';
  static const String changePassword = '/auth/me/password';

  static const String addresses = '/auth/me/addresses';
  static String addressById(int id) => '/auth/me/addresses/$id';
  static String addressSetDefault(int id) => '/auth/me/addresses/$id/default';

  static const String orders = '/orders';
  static String orderById(int id) => '/orders/$id';
  static String cancelOrder(int id) => '/orders/$id/cancel';
  static String refundRequest(int id) => '/orders/$id/refund-request';
  static String confirmOrderReceived(int id) => '/orders/$id/received';

  static const String chatConversations = '/chat/conversations';
  static String chatMessages(int convId) =>
      '/chat/conversations/$convId/messages';
  static String chatConversationRead(int convId) =>
      '/chat/conversations/$convId/read';

  // Cart endpoints — registered on server at /api/cart
  static const String cart = '/cart';
  static const String paymentMethods = '/payments/methods';
  static String paymentMethodSetDefault(int id) =>
      '/payments/methods/$id/default';
  static String paymentMethodById(int id) => '/payments/methods/$id';

  static const String cartItems = '/cart/items';
  static String cartItem(int ciId) => '/cart/items/$ciId';
  static String cartItemSelect(int ciId) => '/cart/items/$ciId/select';
}
