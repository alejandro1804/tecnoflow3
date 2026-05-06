// lib/screens/movimientos/ingreso_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class IngresoFormScreen extends ConsumerStatefulWidget {
  final IngresoRepuesto? ingreso;
  const IngresoFormScreen({super.key, this.ingreso});

  @override
  ConsumerState<IngresoFormScreen> createState() => _State();
}

class _State extends ConsumerState<IngresoFormScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _cantCtrl    = TextEditingController(text: '1');
  final _entregaCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  String _repuestoId = '';
  bool _loading      = false;
  String? _error;

  bool get isEdit => widget.ingreso != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final ing         = widget.ingreso!;
      _repuestoId       = ing.repuestoId;
      _cantCtrl.text    = ing.cantidad.toString();
      _entregaCtrl.text = ing.quienEntrega;
      _descCtrl.text    = ing.descripcion ?? '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (isEdit) {
        await ref.read(movimientosRepoProvider).updateIngreso(
            widget.ingreso!.id,
            repuestoId:   _repuestoId,
            cantidad:     int.parse(_cantCtrl.text),
            quienEntrega: _entregaCtrl.text.trim(),
            descripcion:  _descCtrl.text.trim().isEmpty
                ? null : _descCtrl.text.trim());
      } else {
        await ref.read(movimientosRepoProvider).createIngreso(
            repuestoId:   _repuestoId,
            cantidad:     int.parse(_cantCtrl.text),
            quienEntrega: _entregaCtrl.text.trim(),
            descripcion:  _descCtrl.text.trim().isEmpty
                ? null : _descCtrl.text.trim());
      }
      ref.invalidate(ingresosProvider);
      ref.invalidate(repuestosProvider);
      if (mounted) {
        if (isEdit) Navigator.pop(context);
        else context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit ? 'Ingreso actualizado' : 'Ingreso registrado'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _entregaCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repuestos = ref.watch(repuestosProvider).valueOrNull ?? [];
    if (_repuestoId.isEmpty && repuestos.isNotEmpty) {
      _repuestoId = repuestos.first.id;
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit ? 'Editar ingreso' : 'Registrar ingreso')),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Selector de repuesto ──────────────────
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _repuestoId.isEmpty ? null : _repuestoId,
                decoration: const InputDecoration(
                    labelText: 'Repuesto',
                    prefixIcon: Icon(Icons.inventory_2_outlined)),
                items: repuestos.map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(
                      '${r.descripcion}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w400),
                    ))).toList(),
                onChanged: (v) => setState(() => _repuestoId = v!),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Seleccione un repuesto' : null),
              const SizedBox(height: 16),

              // ── Cantidad ──────────────────────────────
              TextFormField(
                controller: _cantCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers_outlined)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
                  return null;
                }),
              const SizedBox(height: 16),

              // ── Quien entrega ─────────────────────────
              TextFormField(
                controller: _entregaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Quien entrega',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 11),
                decoration: const InputDecoration(
                    labelText: 'Descripción / Nota (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    labelStyle: TextStyle(fontSize: 10))),

              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorContainer(_error!),
              ],
              const SizedBox(height: 28),
              LoadingButton(
                  loading: _loading,
                  onPressed: _submit,
                  label: isEdit ? 'Guardar cambios' : 'Registrar ingreso'),
            ],
          ),
        ),
      ),
    );
  }
}
