import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/address/data/address_api.dart';
import 'package:arcana_online_shop_mobile/features/address/domain/address.dart';
import 'package:arcana_online_shop_mobile/features/address/presentation/address_form_page.dart';

// จำนวนที่อยู่สูงสุดที่เพิ่มได้ ตรงกับที่ web กำหนด
const _maxAddresses = 3;

// หน้าแสดงรายการที่อยู่จัดส่ง — รองรับ add / edit / delete / set-default
class AddressPage extends StatefulWidget {
  const AddressPage({super.key});

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  late final AddressApi _api;

  List<Address> _addresses = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = AddressApi(client: ApiClient());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.fetchAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // เปิดหน้า form เพิ่มที่อยู่ใหม่ แล้ว reload list เมื่อกลับมา
  Future<void> _openAdd() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddressFormPage(api: _api, existing: null),
      ),
    );
    if (saved == true) _load();
  }

  // เปิดหน้า form แก้ไขที่อยู่ที่มีอยู่แล้ว
  Future<void> _openEdit(Address address) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddressFormPage(api: _api, existing: address),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _setDefault(int id) async {
    try {
      await _api.setDefault(id);
      _load();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  // ยืนยันก่อนลบ — ที่อยู่หลักลบไม่ได้ (ปิดปุ่มจาก UI แล้ว แต่กัน edge case)
  Future<void> _delete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบที่อยู่'),
        content: Text('ต้องการลบที่อยู่ของ "${address.recipientName}" ใช่ไหม?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'ลบ',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteAddress(address.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _addresses.length < _maxAddresses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ที่อยู่จัดส่ง'),
        actions: [
          if (!_loading && _error == null)
            TextButton.icon(
              onPressed: canAdd ? _openAdd : null,
              icon: const Icon(Icons.add),
              label: Text(
                'เพิ่ม (${_addresses.length}/$_maxAddresses)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _load)
                : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    if (_addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 12),
              const Text('ยังไม่มีที่อยู่จัดส่ง'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มที่อยู่'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _addresses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _AddressCard(
        address: _addresses[index],
        onEdit: () => _openEdit(_addresses[index]),
        onDelete: () => _delete(_addresses[index]),
        onSetDefault: () => _setDefault(_addresses[index].id),
      ),
    );
  }
}

// Card แสดงข้อมูลที่อยู่หนึ่งรายการ
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  // จัดรูปแบบเบอร์โทร 0812345678 → 081-234-5678
  String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        // ที่อยู่หลักมีขอบสี primary เพื่อแยกให้ชัด
        side: address.isDefault
            ? BorderSide(color: colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ชื่อผู้รับ + เบอร์ + badge ที่อยู่หลัก
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.recipientName,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'ที่อยู่หลัก',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPhone(address.phone),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                // ปุ่ม edit + delete
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'แก้ไข',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      // ที่อยู่หลักลบไม่ได้
                      onPressed: address.isDefault ? null : onDelete,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: address.isDefault
                          ? 'ไม่สามารถลบที่อยู่หลักได้'
                          : 'ลบ',
                      color: Theme.of(context).colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ที่อยู่
            Text(address.addressLine, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              '${address.subdistrictName} ${address.districtName} ${address.provinceName} ${address.zipCode}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            // ปุ่ม "ตั้งเป็นที่อยู่หลัก" — แสดงเฉพาะที่อยู่ที่ไม่ใช่ default
            if (!address.isDefault) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onSetDefault,
                child: Text(
                  'ตั้งเป็นที่อยู่หลัก',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
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
            const Text('โหลดข้อมูลไม่สำเร็จ'),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}
