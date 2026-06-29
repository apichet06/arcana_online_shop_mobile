import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import 'package:arcana_online_shop_mobile/features/auth/presentation/login_page.dart';
import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/notifications/application/buyer_notification_controller.dart';
import 'package:arcana_online_shop_mobile/features/notifications/domain/buyer_notification.dart';
import 'package:arcana_online_shop_mobile/features/orders/data/orders_api.dart';
import 'package:arcana_online_shop_mobile/features/orders/presentation/order_detail_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.controller});

  final BuyerNotificationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AuthSession.instance, controller]),
      builder: (context, _) {
        if (!AuthSession.instance.isLoggedIn) {
          return _LoginPrompt(onLoginPressed: () => _openLogin(context));
        }

        if (controller.loading && controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error != null && controller.items.isEmpty) {
          return _NotificationError(onRetry: controller.reload);
        }

        if (controller.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                _EmptyNotifications(),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: controller.items.length + 1,
            separatorBuilder: (_, index) {
              if (index == 0) return const SizedBox(height: 8);
              return const SizedBox(height: 10);
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return _NotificationHeader(
                  unreadCount: controller.unreadCount,
                  onMarkAllRead: controller.unreadCount == 0
                      ? null
                      : controller.markAllAsRead,
                );
              }

              final notification = controller.items[index - 1];
              return _NotificationTile(
                notification: notification,
                actionable: _notificationOrderId(notification) != null,
                onTap: () => _openNotification(context, notification),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
    await controller.syncWithSession();
  }

  Future<void> _openNotification(
    BuildContext context,
    BuyerNotification notification,
  ) async {
    await controller.markAsRead(notification);

    final orderId = _notificationOrderId(notification);
    if (orderId == null) return;

    final api = OrdersApi(client: ApiClient());
    try {
      final order = await api.fetchOrderDetail(orderId, 'th');
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(order: order, api: api),
        ),
      );
      await controller.reload();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดรายละเอียดคำสั่งซื้อไม่สำเร็จ')),
      );
    }
  }

  int? _notificationOrderId(BuyerNotification notification) {
    if (notification.refType?.toUpperCase() == 'ORDER' &&
        notification.refId != null) {
      return notification.refId;
    }

    final actionUrl = notification.actionUrl;
    if (actionUrl == null) return null;

    final uri = Uri.tryParse(actionUrl);
    final orderId = uri?.queryParameters['order_id'];
    final parsedOrderId = int.tryParse(orderId ?? '');
    if (parsedOrderId != null) return parsedOrderId;

    final match = RegExp(r'order_id=(\d+)').firstMatch(actionUrl);
    return int.tryParse(match?.group(1) ?? '');
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'การแจ้งเตือน',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        TextButton.icon(
          onPressed: onMarkAllRead,
          icon: const Icon(Icons.done_all),
          label: Text(unreadCount == 0 ? 'อ่านครบแล้ว' : 'อ่านทั้งหมด'),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.actionable,
    required this.onTap,
  });

  final BuyerNotification notification;
  final bool actionable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final read = notification.isRead;

    return Card(
      color: read ? null : colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: read
              ? colorScheme.surfaceContainerHighest
              : colorScheme.primary,
          child: Icon(
            read ? Icons.notifications_none : Icons.notifications_active,
            color: read ? colorScheme.onSurfaceVariant : colorScheme.onPrimary,
          ),
        ),
        title: Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: read ? FontWeight.w600 : FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                _formatTime(notification.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: actionable ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    return DateFormat('d MMM yyyy HH:mm').format(value.toLocal());
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีการแจ้งเตือน',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              'โหลดการแจ้งเตือนไม่สำเร็จ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'การแจ้งเตือน',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'เข้าสู่ระบบเพื่อดูสถานะคำสั่งซื้อและข้อความแจ้งเตือนของคุณ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLoginPressed,
              icon: const Icon(Icons.login),
              label: const Text('เข้าสู่ระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}
