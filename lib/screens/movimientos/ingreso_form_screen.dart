// lib/screens/movimientos/ingreso_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class IngresoFormScreen extends ConsumerStatefulWidget {
  final IngresoRepuesto? ingreso;
  final Repuesto?        repuestoPreseleccionado;

  const IngresoFormScreen({
    super.key,
    this.ingreso,
    this.repuestoPreseleccionado,
  });

  @override
  ConsumerState<IngresoFormScreen> createState() => _State();
}

class _State extends ConsumerState<IngresoFormScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _cantCtrl    = TextEditingController(text: '1');
  final _entregaCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _busqCtrl    = TextEditingController();
  final _refCtrl     = TextEditingController();

  String  _repuestoId  = '';
  String  _busqueda    = '';
  String  _busquedaRef = '';
  bool    _loading     = false;
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
      _busqCtrl.text    = ing.repuestoDescripcion ?? '';
    } else if (widget.repuestoPreseleccionado != null) {
      _repuestoId    = widget.repuestoPreseleccionado!.id;
      _busqCtrl.text = widget.repuestoPreseleccionado!.descripcion;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_repuestoId.isEmpty) {
      setState(() => _error = 'Seleccione un repuesto');
      return;
    }
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isEdit ? 'Ingreso actualizado' : 'Ingreso registrado'),
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
    _cantCtrl.dispose(); _entregaCtrl.dispose();
    _descCtrl.dispose(); _busqCtrl.dispose(); _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repuestos    = ref.watch(repuestosProvider).valueOrNull ?? [];
    final repuestoFijo = widget.repuestoPreseleccionado;

    List<Repuesto> repuestosFiltrados;
    if (_busquedaRef.isNotEmpty) {
      final refNum = int.tryParse(_busquedaRef);
      repuestosFiltrados = refNum != null
          ? repuestos.where((r) => r.ref == refNum).toList()
          : [];
    } else if (_busqueda.isNotEmpty) {
      repuestosFiltrados = repuestos.where((r) =>
          // ← codigo nullable
          (r.codigo ?? '').toLowerCase().contains(_busqueda.toLowerCase()) ||
          r.descripcion.toLowerCase().contains(_busqueda.toLowerCase()))
          .toList()
        ..sort((a, b) => a.descripcion.compareTo(b.descripcion));
    } else {
      repuestosFiltrados = [];
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

              // ── Repuesto preseleccionado (solo lectura) ──
              if (repuestoFijo != null && !isEdit)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(repuestoFijo.descripcion,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(
                            // ← codigo nullable
                            'Código: ${repuestoFijo.codigo ?? '—'}  |  Stock: ${repuestoFijo.stockActual}'
                            '${repuestoFijo.ref != null ? '  |  REF: ${repuestoFijo.ref}' : ''}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    )),
                  ]),
                ),

              // ── Buscador de repuesto ──────────────────
              if (repuestoFijo == null || isEdit) ...[
                const Text('REPUESTO', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _busqCtrl,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                      labelText: 'Buscar por código o descripción',
                      prefixIcon: const Icon(Icons.search),
                      labelStyle: const TextStyle(fontSize: 11),
                      suffixIcon: _repuestoId.isNotEmpty
                          ? const Icon(Icons.check_circle,
                              color: Colors.green)
                          : null),
                  onChanged: (v) => setState(() {
                    _busqueda    = v;
                    _busquedaRef = '';
                    _refCtrl.clear();
                    _repuestoId  = '';
                  }),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _refCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Buscar por N° REF',
                    prefixIcon: const Icon(Icons.tag,
                        color: Colors.purple, size: 20),
                    labelStyle: const TextStyle(
                        fontSize: 11, color: Colors.purple),
                    suffixIcon: _busquedaRef.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _refCtrl.clear();
                              setState(() {
                                _busquedaRef = '';
                                _repuestoId  = '';
                              });
                            })
                        : null,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.purple.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.purple)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() {
                    _busquedaRef = v;
                    _busqueda    = '';
                    _busqCtrl.clear();
                    _repuestoId  = '';
                  }),
                ),
                const SizedBox(height: 4),

                if ((_busqueda.isNotEmpty || _busquedaRef.isNotEmpty) &&
                    _repuestoId.isEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10)),
                    child: repuestosFiltrados.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Sin resultados',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: repuestosFiltrados.length,
                            itemBuilder: (_, i) {
                              final r = repuestosFiltrados[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 18, color: Colors.green),
                                title: Text(r.descripcion,
                                    style: const TextStyle(fontSize: 11)),
                                subtitle: Text(
                                    'Stock: ${r.stockActual}'
                                    '${r.ref != null ? '  •  REF ${r.ref}' : ''}',
                                    style: const TextStyle(fontSize: 10)),
                                onTap: () => setState(() {
                                  _repuestoId    = r.id;
                                  _busqCtrl.text = r.descripcion;
                                  _busqueda      = '';
                                  _busquedaRef   = '';
                                  _refCtrl.clear();
                                }),
                              );
                            }),
                  ),
                const SizedBox(height: 16),
              ],

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
                  if ((int.tryParse(v) ?? 0) <= 0)
                    return 'Debe ser mayor a 0';
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

              // ── Nota opcional ─────────────────────────
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                style: const TextStyle(
                    fontWeight: FontWeight.w400, fontSize: 11),
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