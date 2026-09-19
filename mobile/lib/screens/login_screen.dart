import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../state/auth_state.dart';
import '../widgets/app_states.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'user@example.com');
  final _password = TextEditingController(text: 'password');
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthState>().login(_email.text.trim(), _password.text);
    } on ApiException catch (e) {
      if (mounted) showAppError(context, e.firstError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF8F1), AppTheme.bg, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Form(
                key: _form,
                child: Column(
                  children: [
                    const BrandMark(size: 84),
                    const SizedBox(height: 18),
                    const Text(
                      'IndoFish',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Platform terbaik untuk event mancing',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondary, fontSize: 15),
                    ),
                    const SizedBox(height: 28),
                    SoftPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Masuk akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                          const SizedBox(height: 4),
                          const Text('Kelola event, sewa lapak, dan hasil tangkapan', style: TextStyle(color: AppTheme.secondary, fontSize: 13)),
                          const SizedBox(height: 18),
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
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login_rounded),
                            label: Text(_loading ? 'Memproses...' : 'Masuk'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Belum punya akun? Daftar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
