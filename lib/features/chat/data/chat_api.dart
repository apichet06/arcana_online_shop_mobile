import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/core/network/api_paths.dart';
import '../domain/chat_message.dart';
import '../domain/conversation.dart';

class ChatApi {
  ChatApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Conversation>> listConversations() async {
    final json = await _client.get(ApiPaths.chatConversations);
    final data = json['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(Conversation.fromJson).toList();
  }

  Future<Conversation> getOrCreateConversation({int? storeId}) async {
    final body = storeId != null
        ? <String, dynamic>{'st_id': storeId}
        : <String, dynamic>{};
    final json = await _client.post(ApiPaths.chatConversations, data: body);
    return Conversation.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getMessages(int convId) async {
    final json = await _client.get(ApiPaths.chatMessages(convId));
    final data = json['data'];
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  Future<void> markConversationRead(int convId) async {
    await _client.patch(ApiPaths.chatConversationRead(convId));
  }

  Future<ChatMessage> sendMessage(int convId, String body) async {
    final json = await _client.post(
      ApiPaths.chatMessages(convId),
      data: {'body': body, 'message_type': 'text'},
    );
    return ChatMessage.fromJson(json['data'] as Map<String, dynamic>);
  }
}
