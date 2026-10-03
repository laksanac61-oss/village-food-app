import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    String? error;
    if (_register && _name.text.trim().isEmpty) error = 'กรุณากรอกชื่อ';
    if (_register && _login.text.contains('@')) error = 'กรุณากรอกเบอร์โทร';
    if (_register && _password.text.length < 6) error = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัว';
    if (error == null) {
      setState(() => _busy = true);
      try {
        if (_register) {
          await Api.signUp(_login.text, _password.text, _name.text.trim());
        } else {
          await Api.signIn(_login.text, _password.text);
        }
      } on FormatException catch (e) {
        error = e.message;
      } on AuthException catch (e) {
        error = _authError(e.message);
      } catch (e) {
        error = 'เกิดข้อผิดพลาด: $e';
      }
      if (mounted) setState(() => _busy = false);
    }
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  String _authError(String message) {
    final m = message.toLowerCase();
    if (m.contains('invalid login')) return 'เบอร์โทรหรือรหัสผ่านไม่ถูกต้อง';
    if (m.contains('already registered')) return 'เบอร์นี้สมัครไว้แล้ว กรุณาเข้าสู่ระบบ';
    if (m.contains('password')) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัว';
    return 'เกิดข้อผิดพลาด: $message';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/logo.png', height: 200, semanticLabel: 'ส่งอาหารบ้านดุง'),
                const SizedBox(height: 24),
                if (_register)
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'ชื่อ'),
                  ),
                TextField(
                  controller: _login,
                  keyboardType: _register ? TextInputType.phone : TextInputType.text,
                  decoration: InputDecoration(labelText: _register ? 'เบอร์โทร' : 'เบอร์โทร หรือ อีเมล'),
                ),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_register ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ'),
                ),
                TextButton(
                  onPressed: () => setState(() => _register = !_register),
                  child: Text(_register ? 'มีบัญชีแล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? สมัครสมาชิก'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
