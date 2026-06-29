import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:arcana_online_shop_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:arcana_online_shop_mobile/core/network/api_client.dart';

class AddCardPage extends StatefulWidget {
  const AddCardPage({super.key});

  @override
  State<AddCardPage> createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = PaymentMethodsApi();

  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _makeDefault = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final expiry = _expiryCtrl.text.replaceAll(' ', '');
    final parts = expiry.split('/');
    final month = int.tryParse(parts[0]);
    final rawYear = int.tryParse(parts.length > 1 ? parts[1] : '');
    // รองรับทั้ง YY (2 หลัก) และ YYYY (4 หลัก)
    final year = rawYear != null && rawYear < 100 ? 2000 + rawYear : rawYear;

    if (month == null || year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('วันหมดอายุไม่ถูกต้อง')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final token = await _api.createOmiseToken(
        cardName: _nameCtrl.text.trim(),
        cardNumber: _numberCtrl.text,
        expirationMonth: month,
        expirationYear: year,
        securityCode: _cvvCtrl.text.trim(),
      );

      final method = await _api.addCard(
        omiseToken: token,
        makeDefault: _makeDefault,
      );

      if (!mounted) return;
      Navigator.of(context).pop(method);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มบัตรชำระเงิน')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'ชื่อบนบัตร',
                  hintText: 'ชื่อตามที่ปรากฎบนบัตร',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อบนบัตร' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _numberCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [_CardNumberFormatter()],
                decoration: const InputDecoration(
                  labelText: 'หมายเลขบัตร',
                  hintText: '1234 5678 9012 3456',
                  prefixIcon: Icon(Icons.credit_card_outlined),
                ),
                validator: (v) {
                  final digits = v?.replaceAll(' ', '') ?? '';
                  if (digits.isEmpty) return 'กรุณากรอกหมายเลขบัตร';
                  if (digits.length < 13 || digits.length > 19) {
                    return 'หมายเลขบัตรไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [_ExpiryFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'วันหมดอายุ',
                        hintText: 'MM/YY',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'กรุณากรอกวันหมดอายุ';
                        final parts = v.split('/');
                        if (parts.length != 2) return 'รูปแบบไม่ถูกต้อง';
                        final m = int.tryParse(parts[0]);
                        final y = int.tryParse(parts[1]);
                        if (m == null || m < 1 || m > 12) return 'เดือนไม่ถูกต้อง';
                        if (y == null) return 'ปีไม่ถูกต้อง';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '●●●',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'กรุณากรอก CVV';
                        if (v.length < 3) return 'CVV ไม่ถูกต้อง';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _makeDefault,
                onChanged: (v) => setState(() => _makeDefault = v ?? true),
                title: const Text('ตั้งเป็นบัตรหลัก'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Arcana ไม่เก็บเลขบัตรหรือ CVV ข้อมูลถูกส่งตรงไป Omise',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
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
                    : const Text('บันทึกบัตร'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// จัดรูปแบบเลขบัตรเป็น "XXXX XXXX XXXX XXXX"
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 19) return oldValue;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// จัดรูปแบบวันหมดอายุเป็น "MM/YY"
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) return oldValue;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
