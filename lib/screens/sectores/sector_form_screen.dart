// lib/screens/sectores/sector_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class SectorFormScreen extends ConsumerStatefulWidget {
  final String? sectorId;
  const SectorFormScreen({super.key, this.sectorId});
  @override
  ConsumerState<SectorFormScreen> createState() => _State();
}

class _State extends ConsumerState<SectorFormScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nomCtrl   = TextEditingController();
  final _descCtrl  = TextEditingController();
  bool _loading    = false, _loadingData = false;
  String? _error;
  bool get isEdit => widget.sectorId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loadingData = true);
    final sectores = await ref.read(sectoresRepoProvider).getAll();
    final s = sectores.firstWhere((s) => s.id == widget.sectorId);
    _nomCtrl.text  = s.nombre;
    _descCtrl.text = s.descripcion ?? '';
    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final s = Sector(id: widget.sectorId ?? '', nombre: _nomCtrl.text.trim(), descripcion: _descCtrl.text.trim());
      if (isEdit) { await ref.read(sectoresRepoProvider).update(widget.sectorId!, s); }
      else { await ref.read(sectoresRepoProvider).create(s); }
      ref.invalidate(sectoresProvider);
      if (mounted) { context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado'), backgroundColor: Colors.green)); }
    } catch (e) { setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _delete() async {
    final ok = await confirmarEliminacion(context, '¿Eliminar sector "${_nomCtrl.text}"?');
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await ref.read(sectoresRepoProvider).delete(widget.sectorId!);
      ref.invalidate(sectoresProvider);
      if (mounted) context.pop();
    } catch (e) { setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void dispose() { _nomCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(isEdit ? 'Editar sector' : 'Nuevo sector'),
      actions: [if (isEdit) IconButton(icon: const Icon(Icons.delete_outline),
          color: Colors.red[200], onPressed: _loading ? null : _delete)]),
    body: _loadingData ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(controller: _nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del sector', prefixIcon: Icon(Icons.domain_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _descCtrl, maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descripción (opcional)', prefixIcon: Icon(Icons.notes_outlined))),
              if (_error != null) ...[const SizedBox(height: 12), ErrorContainer(_error!)],
              const SizedBox(height: 28),
              LoadingButton(loading: _loading, onPressed: _submit, label: 'Guardar'),
            ]))),
  );
}
