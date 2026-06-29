import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'package:arcana_online_shop_mobile/config/app_config.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import 'package:arcana_online_shop_mobile/features/notifications/data/buyer_notification_api.dart';
import 'package:arcana_online_shop_mobile/features/notifications/domain/buyer_notification.dart';

class BuyerNotificationController extends ChangeNotifier {
  BuyerNotificationController({BuyerNotificationApi? api})
    : _api = api ?? BuyerNotificationApi();

  final BuyerNotificationApi _api;

  socket_io.Socket? _socket;
  int? _connectedUserId;

  List<BuyerNotification> _items = const [];
  bool _loading = false;
  Object? _error;

  List<BuyerNotification> get items => _items;
  bool get loading => _loading;
  Object? get error => _error;
  int get unreadCount => _items.where((item) => !item.isRead).length;

  Future<void> syncWithSession() async {
    final userId = AuthSession.instance.user?.id;
    if (!AuthSession.instance.isLoggedIn || userId == null || userId <= 0) {
      _disconnect();
      _items = const [];
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }

    if (_connectedUserId == userId && _socket != null) return;

    _disconnect();
    _connectedUserId = userId;
    await reload();
    _connectSocket(userId);
  }

  Future<void> reload() async {
    if (!AuthSession.instance.isLoggedIn) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _api.list();
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(BuyerNotification notification) async {
    final id = notification.id;
    if (id == null || notification.isRead) return;

    _items = _items
        .map(
          (item) => item.id == id
              ? item.copyWith(isRead: true, readAt: DateTime.now())
              : item,
        )
        .toList();
    notifyListeners();

    try {
      await _api.markAsRead(id);
    } catch (_) {
      await reload();
    }
  }

  Future<void> markAllAsRead() async {
    if (_items.every((item) => item.isRead)) return;

    final now = DateTime.now();
    _items = _items
        .map((item) => item.copyWith(isRead: true, readAt: item.readAt ?? now))
        .toList();
    notifyListeners();

    try {
      await _api.markAllAsRead();
    } catch (_) {
      await reload();
    }
  }

  void _connectSocket(int userId) {
    final apiUrl = AppConfig.apiBaseUrl;
    if (apiUrl.isEmpty) return;

    final uri = Uri.tryParse(apiUrl);
    if (uri == null || !uri.hasScheme) return;

    final origin = uri.replace(path: '', query: '', fragment: '').toString();
    final socket = socket_io.io(
      origin,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .build(),
    );

    socket.onConnect((_) => socket.emit('join_user', userId));
    socket.on('notification:new', _handleNewNotification);
    socket.on('order:changed', (_) => reload());
    socket.connect();

    _socket = socket;
  }

  void _handleNewNotification(dynamic payload) {
    if (payload is! Map) return;

    final notification = BuyerNotification.fromJson(
      Map<String, dynamic>.from(payload),
    );
    _items = [
      notification,
      ..._items.where((item) => item.id != notification.id),
    ];
    notifyListeners();
  }

  void _disconnect() {
    _socket
      ?..off('notification:new')
      ..off('order:changed')
      ..dispose();
    _socket = null;
    _connectedUserId = null;
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
