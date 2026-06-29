class Conversation {
  const Conversation({
    required this.convId,
    required this.status,
    required this.channel,
    this.subject,
    this.stId,
    this.storeName,
    this.storeEmail,
    this.storeImage,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final int convId;
  final String status;
  final String channel;
  final String? subject;
  final int? stId;
  final String? storeName;
  final String? storeEmail;
  final String? storeImage;
  final String? lastMessage;
  final String? lastMessageType;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName => storeName ?? subject ?? 'ร้านค้า #${stId ?? '-'}';

  Conversation copyWith({
    String? lastMessage,
    String? lastMessageType,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) =>
      Conversation(
        convId: convId,
        status: status,
        channel: channel,
        subject: subject,
        stId: stId,
        storeName: storeName,
        storeEmail: storeEmail,
        storeImage: storeImage,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageType: lastMessageType ?? this.lastMessageType,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        convId: (json['conv_id'] as num).toInt(),
        status: json['status'] as String,
        channel: json['channel'] as String,
        subject: json['subject'] as String?,
        stId: (json['st_id'] as num?)?.toInt(),
        storeName: json['store_name'] as String?,
        storeEmail: json['store_email'] as String?,
        storeImage: json['store_image'] as String?,
        lastMessage: json['last_message'] as String?,
        lastMessageType: json['last_message_type'] as String?,
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.tryParse(json['last_message_at'] as String)
            : null,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
