// lib/screens/movimientos/salida_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class SalidaFormScreen extends ConsumerStatefulWidget {
  final SalidaRepuesto? salida;
  final String? ticketIdInicial;

  const SalidaFormScreen({super.key, this.salida, this.ticketIdInicial});

  @override
  ConsumerState<SalidaFormScreen> createState() => _State();
}

class _State extends ConsumerState<SalidaFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _cantCtrl = TextEditingController(text: '1');
  final _obsCtrl  = TextEditingController();
  final _busqCtrl = TextEditingController();

  String? _repuestoId;
  String? _ticketId;
  String  _busqueda  = '';
  bool    _conTicket = false;
  bool    _loading   = false;
  String? _error;

  bool get isEdit => widget.salida != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final s = widget.salida!;
      _repuestoId    = s.repuestoId;
      _ticketId      = s.ticketId;
      _conTicket     = s.ticketId != null;
      _cantCtrl.text = s.cantidad.toString();
      _obsCtrl.text  = s.observacion ?? '';
      _busqCtrl.text = s.repuestoDescripcion ?? '';
    } else if (widget.ticketIdInicial != null) {
      _ticketId  = widget.ticketIdInicial;
      _conTicket = true;
    }
  }

  @override
  void dispose() {
    _cantCtrl.dispose(); _obsCtrl.dispose(); _busqCtrl.dispose();
    super.dispose();
  }

  String _mensajeError(Object e) {
    final msg = e.toString();
    if (msg.contains('Stock insuficiente')) {
      return 'Stock insuficiente. Verificá la cantidad disponible del repuesto antes de continuar.';
    }
    if (msg.contains('violates row-level security')) {
      return 'No tenés permisos para realizar esta operación.';
    }
    if (msg.contains('violates foreign key')) {
      return 'El repuesto o ticket seleccionado no existe.';
    }
    return 'Ocurrió un error. Intentá nuevamente.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_repuestoId == null) {
      setState(() => _error = 'Seleccione un repuesto');
      return;
    }
    if (_conTicket && _ticketId == null) {
      setState(() => _error = 'Seleccione un ticket');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (isEdit) {
        await ref.read(movimientosRepoProvider).updateSalida(
          widget.salida!.id,
          repuestoId:  _repuestoId!,
          cantidad:    int.parse(_cantCtrl.text),
          ticketId:    _conTicket ? _ticketId : null,
          observacion: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        );
      } else {
        await ref.read(movimientosRepoProvider).createSalida(
          repuestoId:  _repuestoId!,
          cantidad:    int.parse(_cantCtrl.text),
          ticketId:    _conTicket ? _ticketId : null,
          observacion: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        );
      }
      ref.invalidate(salidasProvider);
      ref.invalidate(repuestosProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit ? 'Salida actualizada' : 'Salida registrada'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repuestos = ref.watch(repuestosProvider).valueOrNull ?? [];
    final tickets   = ref.watch(ticketsProvider).valueOrNull ?? [];
    final profile   = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin   = profile?.isAdmin ?? false;

    var ticketsFiltrados = isAdmin
        ? tickets.where((t) => t.estado != 'cerrado').toList()
        : tickets.where((t) =>
            t.tecnicoId == profile?.id &&
            t.estado != 'cerrado').toList();

    if (isEdit && _ticketId != null) {
      final yaEsta = ticketsFiltrados.any((t) => t.id == _ticketId);
      if (!yaEsta) {
        final ticketOriginal = tickets.where((t) => t.id == _ticketId).toList();
        ticketsFiltrados = [...ticketOriginal, ...ticketsFiltrados];
      }
    }

    final repuestosFiltrados = (_busqueda.isEmpty
        ? repuestos
        : repuestos.where((r) =>
            r.codigo.toLowerCase().contains(_busqueda.toLowerCase()) ||
            r.descripcion.toLowerCase().contains(_busqueda.toLowerCase()))
        .toList())
      ..sort((a, b) => a.descripcion.compareTo(b.descripcion));

    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit ? 'Editar salida' : 'Nueva salida de repuesto')),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Seleccionar repuesto ───────────────────
              const Text('REPUESTO', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _busqCtrl,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                    labelText: 'Buscar repuesto',
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Código o descripción...',
                    labelStyle: const TextStyle(fontSize: 11),
                    suffixIcon: _repuestoId != null
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null),
                onChanged: (v) => setState(() {
                  _busqueda   = v;
                  _repuestoId = null;
                }),
              ),
              if (_busqueda.isNotEmpty && _repuestoId == null) ...[
                const SizedBox(height: 4),
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
                            final r        = repuestosFiltrados[i];
                            final sinStock = r.stockActual == 0;
                            return ListTile(
                              dense: true,
                              enabled: !sinStock,
                              leading: StockBadge(
                                  stock: r.stockActual, minimo: r.stockMinimo),
                              title: Text(r.descripcion,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: sinStock ? Colors.grey : null)),
                              subtitle: Text(
                                  sinStock
                                      ? 'Sin stock disponible'
                                      : 'Stock disponible: ${r.stockActual}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: sinStock ? Colors.red : null)),
                              onTap: sinStock ? null : () => setState(() {
                                _repuestoId    = r.id;
                                _busqCtrl.text = r.descripcion;
                                _busqueda      = '';
                              }),
                            );
                          }),
                ),
              ],
              const SizedBox(height: 16),

              // ── Cantidad ───────────────────────────────
              TextFormField(
                controller: _cantCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers_outlined),
                    labelStyle: TextStyle(fontSize: 12)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
                  return null;
                }),
              const SizedBox(height: 16),

              // ── Asociar ticket (opcional) ──────────────
              const Text('TICKET', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(children: [
                const Text('¿Asociar a un ticket?',
                    style: TextStyle(fontSize: 12)),
                const Spacer(),
                Switch(
                    value: _conTicket,
                    onChanged: (v) => setState(() {
                      _conTicket = v;
                      if (!v) _ticketId = null;
                    })),
              ]),
              if (_conTicket) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _ticketId,
                  decoration: const InputDecoration(
                      labelText: 'Seleccionar ticket',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      labelStyle: TextStyle(fontSize: 12)),
                  items: ticketsFiltrados.map((t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(
                        '${t.maquinaNombre ?? 'Sin máquina'} — ${t.estado}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (v) => setState(() => _ticketId = v),
                  validator: (v) => (_conTicket && (v == null || v.isEmpty))
                      ? 'Seleccione un ticket' : null),
              ],
              const SizedBox(height: 16),

              // ── Observación ────────────────────────────
              TextFormField(
                controller: _obsCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                    labelText: 'Observación (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    labelStyle: TextStyle(fontSize: 12))),

              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorContainer(_error!),
              ],

              const SizedBox(height: 28),
              LoadingButton(
                  loading: _loading,
                  onPressed: _repuestoId == null ? null : _submit,
                  label: isEdit ? 'Guardar cambios' : 'Registrar salida'),
            ],
          ),
        ),
      ),
    );
  }
}
