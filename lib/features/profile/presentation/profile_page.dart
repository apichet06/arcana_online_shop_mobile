import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:arcana_online_shop_mobile/core/network/api_client.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import 'package:arcana_online_shop_mobile/features/profile/data/profile_api.dart';
import 'package:arcana_online_shop_mobile/features/profile/domain/profile_data.dart';

// หน้าแก้ไขข้อมูลส่วนตัว — โหลดจาก GET /auth/me และ save ด้วย PATCH /auth/me
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ใช้ client ตัวเดียวกันทั้ง API call และ resolveAssetUrl สำหรับ avatar
  late final ApiClient _client;
  late final ProfileApi _api;

  ProfileData? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // username ใช้ TextEditingController เพราะเป็น free-text input
  // birthday และ gender ใช้ state ตรงๆ เพราะเลือกจาก picker/dropdown
  final _usernameController = TextEditingController();
  String? _birthday; // ISO date เช่น "1999-12-31"
  String? _gender;   // 'MALE' | 'FEMALE' | 'OTHER' | null

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = ProfileApi(client: _client);
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // โหลดข้อมูลโปรไฟล์แล้วเติมลงฟอร์ม
  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _usernameController.text = profile.username;
        // ตัด timestamp ออกจาก birthday เหลือแค่ "yyyy-MM-dd"
        _birthday = profile.birthday?.length != null &&
                (profile.birthday?.length ?? 0) >= 10
            ? profile.birthday!.substring(0, 10)
            : profile.birthday;
        _gender = profile.gender;
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

  // บันทึกโปรไฟล์แล้ว sync username ไปยัง AuthSession ทันที
  // เพื่อให้ header และ account tab แสดงชื่อใหม่โดยไม่ต้องออกจากระบบ
  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _saving = true);
    try {
      final updated = await _api.updateProfile(
        username: username,
        birthday: _birthday,
        gender: _gender,
      );
      if (!mounted) return;

      // sync username ใน AuthSession เพื่อให้ header แสดงชื่อใหม่ทันที
      final current = AuthSession.instance.user;
      if (current != null) {
        AuthSession.instance.updateUsername(updated.username);
      }

      setState(() {
        _profile = updated;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
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

  // เปิด date picker สำหรับเลือกวันเกิด แล้วเก็บเป็น "yyyy-MM-dd"
  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = _birthday != null
        ? DateTime.tryParse(_birthday!) ?? DateTime(2000)
        : DateTime(2000);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('th'),
    );

    if (picked != null) {
      setState(() {
        _birthday =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลส่วนตัว')),
      body: SafeArea(
        // แสดง loading / error / ฟอร์มตาม state
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: _loadProfile)
                : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final profile = _profile;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        // ส่วนหัว: รูปโปรไฟล์ + ชื่อหัวข้อ + provider ที่ล็อกอินด้วย
        Row(
          children: [
            _AvatarCircle(
              // resolveAssetUrl แปลง relative path จาก API เป็น URL เต็ม
              avatarUrl: profile != null
                  ? _client.resolveAssetUrl(profile.avatar)
                  : null,
              username: profile?.username ?? '',
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อมูลส่วนตัว',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _loading
                        ? '...'
                        : 'ล็อกอินด้วย ${profile?.provider ?? ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ชื่อผู้ใช้ — แก้ไขได้
        TextFormField(
          controller: _usernameController,
          enabled: !_loading,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'ชื่อผู้ใช้',
            hintText: 'ชื่อผู้ใช้ของคุณ',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),

        // อีเมล — read-only เพราะผูกกับ provider ไม่สามารถเปลี่ยนได้
        TextFormField(
          initialValue: profile?.email ?? '',
          enabled: false,
          decoration: const InputDecoration(
            labelText: 'อีเมล',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 14),

        // วันเกิด — กดเพื่อเปิด date picker, ไม่บังคับ
        InkWell(
          onTap: _loading ? null : _pickBirthday,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'วันเกิด (ไม่บังคับ)',
              prefixIcon: Icon(Icons.cake_outlined),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            // เมื่อยังไม่ได้เลือก (isEmpty=true) label อยู่กลาง field
            // ถ้าส่ง Text ตอน isEmpty=true จะซ้อนกับ label
            isEmpty: _birthday == null,
            child: _birthday != null
                ? Text(_formatDate(_birthday!))
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 14),

        // เพศ — dropdown ไม่บังคับ, null = "ไม่ระบุ"
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(
            labelText: 'เพศ (ไม่บังคับ)',
            prefixIcon: Icon(Icons.wc_outlined),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('ไม่ระบุ')),
            DropdownMenuItem(value: 'MALE', child: Text('ชาย')),
            DropdownMenuItem(value: 'FEMALE', child: Text('หญิง')),
            DropdownMenuItem(value: 'OTHER', child: Text('อื่นๆ')),
          ],
          onChanged: _loading ? null : (value) => setState(() => _gender = value),
        ),
        const SizedBox(height: 32),

        // ปุ่มบันทึก — แสดง spinner ระหว่าง saving, disable เมื่อ loading/saving
        FilledButton(
          onPressed: (_saving || _loading) ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('บันทึกข้อมูล'),
        ),
      ],
    );
  }

  // แปลง ISO date เป็นรูปแบบภาษาไทย เช่น "1 มกราคม 2542"
  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('d MMMM yyyy', 'th').format(date);
    } catch (_) {
      return isoDate;
    }
  }
}

// วงกลมรูปโปรไฟล์ — แสดงรูปจาก network ถ้ามี, ไม่งั้นแสดงตัวอักษรแรกของชื่อ
class _AvatarCircle extends StatefulWidget {
  const _AvatarCircle({
    required this.avatarUrl,
    required this.username,
    required this.colorScheme,
  });

  final String? avatarUrl;
  final String username;
  final ColorScheme colorScheme;

  @override
  State<_AvatarCircle> createState() => _AvatarCircleState();
}

class _AvatarCircleState extends State<_AvatarCircle> {
  bool _imageError = false;

  // ตัวอักษรแรกของชื่อ ใช้แสดงแทนรูปเมื่อโหลดไม่ได้
  String get _initial {
    final trimmed = widget.username.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed.substring(0, 1).toUpperCase();
  }

  // ตรวจว่าควรแสดงรูปหรือไม่ — กรอง URL ที่เป็น placeholder จาก API
  bool get _showImage {
    if (_imageError) return false;
    final url = widget.avatarUrl;
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return !['system', 'default', 'null', 'undefined'].any(lower.contains);
  }

  @override
  void didUpdateWidget(covariant _AvatarCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // reset error เมื่อ URL เปลี่ยน เพื่อลองโหลดรูปใหม่
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      setState(() => _imageError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: widget.colorScheme.primaryContainer,
      child: _showImage
          ? ClipOval(
              child: Image.network(
                widget.avatarUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                // ถ้าโหลดรูปไม่ได้ ให้ตั้ง flag แล้ว rebuild เป็นตัวอักษรแทน
                errorBuilder: (_, __, ___) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _imageError = true);
                  });
                  return const SizedBox.shrink();
                },
              ),
            )
          : Text(
              _initial,
              style: TextStyle(
                color: widget.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
    );
  }
}

// แสดงเมื่อโหลดโปรไฟล์ไม่สำเร็จ พร้อมปุ่มลองใหม่
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
