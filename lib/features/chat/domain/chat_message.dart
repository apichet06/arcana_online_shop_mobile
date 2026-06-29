class ChatMessage {
  const ChatMessage({
    required this.msgId,
    required this.convId,
    required this.senderType,
    this.senderId,
    this.senderName,
    required this.messageType,
    required this.body,
    required this.createdAt,
  });

  final int msgId;
  final int convId;
  final String senderType;
  final int? senderId;
  final String? senderName;
  final String messageType;
  final String body;
  final DateTime createdAt;

  bool get isUser => senderType == 'user';
  bool get isImage => messageType == 'image';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        msgId: (json['msg_id'] as num).toInt(),
        convId: (json['conv_id'] as num).toInt(),
        senderType: json['sender_type'] as String,
        senderId: (json['sender_id'] as num?)?.toInt(),
        senderName: json['sender_name'] as String?,
        messageType: json['message_type'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
