import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:arcana_online_shop_mobile/features/auth/data/address_lookup_api.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _lookupApi = AddressLookupApi();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipCodeController = TextEditingController();

  List<LocationOption> _provinces = const [];
  List<LocationOption> _districts = const [];
  List<LocationOption> _subdistricts = const [];

  LocationOption? _selectedProvince;
  LocationOption? _selectedDistrict;
  LocationOption? _selectedSubdistrict;
  String _gender = '';
  DateTime? _birthday;
  bool _showPassword = false;
  bool _loadingLocations = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await _lookupApi.getProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _loadingLocations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'โหลดข้อมูลจังหวัดไม่สำเร็จ';
        _loadingLocations = false;
      });
    }
  }

  Future<void> _selectProvince(LocationOption? province) async {
    setState(() {
      _selectedProvince = province;
      _selectedDistrict = null;
      _selectedSubdistrict = null;
      _districts = const [];
      _subdistricts = const [];
      _zipCodeController.clear();
    });
    if (province == null) return;

    final districts = await _lookupApi.getDistricts(province.id);
    if (!mounted) return;
    setState(() => _districts = districts);
  }

  Future<void> _selectDistrict(LocationOption? district) async {
    setState(() {
      _selectedDistrict = district;
      _selectedSubdistrict = null;
      _subdistricts = const [];
      _zipCodeController.clear();
    });
    if (district == null) return;

    final subdistricts = await _lookupApi.getSubdistricts(district.id);
    if (!mounted) return;
    setState(() => _subdistricts = subdistricts);
  }

  void _selectSubdistrict(LocationOption? subdistrict) {
    setState(() {
      _selectedSubdistrict = subdistrict;
      _zipCodeController.text = subdistrict?.zipCode ?? '';
    });
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedSubdistrict == null) {
      setState(() => _errorMessage = 'กรุณาเลือกจังหวัด อำเภอ และตำบล');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final payload = {
      'u_username': _usernameController.text.trim(),
      'u_email': _emailController.text.trim(),
      'u_password': _passwordController.text,
      'u_birthday': _birthday == null ? null : _dateText(_birthday!),
      'u_gender': _gender.isEmpty ? null : _gender,
      'u_provider': 'LOCAL',
      'locb_recipient_name': _recipientController.text.trim(),
      'locb_phone': _phoneController.text.replaceAll(RegExp(r'\D'), ''),
      'locb_address': _addressController.text.trim(),
      'provinces_id': _selectedProvince!.id,
      'districts_id': _selectedDistrict!.id,
      'subdistricts_id': _selectedSubdistrict!.id,
      'zip_code': _zipCodeController.text.trim(),
      'is_default': true,
    };

    try {
      await AuthSession.instance.register(payload);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFromError(error);
        _submitting = false;
      });
    }
  }

  String _messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return error.message ?? 'สมัครสมาชิกไม่สำเร็จ';
    }
    return 'สมัครสมาชิกไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: SafeArea(
        child: _loadingLocations
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    Text(
                      'สร้างบัญชี Arcana',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'กรอกข้อมูลบัญชีและที่อยู่จัดส่งเริ่มต้น',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    _buildAccountFields(),
                    const SizedBox(height: 24),
                    _buildAddressFields(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('สมัครสมาชิก'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAccountFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ข้อมูลบัญชี', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้'),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 3) return 'ชื่อผู้ใช้ต้องมีอย่างน้อย 3 ตัวอักษร';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'อีเมล'),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'กรุณากรอกอีเมล';
            if (!email.contains('@')) return 'รูปแบบอีเมลไม่ถูกต้อง';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'รหัสผ่าน',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator: (value) {
            final text = value ?? '';
            if (text.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: !_showPassword,
          decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่าน'),
          validator: (value) {
            if (value != _passwordController.text) return 'รหัสผ่านไม่ตรงกัน';
            return null;
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickBirthday,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            _birthday == null
                ? 'วันเกิด (ไม่บังคับ)'
                : 'วันเกิด ${_dateText(_birthday!)}',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(labelText: 'เพศ (ไม่บังคับ)'),
          items: const [
            DropdownMenuItem(value: '', child: Text('ไม่ระบุ')),
            DropdownMenuItem(value: 'MALE', child: Text('ชาย')),
            DropdownMenuItem(value: 'FEMALE', child: Text('หญิง')),
            DropdownMenuItem(value: 'OTHER', child: Text('อื่น ๆ')),
          ],
          onChanged: (value) => setState(() => _gender = value ?? ''),
        ),
      ],
    );
  }

  Widget _buildAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ที่อยู่จัดส่ง', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          controller: _recipientController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'ชื่อผู้รับ'),
          validator: (value) {
            if ((value?.trim() ?? '').isEmpty) return 'กรุณากรอกชื่อผู้รับ';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
          validator: (value) {
            final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
            if (!RegExp(r'^0\d{9}$').hasMatch(digits)) {
              return 'กรุณากรอกเบอร์โทรศัพท์ 10 หลัก';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'ที่อยู่'),
          validator: (value) {
            if ((value?.trim() ?? '').isEmpty) return 'กรุณากรอกที่อยู่';
            return null;
          },
        ),
        const SizedBox(height: 12),
        _LocationDropdown(
          label: 'จังหวัด',
          value: _selectedProvince,
          options: _provinces,
          onChanged: _selectProvince,
        ),
        const SizedBox(height: 12),
        _LocationDropdown(
          label: 'อำเภอ/เขต',
          value: _selectedDistrict,
          options: _districts,
          onChanged: _selectedProvince == null ? null : _selectDistrict,
        ),
        const SizedBox(height: 12),
        _LocationDropdown(
          label: 'ตำบล/แขวง',
          value: _selectedSubdistrict,
          options: _subdistricts,
          onChanged: _selectedDistrict == null ? null : _selectSubdistrict,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _zipCodeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'รหัสไปรษณีย์'),
          validator: (value) {
            if ((value?.trim() ?? '').length != 5) {
              return 'รหัสไปรษณีย์ต้องมี 5 หลัก';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final LocationOption? value;
  final List<LocationOption> options;
  final ValueChanged<LocationOption?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<LocationOption>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option.name)),
      ],
      onChanged: onChanged,
    );
  }
}
