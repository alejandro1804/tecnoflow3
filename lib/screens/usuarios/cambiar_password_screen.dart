// lib/screens/usuarios/cambiar_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class CambiarPasswordScreen extends ConsumerStatefulWidget {
  const CambiarPasswordScreen({super.key});
  @override
  ConsumerState<CambiarPasswordScreen> createState() => _State();
}

class _State extends ConsumerState<CambiarPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading    = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final client = Supabase.instance.client;

      // 1. Cambiar contraseña en Supabase Auth
      await client.auth.updateUser(
        UserAttributes(password: _passCtrl.text.trim()),
      );

      // 2. Marcar primer_login = false en public.usuarios
      final uid = client.auth.currentUser!.id;
      await client
          .from('usuarios')
          .update({'primer_login': false})
          .eq('id', uid);

      // 3. Refrescar el perfil y navegar al home
      ref.invalidate(myProfileProvider);

    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset_outlined, size: 64, color: Colors.orange),
                  const SizedBox(height: 20),
                  Text(
                    'Cambiá tu contraseña',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Es tu primer ingreso. Por seguridad, establecé una contraseña personal.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pass2Ctrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Repetir contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        v != _passCtrl.text ? 'Las contraseñas no coinciden' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorContainer(_error!),
                  ],
                  const SizedBox(height: 28),
                  LoadingButton(
                    loading: _loading,
                    onPressed: _submit,
                    label: 'Guardar contraseña',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}