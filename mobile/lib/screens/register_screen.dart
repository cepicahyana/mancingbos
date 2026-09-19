import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'user';
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthState>().register(_name.text.trim(), _email.text.trim(), _password.text, _role);
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar akun')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SoftPanel(
          child: Form(
            key: _form,
            child: Column(
              children: [
                const IconBadge(icon: Icons.person_add_alt_1_rounded, size: 56),
                const SizedBox(height: 14),
                const Text('Buat akun IndoFish', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: fieldDeco('Nama lengkap', icon: Icons.badge_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: fieldDeco('Email', icon: Icons.mail_outline_rounded),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: fieldDeco('Password', icon: Icons.lock_outline_rounded).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Password minimal 6 karakter' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: fieldDeco('Daftar sebagai', icon: Icons.groups_2_outlined),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('Pencinta Mancing')),
                    DropdownMenuItem(value: 'owner', child: Text('Pemilik Lapak')),
                    DropdownMenuItem(value: 'operator', child: Text('Operator Event')),
                  ],
                  onChanged: (v) => setState(() => _role = v ?? 'user'),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_loading ? 'Memproses...' : 'Buat akun'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
