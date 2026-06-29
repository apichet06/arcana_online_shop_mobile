import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/core/network/api_paths.dart';
import 'package:arcana_online_shop_mobile/features/notifications/domain/buyer_notification.dart';

class BuyerNotificationApi {
  BuyerNotificationApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<BuyerNotification>> list() async {
    final response = await _client.get(ApiPaths.myNotifications);
    final rows = response['data'];
    if (rows is! List) return const [];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(BuyerNotification.fromJson)
        .toList();
  }

  Future<void> markAsRead(int notificationId) async {
    await _client.patch(ApiPaths.markMyNotificationRead(notificationId));
  }

  Future<void> markAllAsRead() async {
    await _client.patch(ApiPaths.markAllMyNotificationsRead);
  }
}
