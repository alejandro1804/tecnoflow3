// lib/screens/usuarios/usuario_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets.dart';
import '../../core/constants.dart';
import '../../providers/providers.dart';

class UsuarioFormScreen extends ConsumerStatefulWidget {
  final String? userId;
  const UsuarioFormScreen({super.key, this.userId});
  @override
  ConsumerState<UsuarioFormScreen> createState() => _State();
}

class _State extends ConsumerState<UsuarioFormScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();

  String  _rolId        = '';
  String  _estado       = 'activo';
  bool    _loading      = false;
  bool    _loadingData  = false;
  bool    _primerLogin  = false;
  String? _emailOriginal;
  String? _error;

  bool get isEdit => widget.userId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loadingData = true);
    try {
      final u = await ref.read(usuariosRepoProvider).getById(widget.userId!);
      if (u != null && mounted) {
        _nombreCtrl.text = u.nombre;
        _emailCtrl.text  = u.email;
        setState(() {
          _rolId         = u.rolId;
          _estado        = u.estado;
          _primerLogin   = u.primerLogin;
          _emailOriginal = u.email;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (isEdit) {
        final adminClient = SupabaseClient(supabaseUrl, supabaseServiceKey);
        final emailNuevo  = _emailCtrl.text.trim();
        final emailCambio = emailNuevo != _emailOriginal;

        if (emailCambio) {
          await adminClient.auth.admin.updateUserById(
            widget.userId!,
            attributes: AdminUserAttributes(email: emailNuevo),
          );
        }

        await ref.read(usuariosRepoProvider).update(
          widget.userId!,
          nombre: _nombreCtrl.text.trim(),
          rolId:  _rolId,
          estado: _estado,
          email:  emailCambio ? emailNuevo : null,
        );

      } else {
        final roles = ref.read(rolesProvider).valueOrNull ?? [];
        final rolNombre = roles
            .firstWhere((r) => r.id == _rolId, orElse: () => roles.first)
            .nombre;
        await ref.read(authRepoProvider).createUser(
          email:     _emailCtrl.text.trim(),
          password:  _passCtrl.text.trim(),
          nombre:    _nombreCtrl.text.trim(),
          rolNombre: rolNombre,
        );
      }

      ref.invalidate(usuariosProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Usuario actualizado' : 'Usuario creado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Modal resetear contraseña ─────────────────────────────
  Future<void> _mostrarResetPassword() async {
    final exito = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ResetPasswordModal(
        userId: widget.userId!,
        nombre: _nombreCtrl.text,
      ),
    );

    // El modal ya cerró completamente — ahora es seguro actualizar
    if (exito == true && mounted) {
      ref.invalidate(usuariosProvider);
      setState(() => _primerLogin = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña reseteada'),
          backgroundColor: Colors.orange,
        ),
      );
      context.pop(); // ← volver a la lista de usuarios
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).valueOrNull ?? [];
    if (_rolId.isEmpty && roles.isNotEmpty) _rolId = roles.first.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar usuario' : 'Nuevo usuario'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.lock_reset_outlined),
              color: Colors.orange[300],
              tooltip: 'Resetear contraseña',
              onPressed: _loadingData ? null : _mostrarResetPassword,
            ),
        ],
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Banner contraseña temporal ────────
                    if (isEdit && _primerLogin) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.3))),
                        child: Row(children: const [
                          Icon(Icons.lock_clock_outlined,
                              color: Colors.orange, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                'Este usuario tiene contraseña temporal y aún no realizó su primer ingreso.',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange)),
                          ),
                        ]),
                      ),
                    ],

                    // ── Nombre ────────────────────────────
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Email ─────────────────────────────
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: const Icon(Icons.email_outlined),
                        suffixIcon: isEdit &&
                                _emailCtrl.text.trim() != (_emailOriginal ?? '')
                            ? const Tooltip(
                                message: 'El email será actualizado',
                                child: Icon(Icons.info_outline,
                                    color: Colors.blue, size: 18))
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Contraseña — solo al crear ────────
                    if (!isEdit) ...[
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 6)
                                ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Rol ───────────────────────────────
                    DropdownButtonFormField<String>(
                      value: _rolId.isEmpty ? null : _rolId,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                      items: roles
                          .map((r) => DropdownMenuItem(
                              value: r.id, child: Text(r.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() => _rolId = v!),
                    ),
                    const SizedBox(height: 16),

                    // ── Estado — solo en edición ──────────
                    if (isEdit)
                      DropdownButtonFormField<String>(
                        value: _estado,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                          prefixIcon: Icon(Icons.toggle_on_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'activo', child: Text('Activo')),
                          DropdownMenuItem(
                              value: 'inactivo', child: Text('Inactivo')),
                        ],
                        onChanged: (v) => setState(() => _estado = v!),
                      ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorContainer(_error!),
                    ],
                    const SizedBox(height: 28),
                    LoadingButton(
                      loading: _loading,
                      onPressed: _submit,
                      label: 'Guardar',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Widget separado para el modal — tiene su propio ciclo de vida
// ══════════════════════════════════════════════════════════════
class _ResetPasswordModal extends StatefulWidget {
  final String userId;
  final String nombre;
  const _ResetPasswordModal({
    required this.userId,
    required this.nombre,
  });
  @override
  State<_ResetPasswordModal> createState() => _ResetPasswordModalState();
}

class _ResetPasswordModalState extends State<_ResetPasswordModal> {
  final _formKey   = GlobalKey<FormState>();
  final _passCtrl  = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      // ── Admin API solo para Auth ──────────────────────────
      final adminClient = SupabaseClient(supabaseUrl, supabaseServiceKey);
      await adminClient.auth.admin.updateUserById(
        widget.userId,
        attributes: AdminUserAttributes(password: _passCtrl.text.trim()),
      );

      // ── Cliente normal para la tabla usuarios ─────────────
      await Supabase.instance.client
          .from('usuarios')
          .update({'primer_login': true})
          .eq('id', widget.userId);

      // ── Cerrar modal devolviendo éxito ────────────────────
      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.lock_reset_outlined,
                    color: Colors.orange, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resetear contraseña',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(widget.nombre,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.2))),
              child: const Text(
                  'El usuario deberá cambiar esta contraseña en su próximo ingreso.',
                  style: TextStyle(fontSize: 11, color: Colors.orange)),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Nueva contraseña temporal',
                  prefixIcon: Icon(Icons.lock_outline)),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null),
            const SizedBox(height: 12),

            TextFormField(
              controller: _pass2Ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: Icon(Icons.lock_outline)),
              validator: (v) =>
                  v != _passCtrl.text ? 'Las contraseñas no coinciden' : null),

            if (_error != null) ...[
              const SizedBox(height: 10),
              ErrorContainer(_error!),
            ],
            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _loading ? null : _confirmar,
              child: _loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmar reset'),
            ),
          ],
        ),
      ),
    );
  }
}