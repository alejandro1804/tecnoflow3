// lib/screens/movimientos/ingresos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/PdfGenerator.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'ingreso_form_screen.dart';

class IngresosScreen extends ConsumerStatefulWidget {
  const IngresosScreen({super.key});

  @override
  ConsumerState<IngresosScreen> createState() => _State();
}

class _State extends ConsumerState<IngresosScreen> {
  String    _busqueda     = '';
  DateTime? _desde;
  DateTime? _hasta;
  bool      _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(ingresosProvider));
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

  List<IngresoRepuesto> _filtrar(List<IngresoRepuesto> todos) {
    return todos.where((ing) {
      // Filtro texto
      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        final coincide =
            (ing.repuestoCodigo ?? '').toLowerCase().contains(q) ||
            (ing.repuestoDescripcion ?? '').toLowerCase().contains(q) ||
            ing.quienEntrega.toLowerCase().contains(q);
        if (!coincide) return false;
      }
      // Filtro cronológico
      if (_desde != null || _hasta != null) {
        final fecha = _parseFecha(ing.fecha);
        if (fecha == null) return false;
        if (_desde != null && fecha.isBefore(_desde!)) return false;
        if (_hasta != null &&
            fecha.isAfter(_hasta!.add(const Duration(days: 1) - const Duration(microseconds: 1)))) {
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
        // Si "hasta" queda antes de "desde", la limpiamos
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

  Future<void> _exportarPdf(List<IngresoRepuesto> ingresos) async {
    setState(() => _generandoPdf = true);
    try {
      await PdfGenerator.generarIngresos(
          ingresos: ingresos, busqueda: _busqueda);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  Future<void> _eliminar(
      BuildContext context, WidgetRef ref, IngresoRepuesto ing) async {
    final repuesto =
        '${ing.repuestoCodigo ?? ''} — ${ing.repuestoDescripcion ?? ''}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ingreso'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('¿Eliminar este ingreso de repuesto?'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.warning_amber_outlined,
                  color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Se restarán ${ing.cantidad} '
                'unidad${ing.cantidad != 1 ? 'es' : ''} de "$repuesto" del stock.',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              )),
            ]),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar y restar stock')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(movimientosRepoProvider).deleteIngreso(ing.id);
      ref.invalidate(ingresosProvider);
      ref.invalidate(repuestosProvider);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Ingreso eliminado — ${ing.cantidad} '
                'unidad${ing.cantidad != 1 ? 'es' : ''} restadas del stock'),
            backgroundColor: Colors.red));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _verDetalle(BuildContext context, IngresoRepuesto ing) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
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
            const Text('DETALLE DE INGRESO',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                    letterSpacing: 1)),
            const Spacer(),
            if (ing.repuestoRef != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.purple.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.tag, size: 11, color: Colors.purple),
                  const SizedBox(width: 3),
                  Text('REF ${ing.repuestoRef}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.purple,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          _DetalleRow(
              Icons.inventory_2_outlined, 'Repuesto', ing.repuestoDescripcion ?? '—'),
          _DetalleRow(Icons.qr_code_outlined, 'Código', ing.repuestoCodigo ?? '—'),
          _DetalleRow(Icons.numbers_outlined, 'Cantidad', '+${ing.cantidad}',
              color: Colors.green),
          _DetalleRow(Icons.calendar_today_outlined, 'Fecha', ing.fecha),
          _DetalleRow(Icons.person_outline, 'Quien entrega', ing.quienEntrega),
          if (ing.descripcion != null)
            _DetalleRow(Icons.notes_outlined, 'Nota', ing.descripcion!),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async       = ref.watch(ingresosProvider);
    final profile     = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin     = profile?.isAdmin ?? false;
    final isPaniolero = profile?.isPaniolero ?? false;
    final canEdit     = isAdmin || isPaniolero;
    final hayFiltroFecha = _desde != null || _hasta != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresos de repuestos'),
        actions: [
          async.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (todos) {
                final filtrados = _filtrar(todos);
                return _generandoPdf
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)))
                    : IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'Exportar PDF',
                        onPressed: filtrados.isEmpty
                            ? null
                            : () => _exportarPdf(filtrados));
              }),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Registrar ingreso'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProviderScope(
                          parent: ProviderScope.containerOf(context),
                          child: const IngresoFormScreen()))))
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (todos) {
          final ingresos = _filtrar(todos);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(ingresosProvider.future),
            child: Column(children: [
              // ── Barra de filtros ──────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(children: [

                  // Buscador por texto
                  TextField(
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por código, descripción o quien entrega...',
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
                                  ? Colors.green.withOpacity(0.07)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _desde != null
                                      ? Colors.green.withOpacity(0.4)
                                      : Colors.grey.shade300)),
                          child: Row(children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13,
                                color: _desde != null
                                    ? Colors.green
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
                                        ? Colors.green.shade700
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
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
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
                                  ? Colors.green.withOpacity(0.07)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _hasta != null
                                      ? Colors.green.withOpacity(0.4)
                                      : Colors.grey.shade300)),
                          child: Row(children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13,
                                color: _hasta != null
                                    ? Colors.green
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
                                        ? Colors.green.shade700
                                        : Colors.grey),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),

                    // Botón limpiar fechas (solo si hay alguna activa)
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
                        '${ingresos.length} resultado${ingresos.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // ── Lista ─────────────────────────────────────────────
              Expanded(
                child: ingresos.isEmpty
                    ? const Center(child: Text('Sin resultados'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: ingresos.length,
                        itemBuilder: (_, i) {
                          final ing = ingresos[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // Fila 1: Descripción
                                  Text(ing.repuestoDescripcion ?? '',
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
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                                child: Text('+${ing.cantidad}',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.green,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                  Icons.calendar_today_outlined,
                                                  size: 12,
                                                  color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(ing.fecha,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey)),
                                            ]),
                                            const SizedBox(height: 4),
                                            Row(children: [
                                              const Icon(Icons.person_outline,
                                                  size: 12,
                                                  color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                  child: Text(ing.quienEntrega,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                            ]),
                                            if (ing.descripcion != null) ...[
                                              const SizedBox(height: 4),
                                              Row(children: [
                                                const Icon(
                                                    Icons.notes_outlined,
                                                    size: 12,
                                                    color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                    child: Text(
                                                        ing.descripcion!,
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color:
                                                                Colors.grey),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
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
                                          if (ing.repuestoRef != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              margin: const EdgeInsets.only(
                                                  bottom: 4),
                                              decoration: BoxDecoration(
                                                  color: Colors.purple
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  border: Border.all(
                                                      color: Colors.purple
                                                          .withOpacity(0.3))),
                                              child: Text(
                                                  '# ${ing.repuestoRef}',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.purple,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ),
                                          if (canEdit)
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                  Icons.more_vert,
                                                  size: 18),
                                              onSelected: (v) {
                                                if (v == 'ver') {
                                                  _verDetalle(context, ing);
                                                } else if (v == 'editar') {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              ProviderScope(
                                                                  parent: ProviderScope
                                                                      .containerOf(
                                                                          context),
                                                                  child:
                                                                      IngresoFormScreen(
                                                                          ingreso:
                                                                              ing))));
                                                } else if (v == 'eliminar') {
                                                  _eliminar(context, ref, ing);
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                    value: 'ver',
                                                    child: Row(children: [
                                                      Icon(
                                                          Icons
                                                              .visibility_outlined,
                                                          size: 16,
                                                          color: Colors.teal),
                                                      SizedBox(width: 8),
                                                      Text('Ver detalle')
                                                    ])),
                                                const PopupMenuItem(
                                                    value: 'editar',
                                                    child: Row(children: [
                                                      Icon(
                                                          Icons.edit_outlined,
                                                          size: 16),
                                                      SizedBox(width: 8),
                                                      Text('Editar')
                                                    ])),
                                                const PopupMenuItem(
                                                    value: 'eliminar',
                                                    child: Row(children: [
                                                      Icon(
                                                          Icons.delete_outline,
                                                          size: 16,
                                                          color: Colors.red),
                                                      SizedBox(width: 8),
                                                      Text('Eliminar',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red))
                                                    ])),
                                              ],
                                            ),
                                          if (!canEdit)
                                            InkWell(
                                              onTap: () =>
                                                  _verDetalle(context, ing),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                    color: Colors.teal
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                                child: const Icon(
                                                    Icons.visibility_outlined,
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
                      color: color ?? Colors.black87),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}