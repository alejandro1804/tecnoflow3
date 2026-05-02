// lib/screens/usuarios/usuario_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
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
  String _rolId     = '';
  String _estado    = 'activo';
  bool _loading     = false, _loadingData = false;
  String? _error;
  bool get isEdit => widget.userId != null;

  @override
  void initState() { super.initState(); if (isEdit) _load(); }

  Future<void> _load() async {
    setState(() => _loadingData = true);
    try {
      final u = await ref.read(usuariosRepoProvider).getById(widget.userId!);
      if (u != null && mounted) {
        _nombreCtrl.text = u.nombre;
        _emailCtrl.text  = u.email;
        setState(() { _rolId = u.rolId; _estado = u.estado; });
      }
    } finally { if (mounted) setState(() => _loadingData = false); }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (isEdit) {
        await ref.read(usuariosRepoProvider).update(widget.userId!,
            nombre: _nombreCtrl.text.trim(), rolId: _rolId, estado: _estado);
      } else {
        await ref.read(authRepoProvider).signUp(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text.trim(),
            nombre: _nombreCtrl.text.trim(),
            rol: ref.read(rolesProvider).valueOrNull
                ?.firstWhere((r) => r.id == _rolId, orElse: () => ref.read(rolesProvider).valueOrNull!.first)
                .nombre ?? 'tecnico');
      }
      ref.invalidate(usuariosProvider);
      if (mounted) { context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit ? 'Usuario actualizado' : 'Usuario creado'),
            backgroundColor: Colors.green)); }
    } catch (e) { setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void dispose() { _nombreCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).valueOrNull ?? [];
    if (_rolId.isEmpty && roles.isNotEmpty) _rolId = roles.first.id;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar usuario' : 'Nuevo usuario')),
      body: _loadingData ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(padding: const EdgeInsets.all(20),
              child: Form(key: _formKey, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                  const SizedBox(height: 16),
                  if (!isEdit) ...[
                    TextFormField(controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.email_outlined)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _passCtrl, obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                        validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    value: _rolId.isEmpty ? null : _rolId,
                    decoration: const InputDecoration(labelText: 'Rol', prefixIcon: Icon(Icons.admin_panel_settings_outlined)),
                    items: roles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nombre))).toList(),
                    onChanged: (v) => setState(() => _rolId = v!)),
                  const SizedBox(height: 16),
                  if (isEdit)
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: const InputDecoration(labelText: 'Estado', prefixIcon: Icon(Icons.toggle_on_outlined)),
                      items: const [
                        DropdownMenuItem(value: 'activo',   child: Text('Activo')),
                        DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!)),
                  if (_error != null) ...[const SizedBox(height: 12), ErrorContainer(_error!)],
                  const SizedBox(height: 28),
                  LoadingButton(loading: _loading, onPressed: _submit, label: 'Guardar'),
                ]))),
    );
  }
}
