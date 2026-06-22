class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
  });

  final int id;
  final String username;
  final String email;
  final String? avatar;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: _asInt(json['u_id']),
      username: json['u_username']?.toString() ?? '',
      email: json['u_email']?.toString() ?? '',
      avatar: json['u_avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'u_id': id,
      'u_username': username,
      'u_email': email,
      'u_avatar': avatar,
    };
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
