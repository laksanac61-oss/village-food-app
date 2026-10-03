import 'package:flutter/material.dart';

import '../core/api.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _register = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    await guard(context, () async {
      if (_register) {
        await Api.signUp(_email.text.trim(), _password.text, _name.text.trim(), _phone.text.trim());
      } else {
        await Api.signIn(_email.text.trim(), _password.text);
      }
    });
    if (mounted) setState(() => _busy = false);
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
                const Icon(Icons.restaurant, size: 64),
                const SizedBox(height: 8),
                Text(
                  'สั่งอาหารในหมู่บ้าน',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                if (_register) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'ชื่อ'),
                  ),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'เบอร์โทร'),
                  ),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'อีเมล'),
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
