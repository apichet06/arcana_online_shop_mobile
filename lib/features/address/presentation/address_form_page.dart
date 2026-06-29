import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:arcana_online_shop_mobile/core/widgets/location_picker_field.dart';
import 'package:arcana_online_shop_mobile/features/address/data/address_api.dart';
import 'package:arcana_online_shop_mobile/features/address/domain/address.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/address_lookup_api.dart';

// หน้าฟอร์มเพิ่ม/แก้ไขที่อยู่จัดส่ง
// ถ้า [existing] เป็น null = โหมดเพิ่ม, ถ้ามีค่า = โหมดแก้ไข
class AddressFormPage extends StatefulWidget {
  const AddressFormPage({
    super.key,
    required this.api,
    required this.existing,
  });

  final AddressApi api;
  final Address? existing;

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _lookupApi = AddressLookupApi();

  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _zipController = TextEditingController();

  // Location state — id และ name แยกกัน เพื่อแสดงชื่อบนปุ่ม และส่ง id ไป API
  int? _provinceId;
  String? _provinceName;
  int? _districtId;
  String? _districtName;
  int? _subdistrictId;
  String? _subdistrictName;
  bool _isDefault = false;

  List<LocationOption> _provinces = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _subdistricts = const [];

  bool _loadingProvinces = true;
  bool _loadingDistricts = false;
  bool _loadingSubdistricts = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _addressLineController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  // โหลด province list และถ้าเป็นโหมดแก้ไข ให้ pre-fill ฟอร์มและโหลด cascade ต่อ
  Future<void> _initForm() async {
    final existing = widget.existing;
    if (existing != null) {
      _recipientController.text = existing.recipientName;
      _phoneController.text = _formatPhone(existing.phone);
      _addressLineController.text = existing.addressLine;
      _zipController.text = existing.zipCode;
      _provinceId = existing.provincesId;
      _provinceName = existing.provinceName;
      _districtId = existing.districtsId;
      _districtName = existing.districtName;
      _subdistrictId = existing.subdistrictsId;
      _subdistrictName = existing.subdistrictName;
      _isDefault = existing.isDefault;
    }

    final provinces = await _lookupApi.getProvinces();
    if (!mounted) return;
    setState(() {
      _provinces = provinces;
      _loadingProvinces = false;
    });

    // ถ้า edit: โหลด district + subdistrict ต่อเลย
    if (existing != null) {
      await _loadDistricts(existing.provincesId);
      if (!mounted) return;
      await _loadSubdistricts(existing.districtsId);
    }
  }

  Future<void> _loadDistricts(int provinceId) async {
    setState(() => _loadingDistricts = true);
    final districts = await _lookupApi.getDistricts(provinceId);
    if (!mounted) return;
    setState(() {
      _districts = districts;
      _loadingDistricts = false;
    });
  }

  Future<void> _loadSubdistricts(int districtId) async {
    setState(() => _loadingSubdistricts = true);
    final subdistricts = await _lookupApi.getSubdistricts(districtId);
    if (!mounted) return;
    setState(() {
      _subdistricts = subdistricts;
      _loadingSubdistricts = false;
    });
  }

  // เลือกจังหวัด → reset district + subdistrict + zip
  void _onProvinceSelected(LocationOption option) {
    setState(() {
      _provinceId = option.id;
      _provinceName = option.name;
      _districtId = null;
      _districtName = null;
      _subdistrictId = null;
      _subdistrictName = null;
      _districts = const [];
      _subdistricts = const [];
      _zipController.clear();
    });
    _loadDistricts(option.id);
  }

  // เลือกอำเภอ → reset subdistrict + zip
  void _onDistrictSelected(LocationOption option) {
    setState(() {
      _districtId = option.id;
      _districtName = option.name;
      _subdistrictId = null;
      _subdistrictName = null;
      _subdistricts = const [];
      _zipController.clear();
    });
    _loadSubdistricts(option.id);
  }

