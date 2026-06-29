import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:arcana_online_shop_mobile/config/app_config.dart';
import 'package:arcana_online_shop_mobile/features/auth/data/auth_session.dart';
import 'package:arcana_online_shop_mobile/features/auth/presentation/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _googleScopes = ['email', 'profile'];
  static Future<void>? _googleInitialization;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await AuthSession.instance.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _completeLogin();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFromError(error);
        _submitting = false;
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await _ensureGoogleInitialized();

      final signIn = GoogleSignIn.instance;
      if (!signIn.supportsAuthenticate()) {
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.uiUnavailable,
          description: 'อุปกรณ์นี้ไม่รองรับ Google Sign-In',
        );
      }

      final account = await signIn.authenticate(scopeHint: _googleScopes);
      final authorization =
          await account.authorizationClient.authorizationForScopes(
            _googleScopes,
          ) ??
          await account.authorizationClient.authorizeScopes(_googleScopes);

      await AuthSession.instance.loginWithGoogleAccessToken(
        authorization.accessToken,
      );
      _completeLogin();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFromError(error);
        _submitting = false;
      });
    }
  }

  Future<void> _loginWithFacebook() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
        loginTracking: LoginTracking.enabled,
      );

      switch (result.status) {
        case LoginStatus.success:
          final accessToken = result.accessToken?.tokenString;
          if (accessToken == null || accessToken.isEmpty) {
            throw Exception('ไม่พบ access token จาก Facebook');
          }

          await AuthSession.instance.loginWithFacebookAccessToken(accessToken);
          _completeLogin();
          return;
        case LoginStatus.cancelled:
          throw Exception('ยกเลิกการเข้าสู่ระบบด้วย Facebook');
        case LoginStatus.operationInProgress:
          throw Exception('กำลังเข้าสู่ระบบด้วย Facebook อยู่');
        case LoginStatus.failed:
          throw Exception(result.message ?? 'เข้าสู่ระบบด้วย Facebook ไม่สำเร็จ');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _messageFromError(error);
        _submitting = false;
      });
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    final serverClientId = AppConfig.googleServerClientId;
    if (serverClientId == null || serverClientId.isEmpty) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
        description: 'ไม่พบ GOOGLE_CLIENT_ID สำหรับ Google Sign-In',
      );
    }

    _googleInitialization ??= GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleClientId,
      serverClientId: serverClientId,
    );

    try {
      await _googleInitialization;
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
  }

  String _messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return error.message ?? 'เข้าสู่ระบบไม่สำเร็จ';
    }
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'ยกเลิกการเข้าสู่ระบบด้วย Google';
      }
      return error.description ?? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ';
    }
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isNotEmpty && message != 'null') return message;
    return 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เข้าสู่ระบบ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Center(
              child: ClipOval(
                child: Image.asset(
                  'assets/image/app_icon.jpg',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Welcome to Arcana',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'เข้าสู่ระบบเพื่อจัดการบัญชี คำสั่งซื้อ และที่อยู่จัดส่งของคุณ',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'อีเมล',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'กรุณากรอกอีเมล';
                      if (!email.contains('@')) return 'รูปแบบอีเมลไม่ถูกต้อง';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) {
                      if (!_submitting) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                      if (password.length < 6) {
                        return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                      }
                      return null;
                    },
                  ),
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
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text('เข้าสู่ระบบ'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _submitting ? null : _openRegister,
                    child: const Text('สมัครสมาชิก'),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _loginWithGoogle,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('เข้าสู่ระบบด้วย Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _loginWithFacebook,
                    icon: const Icon(Icons.facebook),
                    label: const Text('เข้าสู่ระบบด้วย Facebook'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRegister() async {
    final registered = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const RegisterPage()));
    if (!mounted) return;
    if (registered == true) _completeLogin();
  }

  void _completeLogin() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
