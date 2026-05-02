// lib/screens/movimientos/ingreso_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class IngresoFormScreen extends ConsumerStatefulWidget {
  const IngresoFormScreen({super.key});
  @override
  ConsumerState<IngresoFormScreen> createState() => _State();
}

class _State extends ConsumerState<IngresoFormScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _cantCtrl      = TextEditingController(text: '1');
  final _entregaCtrl   = TextEditingController();
  final _descCtrl      = TextEditingController();
  String _repuestoId   = '';
  bool _loading        = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(movimientosRepoProvider).createIngreso(
          repuestoId:   _repuestoId,
          cantidad:     int.parse(_cantCtrl.text),
          quienEntrega: _entregaCtrl.text.trim(),
          descripcion:  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim());
      ref.invalidate(ingresosProvider);
      ref.invalidate(repuestosProvider);
      if (mounted) { context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ingreso registrado'), backgroundColor: Colors.green)); }
    } catch (e) { setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  void dispose() { _cantCtrl.dispose(); _entregaCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final repuestos = ref.watch(repuestosProvider).valueOrNull ?? [];
    if (_repuestoId.isEmpty && repuestos.isNotEmpty) _repuestoId = repuestos.first.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar ingreso')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20),
          child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              value: _repuestoId.isEmpty ? null : _repuestoId,
              decoration: const InputDecoration(labelText: 'Repuesto', prefixIcon: Icon(Icons.inventory_2_outlined)),
              items: repuestos.map((r) => DropdownMenuItem(value: r.id,
                  child: Text('${r.codigo} — ${r.descripcion}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _repuestoId = v!),
              validator: (v) => (v == null || v.isEmpty) ? 'Seleccione un repuesto' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _cantCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Cantidad', prefixIcon: Icon(Icons.numbers_outlined)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
                  return null;
                }),
            const SizedBox(height: 16),
            TextFormField(controller: _entregaCtrl,
                decoration: const InputDecoration(labelText: 'Quien entrega', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _descCtrl, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción / Nota (opcional)', prefixIcon: Icon(Icons.notes_outlined))),
            if (_error != null) ...[const SizedBox(height: 12), ErrorContainer(_error!)],
            const SizedBox(height: 28),
            LoadingButton(loading: _loading, onPressed: _submit, label: 'Registrar ingreso'),
          ]))),
    );
  }
}
