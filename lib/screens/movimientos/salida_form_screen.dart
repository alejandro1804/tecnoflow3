// lib/screens/movimientos/salida_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class SalidaFormScreen extends ConsumerStatefulWidget {
  final SalidaRepuesto? salida;
  final String?         ticketIdInicial;
  final String?         maquinaId;
  final Repuesto?       repuestoPreseleccionado;

  const SalidaFormScreen({
    super.key,
    this.salida,
    this.ticketIdInicial,
    this.maquinaId,
    this.repuestoPreseleccionado,
  });

  @override
  ConsumerState<SalidaFormScreen> createState() => _State();
}

class _State extends ConsumerState<SalidaFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _cantCtrl = TextEditingController(text: '1');
  final _obsCtrl  = TextEditingController();
  final _busqCtrl = TextEditingController();
  final _refCtrl  = TextEditingController();

  String? _repuestoId;
  String? _ticketId;
  String  _busqueda    = '';
  String  _busquedaRef = '';
  bool    _conTicket   = false;
  bool    _loading     = false;
  String? _error;

  List<Repuesto>? _repuestosMaquina;
  bool _cargandoRepuestos = false;

  bool get isEdit      => widget.salida != null;
  bool get desdeTicket => widget.ticketIdInicial != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final s        = widget.salida!;
      _repuestoId    = s.repuestoId;
      _ticketId      = s.ticketId;
      _conTicket     = s.ticketId != null;
      _cantCtrl.text = s.cantidad.toString();
      _obsCtrl.text  = s.observacion ?? '';
      _busqCtrl.text = s.repuestoDescripcion ?? '';
    } else if (widget.repuestoPreseleccionado != null) {
      final r        = widget.repuestoPreseleccionado!;
      _repuestoId    = r.id;
      _busqCtrl.text = r.descripcion;
    } else if (widget.ticketIdInicial != null) {
      _ticketId  = widget.ticketIdInicial;
      _conTicket = true;
    }

    if (widget.maquinaId != null && !isEdit) {
      Future.microtask(() => _cargarRepuestosMaquina());
    }
  }

  Future<void> _cargarRepuestosMaquina() async {
    setState(() => _cargandoRepuestos = true);
    try {
      final items = await ref
          .read(repuestosMaquinasRepoProvider)
          .getByMaquina(widget.maquinaId!);
      final todosRepuestos = ref.read(repuestosProvider).valueOrNull ?? [];
      final idsEnMaquina   = items.map((m) => m.repuestoId).toSet();
      final filtrados = todosRepuestos
          .where((r) => idsEnMaquina.contains(r.id))
          .toList()
        ..sort((a, b) => a.descripcion.compareTo(b.descripcion));
      setState(() {
        _repuestosMaquina  = filtrados.isEmpty ? null : filtrados;
        _cargandoRepuestos = false;
      });
    } catch (e) {
      setState(() => _cargandoRepuestos = false);
    }
  }

  @override
  void dispose() {
    _cantCtrl.dispose(); _obsCtrl.dispose();
    _busqCtrl.dispose(); _refCtrl.dispose();
    super.dispose();
  }

  String _mensajeError(Object e) {
    final msg = e.toString();
    if (msg.contains('Stock insuficiente'))
      return 'Stock insuficiente. Verificá la cantidad disponible.';
    if (msg.contains('violates row-level security'))
      return 'No tenés permisos para realizar esta operación.';
    if (msg.contains('violates foreign key'))
      return 'El repuesto o ticket seleccionado no existe.';
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
          observacion: _obsCtrl.text.trim().isEmpty
              ? null : _obsCtrl.text.trim(),
        );
      } else {
        await ref.read(movimientosRepoProvider).createSalida(
          repuestoId:  _repuestoId!,
          cantidad:    int.parse(_cantCtrl.text),
          ticketId:    _conTicket ? _ticketId : null,
          observacion: _obsCtrl.text.trim().isEmpty
              ? null : _obsCtrl.text.trim(),
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
    final todosRepuestos = ref.watch(repuestosProvider).valueOrNull ?? [];
    final tickets        = ref.watch(ticketsProvider).valueOrNull ?? [];
    final profile        = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin        = profile?.isAdmin ?? false;

    var ticketsFiltrados = isAdmin
        ? tickets.where((t) => t.estado != 'cerrado').toList()
        : tickets.where((t) =>
            t.tecnicoId == profile?.id && t.estado != 'cerrado').toList();

    if (isEdit && _ticketId != null) {
      final yaEsta = ticketsFiltrados.any((t) => t.id == _ticketId);
      if (!yaEsta) {
        final orig = tickets.where((t) => t.id == _ticketId).toList();
        ticketsFiltrados = [...orig, ...ticketsFiltrados];
      }
    }

    final fuenteRepuestos = (_repuestosMaquina != null && !isEdit)
        ? _repuestosMaquina!
        : todosRepuestos;

    // Filtro por REF tiene prioridad
    List<Repuesto> repuestosFiltrados;
    if (_busquedaRef.isNotEmpty) {
      final refNum = int.tryParse(_busquedaRef);
      repuestosFiltrados = refNum != null
          ? fuenteRepuestos.where((r) => r.ref == refNum).toList()
          : [];
    } else {
      repuestosFiltrados = (_busqueda.isEmpty
          ? fuenteRepuestos
          : fuenteRepuestos.where((r) =>
              r.codigo.toLowerCase().contains(_busqueda.toLowerCase()) ||
              r.descripcion.toLowerCase().contains(_busqueda.toLowerCase()))
          .toList())
        ..sort((a, b) => a.descripcion.compareTo(b.descripcion));
    }

    final repuestoFijo = widget.repuestoPreseleccionado;
    final ticketFijo   = desdeTicket
        ? tickets.where((t) => t.id == _ticketId).firstOrNull
        : null;

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

              // ── Repuesto preseleccionado (solo lectura) ──
              if (repuestoFijo != null && !isEdit) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(repuestoFijo.descripcion,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                            'Código: ${repuestoFijo.codigo}  |  Stock: ${repuestoFijo.stockActual}'
                            '${repuestoFijo.ref != null ? '  |  REF: ${repuestoFijo.ref}' : ''}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Buscador de repuesto ──────────────────
              if (repuestoFijo == null || isEdit) ...[
                const Text('REPUESTO', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 4),

                if (_repuestosMaquina != null && !isEdit)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.blue.withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.precision_manufacturing_outlined,
                          size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                          'Repuestos de la máquina del ticket (${_repuestosMaquina!.length})',
                          style: const TextStyle(
                              fontSize: 9, color: Colors.blue)),
                    ]),
                  ),

                if (_cargandoRepuestos)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Buscador texto
                  TextFormField(
                    controller: _busqCtrl,
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                        labelText: 'Buscar por código o descripción',
                        prefixIcon: const Icon(Icons.search),
                        labelStyle: const TextStyle(fontSize: 11),
                        suffixIcon: _repuestoId != null
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null),
                    onChanged: (v) => setState(() {
                      _busqueda    = v;
                      _busquedaRef = '';
                      _refCtrl.clear();
                      _repuestoId  = null;
                    }),
                  ),
                  const SizedBox(height: 8),

                  // Buscador REF
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
                                  _repuestoId  = null;
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
                      _repuestoId  = null;
                    }),
                  ),
                  const SizedBox(height: 4),

                  // Lista resultados
                  if ((_busqueda.isNotEmpty || _busquedaRef.isNotEmpty) &&
                      _repuestoId == null)
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
                                      stock: r.stockActual,
                                      minimo: r.stockMinimo),
                                  title: Text(r.descripcion,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: sinStock
                                              ? Colors.grey : null)),
                                  subtitle: Text(
                                      sinStock
                                          ? 'Sin stock'
                                          : 'Stock: ${r.stockActual}'
                                            '${r.ref != null ? '  •  REF ${r.ref}' : ''}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: sinStock
                                              ? Colors.red : null)),
                                  onTap: sinStock
                                      ? null
                                      : () => setState(() {
                                            _repuestoId    = r.id;
                                            _busqCtrl.text = r.descripcion;
                                            _busqueda      = '';
                                            _busquedaRef   = '';
                                            _refCtrl.clear();
                                          }),
                                );
                              }),
                    ),
                ],
                const SizedBox(height: 16),
              ],

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

              // ── Ticket ────────────────────────────────
              const Text('TICKET', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 8),

              if (desdeTicket && !isEdit) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.grey.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.confirmation_number_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticketFijo != null
                              ? '${ticketFijo.maquinaNombre ?? 'Sin máquina'} — ${ticketFijo.estado}'
                              : 'Ticket asociado',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600)),
                        const Text('Ticket vinculado — no modificable',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    )),
                    const Icon(Icons.lock_outline,
                        size: 14, color: Colors.grey),
                  ]),
                ),
                const SizedBox(height: 16),
              ] else ...[
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
                        prefixIcon:
                            Icon(Icons.confirmation_number_outlined),
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
                    validator: (v) =>
                        (_conTicket && (v == null || v.isEmpty))
                            ? 'Seleccione un ticket' : null),
                ],
                const SizedBox(height: 16),
              ],

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