// lib/screens/maquinas/maquina_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class MaquinaFormScreen extends ConsumerStatefulWidget {
  final String? maquinaId;
  const MaquinaFormScreen({super.key, this.maquinaId});
  @override
  ConsumerState<MaquinaFormScreen> createState() => _State();
}

class _State extends ConsumerState<MaquinaFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nomCtrl  = TextEditingController();
  final _codCtrl  = TextEditingController();
  final _descCtrl = TextEditingController();
  String _sectorId = '';
  String _estado   = 'activo';
  bool _loading = false, _loadingData = false;
  String? _error;

  bool get isEdit => widget.maquinaId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loadingData = true);
    try {
      final maquinas = await ref.read(maquinasRepoProvider).getAll();
      final m = maquinas.firstWhere((m) => m.id == widget.maquinaId);
      _nomCtrl.text  = m.nombre;
      _codCtrl.text  = m.codigo;
      _descCtrl.text = m.descripcion ?? '';
      setState(() { _sectorId = m.sectorId; _estado = m.estado; });
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final m = Maquina(
        id:          widget.maquinaId ?? '',
        sectorId:    _sectorId,
        nombre:      _nomCtrl.text.trim(),
        codigo:      _codCtrl.text.trim(),
        estado:      _estado,
        descripcion: _descCtrl.text.trim(),
      );
      if (isEdit) {
        await ref.read(maquinasRepoProvider).update(widget.maquinaId!, m);
      } else {
        await ref.read(maquinasRepoProvider).create(m);
      }
      ref.invalidate(maquinasProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Guardado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _codCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectores = ref.watch(sectoresProvider).valueOrNull ?? [];
    if (_sectorId.isEmpty && sectores.isNotEmpty) {
      _sectorId = sectores.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar máquina' : 'Nueva máquina'),
        // Sin botón eliminar — las máquinas se inactivan, no se eliminan
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

                    // ── Nombre ────────────────────────────
                    TextFormField(
                      controller: _nomCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(
                              Icons.precision_manufacturing_outlined)),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 16),

                    // ── Código ────────────────────────────
                    TextFormField(
                      controller: _codCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Código',
                          prefixIcon: Icon(Icons.qr_code_outlined)),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 16),

                    // ── Sector ────────────────────────────
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _sectorId.isEmpty ? null : _sectorId,
                      decoration: const InputDecoration(
                          labelText: 'Sector',
                          prefixIcon: Icon(Icons.domain_outlined)),
                      items: sectores.map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.nombre))).toList(),
                      onChanged: (v) => setState(() => _sectorId = v!),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 16),

                    // ── Estado ────────────────────────────
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: const InputDecoration(
                          labelText: 'Estado',
                          prefixIcon: Icon(Icons.toggle_on_outlined)),
                      items: const [
                        DropdownMenuItem(
                            value: 'activo', child: Text('Activo')),
                        DropdownMenuItem(
                            value: 'inactivo', child: Text('Inactivo')),
                        DropdownMenuItem(
                            value: 'en_reparacion',
                            child: Text('En reparación')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!)),
                    const SizedBox(height: 16),

                    // ── Descripción ───────────────────────
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          prefixIcon: Icon(Icons.notes_outlined))),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorContainer(_error!),
                    ],
                    const SizedBox(height: 28),
                    LoadingButton(
                        loading: _loading,
                        onPressed: _submit,
                        label: 'Guardar'),
                  ],
                ),
              ),
      ),
    );
  }
}
