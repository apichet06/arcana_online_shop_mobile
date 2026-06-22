import 'package:arcana_online_shop_mobile/core/network/api_client.dart';

class AddressLookupApi {
  AddressLookupApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<LocationOption>> getProvinces() async {
    final response = await _client.get('/address/province/');
    return _readOptions(response);
  }

  Future<List<LocationOption>> getDistricts(int provinceId) async {
    final response = await _client.get('/address/district/$provinceId');
    return _readOptions(response);
  }

  Future<List<LocationOption>> getSubdistricts(int districtId) async {
    final response = await _client.get('/address/subdistrict/$districtId');
    return _readOptions(response);
  }

  List<LocationOption> _readOptions(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(LocationOption.fromJson)
        .toList();
  }
}

class LocationOption {
  const LocationOption({
    required this.id,
    required this.name,
    this.zipCode,
  });

  final int id;
  final String name;
  final String? zipCode;

  factory LocationOption.fromJson(Map<String, dynamic> json) {
    return LocationOption(
      id: _asInt(json['id']),
      name: json['name_in_thai']?.toString() ?? '',
      zipCode: json['zip_code']?.toString(),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
