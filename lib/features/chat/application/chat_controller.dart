import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'package:arcana_online_shop_mobile/config/app_config.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import '../data/chat_api.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';

class ChatController extends ChangeNotifier {
  ChatController({ChatApi? api}) : _api = api ?? ChatApi();

  final ChatApi _api;
  socket_io.Socket? _socket;
  int? _connectedUserId;

  List<Conversation> _conversations = const [];
  bool _loading = false;
  Object? _error;

  int? _activeConvId;
  void Function(ChatMessage)? _onActiveConvMessage;

  List<Conversation> get conversations => _conversations;
  bool get loading => _loading;
  Object? get error => _error;
  int get totalUnreadCount =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  Future<void> syncWithSession() async {
    final userId = AuthSession.instance.user?.id;
    if (!AuthSession.instance.isLoggedIn || userId == null || userId <= 0) {
      _disconnect();
      _conversations = const [];
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
      _conversations = await _api.listConversations();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Called by ConversationMessagesPage when it opens/closes a conversation.
  void setActiveConversation(int? convId, void Function(ChatMessage)? onMessage) {
    _activeConvId = convId;
    _onActiveConvMessage = onMessage;
    if (convId != null) {
      _emitJoinConversation(convId);
    }
  }

  // Called after the user sends a message via HTTP to update the conv list preview.
  void onMessageSent(ChatMessage msg) {
    _applyMessageToConvList(msg, resetUnread: true);
  }

  void updateConversationRead(int convId) {
    _conversations = _conversations
        .map((c) => c.convId == convId ? c.copyWith(unreadCount: 0) : c)
        .toList();
    notifyListeners();
  }

  void _emitJoinConversation(int convId) {
    final socket = _socket;
    if (socket == null) return;
    socket.emit('join_conversation', {
      'conv_id': convId,
      'token': AuthSession.instance.accessToken,
    });
  }

  void _applyMessageToConvList(ChatMessage msg, {required bool resetUnread}) {
    _conversations = _conversations.map((c) {
      if (c.convId != msg.convId) return c;
      return c.copyWith(
        lastMessage: msg.body,
        lastMessageType: msg.messageType,
        lastMessageAt: msg.createdAt,
        unreadCount: resetUnread ? 0 : c.unreadCount + 1,
      );
    }).toList();
    notifyListeners();
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

    socket.onConnect((_) {
      socket.emit('join_user', userId);
      if (_activeConvId != null) {
        _emitJoinConversation(_activeConvId!);
      }
    });

    // Fires for all convs involving this user (from user room).
    socket.on('chat:new_message', _handleUserRoomMessage);
    // Fires for the active conv room.
    socket.on('new_message', _handleConvRoomMessage);
    socket.connect();

    _socket = socket;
  }

  // Payload: { conv_id: number, message: ChatMessage }
  void _handleUserRoomMessage(dynamic payload) {
    if (payload is! Map) return;
    final msgData = payload['message'];
    if (msgData is! Map) return;

    final message = ChatMessage.fromJson(Map<String, dynamic>.from(msgData));

    if (message.convId == _activeConvId) {
      _onActiveConvMessage?.call(message);
      _applyMessageToConvList(message, resetUnread: true);
    } else {
      final exists = _conversations.any((c) => c.convId == message.convId);
      if (!exists) {
        reload();
        return;
      }
      _applyMessageToConvList(message, resetUnread: false);
    }
  }

  // Payload: ChatMessage directly (from conversation room).
  void _handleConvRoomMessage(dynamic payload) {
    if (payload is! Map) return;
    final message = ChatMessage.fromJson(Map<String, dynamic>.from(payload));
    if (message.convId != _activeConvId) return;

    _onActiveConvMessage?.call(message);
    _applyMessageToConvList(message, resetUnread: true);
  }

  void _disconnect() {
    _socket
      ?..off('chat:new_message')
      ..off('new_message')
      ..dispose();
    _socket = null;
    _connectedUserId = null;
    _activeConvId = null;
    _onActiveConvMessage = null;
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
