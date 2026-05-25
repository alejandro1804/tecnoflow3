// lib/screens/usuarios/cambiar_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _obscure1   = true;
  bool _obscure2   = true;
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

      // 3. Verificar directo en BD que el cambio se aplicó
      final row = await client
          .from('usuarios')
          .select('primer_login')
          .eq('id', uid)
          .single();
      final primerLoginActual = row['primer_login'] as bool? ?? true;

      // 4. Si la BD confirma que ya no es primer_login, navegar
      if (primerLoginActual == false) {
        ref.invalidate(myProfileProvider);
        if (mounted) context.go('/home');
      } else {
        // Reintentar si por alguna razón no se guardó
        setState(() => _error = 'Error al guardar. Intentá de nuevo.');
      }

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
                  const Icon(Icons.lock_reset_outlined,
                      size: 64, color: Colors.orange),
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
                    obscureText: _obscure1,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure1
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _obscure1 = !_obscure1),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pass2Ctrl,
                    obscureText: _obscure2,
                    decoration: InputDecoration(
                      labelText: 'Repetir contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure2
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _obscure2 = !_obscure2),
                      ),
                    ),
                    validator: (v) =>
                        v != _passCtrl.text
                            ? 'Las contraseñas no coinciden' : null,
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