  // เลือกตำบล → เติม zip อัตโนมัติ
  void _onSubdistrictSelected(LocationOption option) {
    setState(() {
      _subdistrictId = option.id;
      _subdistrictName = option.name;
      if (option.zipCode != null && option.zipCode!.isNotEmpty) {
        _zipController.text = option.zipCode!;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_provinceId == null || _districtId == null || _subdistrictId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกจังหวัด อำเภอ และตำบลให้ครบ')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final input = AddressInput(
        // เก็บเบอร์เฉพาะตัวเลข
        recipientName: _recipientController.text.trim(),
        phone: _normalizePhone(_phoneController.text),
        addressLine: _addressLineController.text.trim(),
        provincesId: _provinceId!,
        districtsId: _districtId!,
        subdistrictsId: _subdistrictId!,
        zipCode: _zipController.text.trim(),
        isDefault: _isDefault,
      );

      if (_isEditing) {
        await widget.api.updateAddress(widget.existing!.id, input);
      } else {
        await widget.api.addAddress(input);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 0812345678 → 081-234-5678
  String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  // 081-234-5678 → 0812345678
  String _normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'แก้ไขที่อยู่' : 'เพิ่มที่อยู่'),
      ),
      body: SafeArea(
        child: _loadingProvinces
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    // ชื่อผู้รับ
                    TextFormField(
                      controller: _recipientController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อผู้รับ',
                        hintText: 'ชื่อ-นามสกุล',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'กรุณากรอกชื่อผู้รับ' : null,
                    ),
                    const SizedBox(height: 14),

                    // เบอร์โทรศัพท์ — format XXX-XXX-XXXX ขณะพิมพ์
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 12, // 10 digits + 2 dashes
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                          null, // ซ่อน counter
                      inputFormatters: [_ThaiPhoneFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'เบอร์โทรศัพท์',
                        hintText: '081-234-5678',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        final digits = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                        if (digits.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
                        if (digits.length != 10) return 'เบอร์โทรต้องมี 10 หลัก';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ที่อยู่ (บ้านเลขที่ / ถนน / ซอย)
                    TextFormField(
                      controller: _addressLineController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'ที่อยู่',
                        hintText: 'บ้านเลขที่ / ถนน / ซอย',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'กรุณากรอกที่อยู่' : null,
                    ),
                    const SizedBox(height: 14),

                    // จังหวัด — เปิด bottom sheet ค้นหาได้
                    LocationPickerField(
                      label: 'จังหวัด',
                      selectedName: _provinceName,
                      options: _provinces,
                      loading: _loadingProvinces,
                      placeholder: 'เลือกจังหวัด',
                      searchHint: 'ค้นหาจังหวัด...',
                      onSelected: _onProvinceSelected,
                      validator: (_) => _provinceId == null ? 'กรุณาเลือกจังหวัด' : null,
                    ),
                    const SizedBox(height: 14),

                    // อำเภอ — enable เมื่อเลือกจังหวัดแล้ว
                    LocationPickerField(
                      label: 'อำเภอ / เขต',
                      selectedName: _districtName,
                      options: _districts,
                      loading: _loadingDistricts,
                      enabled: _provinceId != null,
                      placeholder: _provinceId == null ? 'เลือกจังหวัดก่อน' : 'เลือกอำเภอ',
                      searchHint: 'ค้นหาอำเภอ...',
                      onSelected: _onDistrictSelected,
                      validator: (_) => _districtId == null ? 'กรุณาเลือกอำเภอ' : null,
                    ),
                    const SizedBox(height: 14),

                    // ตำบล — enable เมื่อเลือกอำเภอแล้ว
                    LocationPickerField(
                      label: 'ตำบล / แขวง',
                      selectedName: _subdistrictName,
                      options: _subdistricts,
                      loading: _loadingSubdistricts,
                      enabled: _districtId != null,
                      placeholder: _districtId == null ? 'เลือกอำเภอก่อน' : 'เลือกตำบล',
                      searchHint: 'ค้นหาตำบล...',
                      onSelected: _onSubdistrictSelected,
                      validator: (_) =>
                          _subdistrictId == null ? 'กรุณาเลือกตำบล' : null,
                    ),
                    const SizedBox(height: 14),

                    // รหัสไปรษณีย์ — เติมอัตโนมัติจากตำบล แต่แก้มือได้
                    TextFormField(
                      controller: _zipController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 5,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                          null,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'รหัสไปรษณีย์',
                        hintText: '10110',
                        prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'กรุณากรอกรหัสไปรษณีย์';
                        if (val.length != 5) return 'รหัสไปรษณีย์ต้องมี 5 หลัก';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // ตั้งเป็นที่อยู่หลัก
                    SwitchListTile(
                      value: _isDefault,
                      // ที่อยู่หลักที่มีอยู่แล้วปิด toggle ไม่ได้ผ่าน UI นี้
                      onChanged: widget.existing?.isDefault == true
                          ? null
                          : (v) => setState(() => _isDefault = v),
                      title: const Text('ตั้งเป็นที่อยู่หลัก'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),

                    // ปุ่มบันทึก
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing ? 'บันทึกการแก้ไข' : 'บันทึกที่อยู่'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// Formatter แปลงตัวเลขเป็นรูปแบบ XXX-XXX-XXXX ขณะพิมพ์
class _ThaiPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
