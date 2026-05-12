// lib/screens/login/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() { _loading = true; _error = null; });
  try {
    await ref.read(authRepoProvider).signIn(
      email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());

    // Verificar que el usuario esté activo
    final profile = await ref.read(authRepoProvider).getMyProfile();
    if (profile == null || profile.estado == 'inactivo') {
      await ref.read(authRepoProvider).signOut();
      setState(() => _error = 'Usuario inactivo. Contacte al administrador.');
      return;
    }

    if (mounted) context.go('/home');
  } catch (_) {
    setState(() => _error = 'Credenciales incorrectas. Intente nuevamente.');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.construction_rounded, size: 72, color: Colors.white),
          const SizedBox(height: 12),
          const Text(AppStrings.appName,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text('Control de stock — Mantenimiento',
              style: TextStyle(color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 40),
          Card(child: Padding(padding: const EdgeInsets.all(24),
            child: Form(key: _formKey, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: AppStrings.labelEmail,
                    prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: AppStrings.labelPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure))),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorContainer(_error!),
                ],
                const SizedBox(height: 24),
                LoadingButton(loading: _loading, onPressed: _login, label: AppStrings.btnLogin),
              ])))),
        ]),
      ))),
    );
  }
}
