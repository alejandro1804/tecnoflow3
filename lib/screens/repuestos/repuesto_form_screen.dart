// lib/screens/repuestos/repuesto_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class RepuestoFormScreen extends ConsumerStatefulWidget {
  final String? repuestoId;
  const RepuestoFormScreen({super.key, this.repuestoId});
  @override
  ConsumerState<RepuestoFormScreen> createState() => _State();
}

class _State extends ConsumerState<RepuestoFormScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _codCtrl   = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _minCtrl   = TextEditingController(text: '0');
  final _ubicCtrl  = TextEditingController();
  bool _loading = false, _loadingData = false;
  String? _error;
  bool get isEdit => widget.repuestoId != null;

  @override
  void initState() { super.initState(); if (isEdit) _load(); }

  Future<void> _load() async {
    setState(() => _loadingData = true);
    try {
      final r = await ref.read(repuestosRepoProvider).getAll();
      final rep = r.firstWhere((r) => r.id == widget.repuestoId);
      _codCtrl.text  = rep.codigo;
      _descCtrl.text = rep.descripcion;
      _minCtrl.text  = rep.stockMinimo.toString();
      _ubicCtrl.text = rep.ubicacion ?? '';
    } finally { if (mounted) setState(() => _loadingData = false); }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final rep = Repuesto(id: widget.repuestoId ?? '',
          codigo: _codCtrl.text.trim(), descripcion: _descCtrl.text.trim(),
          stockActual: 0, stockMinimo: int.tryParse(_minCtrl.text) ?? 0,
          ubicacion: _ubicCtrl.text.trim().isEmpty ? null : _ubicCtrl.text.trim());
      if (isEdit) await ref.read(repuestosRepoProvider).update(widget.repuestoId!, rep);
      else        await ref.read(repuestosRepoProvider).create(rep);
      ref.invalidate(repuestosProvider);
      if (mounted) { context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado'), backgroundColor: Colors.green)); }
    } catch (e) { setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _delete() async {
    final ok = await confirmarEliminacion(context, '¿Eliminar "${_codCtrl.text}"?');
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await ref.read(repuestosRepoProvider).delete(widget.repuestoId!);
      ref.invalidate(repuestosProvider);
      if (mounted) context.pop();
    } catch (e) { setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void dispose() { _codCtrl.dispose(); _descCtrl.dispose(); _minCtrl.dispose(); _ubicCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(isEdit ? 'Editar repuesto' : 'Nuevo repuesto'),
      actions: [if (isEdit) IconButton(icon: const Icon(Icons.delete_outline),
          color: Colors.red[200], onPressed: _loading ? null : _delete)]),
    body: _loadingData ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(controller: _codCtrl, textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Código / SKU', prefixIcon: Icon(Icons.qr_code_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _descCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción', prefixIcon: Icon(Icons.description_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _minCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Stock mínimo', prefixIcon: Icon(Icons.warning_amber_outlined)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _ubicCtrl,
                  decoration: const InputDecoration(labelText: 'Ubicación / Depósito (opcional)', prefixIcon: Icon(Icons.location_on_outlined))),
              if (_error != null) ...[const SizedBox(height: 12), ErrorContainer(_error!)],
              const SizedBox(height: 28),
              LoadingButton(loading: _loading, onPressed: _submit, label: 'Guardar'),
            ]))),
  );
}
