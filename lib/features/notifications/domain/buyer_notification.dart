class BuyerNotification {
  const BuyerNotification({
    required this.targetType,
    required this.targetId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.priority,
    required this.createdAt,
    this.id,
    this.actionUrl,
    this.refType,
    this.refId,
    this.readAt,
  });

  final int? id;
  final String targetType;
  final int targetId;
  final String type;
  final String title;
  final String message;
  final String? actionUrl;
  final String? refType;
  final int? refId;
  final bool isRead;
  final DateTime? readAt;
  final String priority;
  final DateTime? createdAt;

  factory BuyerNotification.fromJson(Map<String, dynamic> json) {
    return BuyerNotification(
      id: _asNullableInt(json['noti_id']),
      targetType: json['target_type']?.toString() ?? 'USER',
      targetId: _asInt(json['target_id']),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      actionUrl: _asNullableString(json['action_url']),
      refType: _asNullableString(json['ref_type']),
      refId: _asNullableInt(json['ref_id']),
      isRead: _asBool(json['is_read']),
      readAt: _asDate(json['read_at']),
      priority: json['priority']?.toString() ?? 'NORMAL',
      createdAt: _asDate(json['created_at']),
    );
  }

  BuyerNotification copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return BuyerNotification(
      id: id,
      targetType: targetType,
      targetId: targetId,
      type: type,
      title: title,
      message: message,
      actionUrl: actionUrl,
      refType: refType,
      refId: refId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      priority: priority,
      createdAt: createdAt,
    );
  }

  static String? _asNullableString(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  static int _asInt(Object? value) {
    return _asNullableInt(value) ?? 0;
  }

  static int? _asNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  static DateTime? _asDate(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }
}
