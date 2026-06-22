class StorefrontCategory {
  const StorefrontCategory({
    required this.id,
    required this.name,
    required this.catalogId,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int catalogId;
  final int sortOrder;

  factory StorefrontCategory.fromJson(Map<String, dynamic> json) {
    return StorefrontCategory(
      id: _asInt(json['c_id']),
      name: (json['cl_name'] ?? '').toString(),
      catalogId: _asInt(json['ctl_id']),
      sortOrder: _asInt(json['c_sort_order']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
