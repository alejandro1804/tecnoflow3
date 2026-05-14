// lib/screens/movimientos/salidas_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets.dart';
import '../../core/PdfGenerator.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'salida_form_screen.dart';

class SalidasScreen extends ConsumerStatefulWidget {
  const SalidasScreen({super.key});

  @override
  ConsumerState<SalidasScreen> createState() => _State();
}

class _State extends ConsumerState<SalidasScreen> {
  String    _busqueda     = '';
  DateTime? _desde;
  DateTime? _hasta;
  bool      _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(salidasProvider));
  }

  // Intenta parsear "dd/MM/yyyy" o "yyyy-MM-dd" (lo que devuelva el modelo)
  DateTime? _parseFecha(String raw) {
    try {
      final p = raw.trim();
      if (p.contains('/')) {
        final parts = p.split('/');
        if (parts.length == 3) {
          return DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } else if (p.contains('-')) {
        final parts = p.split('-');
        if (parts.length == 3) {
          return DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      }
    } catch (_) {}
    return null;
  }

  List<SalidaRepuesto> _filtrar(List<SalidaRepuesto> todas) {
    return todas.where((s) {
      // Filtro texto
      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        final coincide =
            (s.repuestoCodigo ?? '').toLowerCase().contains(q) ||
            (s.repuestoDescripcion ?? '').toLowerCase().contains(q);
        if (!coincide) return false;
      }
      // Filtro cronológico
      if (_desde != null || _hasta != null) {
        final fecha = _parseFecha(s.fecha);
        if (fecha == null) return false;
        if (_desde != null && fecha.isBefore(_desde!)) return false;
        if (_hasta != null &&
            fecha.isAfter(
                _hasta!.add(const Duration(days: 1) - const Duration(microseconds: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _pickFecha({required bool esDesde}) async {
    final inicial = esDesde
        ? (_desde ?? DateTime.now())
        : (_hasta ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('es'),
    );
    if (picked == null) return;
    setState(() {
      if (esDesde) {
        _desde = picked;
        if (_hasta != null && _hasta!.isBefore(picked)) _hasta = null;
      } else {
        _hasta = picked;
        if (_desde != null && _desde!.isAfter(picked)) _desde = null;
      }
    });
  }

  void _limpiarFechas() => setState(() { _desde = null; _hasta = null; });

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _exportarPdf(List<SalidaRepuesto> salidas) async {
    setState(() => _generandoPdf = true);
    try {
      await PdfGenerator.generarSalidas(
          salidas: salidas, busqueda: _busqueda);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  void _verDetalle(BuildContext context, SalidaRepuesto s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                const Text('DETALLE DE SALIDA',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 1)),
                const Spacer(),
                if (s.repuestoRef != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.purple.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.tag,
                          size: 10, color: Colors.purple),
                      const SizedBox(width: 3),
                      Text('REF ${s.repuestoRef}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.purple,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 12),
              _DetalleRow(Icons.inventory_2_outlined, 'Rep',
                  s.repuestoDescripcion ?? '—'),
              _DetalleRow(Icons.qr_code_outlined, 'Código',
                  s.repuestoCodigo ?? '—'),
              _DetalleRow(Icons.numbers_outlined, 'Cantidad',
                  '-${s.cantidad}',
                  color: Colors.red),
              _DetalleRow(
                  Icons.calendar_today_outlined, 'Fecha', s.fecha),
              _DetalleRow(
                  Icons.confirmation_number_outlined,
                  'Ticket',
                  s.ticketId != null
                      ? (s.ticketNumero != null
                          ? 'N° ${s.ticketNumero!}'
                          : '${s.ticketId!.substring(0, 8)}...')
                      : 'Sin ticket asociado'),
              if (s.observacion != null) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),
                const Text('OBSERVACIÓN',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 1)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.grey.withOpacity(0.2))),
                  child: Text(s.observacion!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black87)),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _eliminar(
      BuildContext context, WidgetRef ref, SalidaRepuesto s) async {
    final repuesto =
        '${s.repuestoCodigo ?? ''} — ${s.repuestoDescripcion ?? ''}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar salida'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('¿Eliminar esta salida de repuesto?'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.green.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Se devolverán ${s.cantidad} '
                'unidad${s.cantidad != 1 ? 'es' : ''} '
                'de "$repuesto" al stock.',
                style: const TextStyle(
                    fontSize: 12, color: Colors.green),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar y devolver stock')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(movimientosRepoProvider).deleteSalida(s.id);
      ref.invalidate(salidasProvider);
      ref.invalidate(repuestosProvider);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Salida eliminada — ${s.cantidad} '
                'unidad${s.cantidad != 1 ? 'es' : ''} devueltas al stock'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async       = ref.watch(salidasProvider);
    final profile     = ref.watch(myProfileProvider).valueOrNull;
    final uid         = profile?.id ?? '';
    final isAdmin     = profile?.isAdmin ?? false;
    final isPaniolero = profile?.isPaniolero ?? false;
    final canEdit     = isAdmin || isPaniolero;
    final hayFiltroFecha = _desde != null || _hasta != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salidas de repuestos'),
        actions: [
          async.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (todas) {
                final filtradas = _filtrar(todas);
                return _generandoPdf
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white)))
                    : IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'Exportar PDF',
                        onPressed: filtradas.isEmpty
                            ? null
                            : () => _exportarPdf(filtradas));
              }),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Nueva salida'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProviderScope(
                          parent: ProviderScope.containerOf(context),
                          child: const SalidaFormScreen()))))
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (todas) {
          final salidas = _filtrar(todas);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(salidasProvider.future),
            child: Column(children: [
              // ── Barra de filtros ──────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(children: [

                  // Buscador por texto
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por código o descripción...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _busqueda = ''))
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                  const SizedBox(height: 8),

                  // ── Filtro desde / hasta ──────────────────────────
                  Row(children: [
                    // Botón DESDE
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickFecha(esDesde: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: _desde != null
                                  ? Colors.red.withOpacity(0.06)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _desde != null
                                      ? Colors.red.withOpacity(0.4)
                                      : Colors.grey.shade300)),
                          child: Row(children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13,
                                color: _desde != null
                                    ? Colors.red
                                    : Colors.grey),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _desde != null
                                    ? _formatFecha(_desde!)
                                    : 'Desde',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _desde != null
                                        ? Colors.red.shade700
                                        : Colors.grey),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Separador
                    const Text('—',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 6),

                    // Botón HASTA
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickFecha(esDesde: false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: _hasta != null
                                  ? Colors.red.withOpacity(0.06)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _hasta != null
                                      ? Colors.red.withOpacity(0.4)
                                      : Colors.grey.shade300)),
                          child: Row(children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13,
                                color: _hasta != null
                                    ? Colors.red
                                    : Colors.grey),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _hasta != null
                                    ? _formatFecha(_hasta!)
                                    : 'Hasta',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _hasta != null
                                        ? Colors.red.shade700
                                        : Colors.grey),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),

                    // Botón limpiar fechas
                    if (hayFiltroFecha) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _limpiarFechas,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3))),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),

                  // Contador de resultados
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        '${salidas.length} resultado${salidas.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // ── Lista ─────────────────────────────────────────────
              Expanded(
                child: salidas.isEmpty
                    ? const Center(child: Text('Sin resultados'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: salidas.length,
                        itemBuilder: (_, i) {
                          final s          = salidas[i];
                          final esMia      = s.registradoPor == uid;
                          final canEditItem =
                              isAdmin || isPaniolero || esMia;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 10, 12, 10),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [

                                  // Fila 1: Descripción
                                  Text(s.repuestoDescripcion ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 10),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 8),

                                  // Fila 2: Datos + acciones
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(6)),
                                                child: Text(
                                                    '-${s.cantidad}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight
                                                                .w700)),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                  Icons
                                                      .calendar_today_outlined,
                                                  size: 12,
                                                  color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(s.fecha,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey)),
                                            ]),
                                            const SizedBox(height: 4),
                                            Row(children: [
                                              const Icon(
                                                  Icons
                                                      .confirmation_number_outlined,
                                                  size: 12,
                                                  color: Colors.grey),
                                              const SizedBox(width: 4),
                                              s.ticketId != null
                                                  ? Text(
                                                      s.ticketNumero != null
                                                          ? 'Ticket N° ${s.ticketNumero!}'
                                                          : 'Ticket: ${s.ticketId!.substring(0, 8)}...',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey))
                                                  : const Text(
                                                      'Sin ticket asociado',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .orange)),
                                            ]),
                                            if (s.observacion !=
                                                null) ...[
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                const Icon(
                                                    Icons.notes_outlined,
                                                    size: 12,
                                                    color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                    child: Text(
                                                        s.observacion!,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis)),
                                              ]),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Acciones derecha
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          if (s.repuestoRef != null)
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                              margin:
                                                  const EdgeInsets.only(
                                                      bottom: 4),
                                              decoration: BoxDecoration(
                                                  color: Colors.purple
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(5),
                                                  border: Border.all(
                                                      color: Colors.purple
                                                          .withOpacity(
                                                              0.3))),
                                              child: Text(
                                                  '# ${s.repuestoRef}',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.purple,
                                                      fontWeight:
                                                          FontWeight
                                                              .w800)),
                                            ),
                                          if (canEditItem)
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                  Icons.more_vert,
                                                  size: 18),
                                              onSelected: (v) {
                                                if (v == 'ver') {
                                                  _verDetalle(context, s);
                                                } else if (v ==
                                                    'editar') {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              ProviderScope(
                                                                  parent: ProviderScope
                                                                      .containerOf(
                                                                          context),
                                                                  child:
                                                                      SalidaFormScreen(
                                                                          salida:
                                                                              s))));
                                                } else if (v ==
                                                    'eliminar') {
                                                  _eliminar(
                                                      context, ref, s);
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                    value: 'ver',
                                                    child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .visibility_outlined,
                                                              size: 16,
                                                              color: Colors
                                                                  .teal),
                                                          SizedBox(
                                                              width: 8),
                                                          Text(
                                                              'Ver detalle')
                                                        ])),
                                                const PopupMenuItem(
                                                    value: 'editar',
                                                    child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              size: 16),
                                                          SizedBox(
                                                              width: 8),
                                                          Text('Editar')
                                                        ])),
                                                const PopupMenuItem(
                                                    value: 'eliminar',
                                                    child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 16,
                                                              color: Colors
                                                                  .red),
                                                          SizedBox(
                                                              width: 8),
                                                          Text('Eliminar',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red))
                                                        ])),
                                              ],
                                            ),
                                          if (!canEditItem)
                                            InkWell(
                                              onTap: () =>
                                                  _verDetalle(context, s),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      6),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(
                                                        6),
                                                decoration: BoxDecoration(
                                                    color: Colors.teal
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(6)),
                                                child: const Icon(
                                                    Icons
                                                        .visibility_outlined,
                                                    size: 18,
                                                    color: Colors.teal),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _DetalleRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color?   color;
  const _DetalleRow(this.icon, this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color ?? Colors.black87))),
        ]),
      );
}