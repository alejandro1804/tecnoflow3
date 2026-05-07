// lib/screens/repuestos/repuestos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../core/pdfgenerator.dart';
import '../../core/image_viewer.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

class RepuestosScreen extends ConsumerStatefulWidget {
  final bool soloStockBajo;
  const RepuestosScreen({super.key, this.soloStockBajo = false});

  @override
  ConsumerState<RepuestosScreen> createState() => _State();
}

class _State extends ConsumerState<RepuestosScreen> {
  late bool _soloStockBajo;
  String  _busqueda     = '';
  bool    _generandoPdf = false;
  final Set<String> _expandidos = {};

  @override
  void initState() {
    super.initState();
    _soloStockBajo = widget.soloStockBajo;
  }

  List<Repuesto> _filtrar(List<Repuesto> todos) {
    var lista = _soloStockBajo
        ? todos.where((r) => r.stockBajo).toList()
        : todos.toList();
    if (_busqueda.isNotEmpty) {
      lista = lista.where((r) =>
          r.codigo.toLowerCase().contains(_busqueda.toLowerCase()) ||
          r.descripcion.toLowerCase().contains(_busqueda.toLowerCase()) ||
          (r.ubicacion ?? '').toLowerCase().contains(_busqueda.toLowerCase()))
      .toList();
    }
    return lista;
  }

  Future<void> _exportarPdf(List<Repuesto> repuestos) async {
    setState(() => _generandoPdf = true);
    try {
      await PdfGenerator.generarRepuestos(
        repuestos:     repuestos,
        soloStockBajo: _soloStockBajo,
        busqueda:      _busqueda,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async   = ref.watch(repuestosProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repuestos'),
        actions: [
          async.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (todos) {
              final repuestos = _filtrar(todos);
              return _generandoPdf
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      tooltip: 'Exportar PDF',
                      onPressed: repuestos.isEmpty
                          ? null
                          : () => _exportarPdf(repuestos));
            }),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add), label: const Text('Nuevo'),
              onPressed: () => context.push('/repuestos/nuevo'))
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (todos) {
          final repuestos  = _filtrar(todos);
          final bajosCount = todos.where((r) => r.stockBajo).length;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(repuestosProvider.future),
            child: Column(children: [
              // ── Barra de filtros ─────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por código, descripción...',
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
                  Row(children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: !_soloStockBajo,
                      onSelected: (_) =>
                          setState(() => _soloStockBajo = false),
                      selectedColor: Theme.of(context)
                          .colorScheme.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: !_soloStockBajo
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[700]),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.warning_amber_outlined,
                            size: 13, color: Colors.red),
                        const SizedBox(width: 4),
                        Text('Stock bajo ($bajosCount)',
                            style: const TextStyle(fontSize: 11)),
                      ]),
                      selected: _soloStockBajo,
                      onSelected: (_) =>
                          setState(() => _soloStockBajo = true),
                      selectedColor: Colors.red.withOpacity(0.12),
                      labelStyle: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: _soloStockBajo
                              ? Colors.red
                              : Colors.grey[700]),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        '${repuestos.length} resultado${repuestos.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // ── Listado ──────────────────────────────
              Expanded(
                child: repuestos.isEmpty
                    ? Center(child: Text(_soloStockBajo
                        ? 'No hay repuestos con stock bajo'
                        : 'Sin repuestos encontrados'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: repuestos.length,
                        itemBuilder: (_, i) {
                          final r         = repuestos[i];
                          final expandido = _expandidos.contains(r.id);
                          return _RepuestoCard(
                            repuesto:  r,
                            isAdmin:   isAdmin,
                            expandido: expandido,
                            onToggle:  () => setState(() {
                              if (expandido) {
                                _expandidos.remove(r.id);
                              } else {
                                _expandidos.add(r.id);
                                ref.invalidate(
                                    maquinasPorRepuestoProvider(r.id));
                              }
                            }),
                          );
                        }),
              ),
            ]),
          );
        }),
    );
  }
}

// ── Card de repuesto ──────────────────────────────────────────
class _RepuestoCard extends ConsumerWidget {
  final Repuesto     repuesto;
  final bool         isAdmin;
  final bool         expandido;
  final VoidCallback onToggle;

  const _RepuestoCard({
    required this.repuesto,
    required this.isAdmin,
    required this.expandido,
    required this.onToggle,
  });

  void _verDetalle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),

              const Text('DETALLE DE REPUESTO', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 12),

              // ── Foto ─────────────────────────────────
              if (repuesto.imagenUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    repuesto.imagenUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            height: 200,
                            decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12)),
                            child: const Center(
                                child: CircularProgressIndicator())),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined,
                          size: 40, color: Colors.grey[300]),
                      const SizedBox(height: 6),
                      Text('Sin imagen',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Campos ────────────────────────────────
              _DetalleRow(Icons.qr_code_outlined, 'Código', repuesto.codigo),
              _DetalleRow(Icons.description_outlined, 'Descripción',
                  repuesto.descripcion),
              _DetalleRow(Icons.location_on_outlined, 'Ubicación',
                  repuesto.ubicacion ?? '—'),
              const Divider(height: 20),
              _DetalleRow(Icons.inventory_2_outlined, 'Stock actual',
                  repuesto.stockActual.toString(),
                  color: repuesto.stockBajo ? Colors.red : Colors.green),
              _DetalleRow(Icons.warning_amber_outlined, 'Stock mínimo',
                  repuesto.stockMinimo.toString()),
              const SizedBox(height: 8),
              // Badge estado stock
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: repuesto.stockBajo
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      repuesto.stockBajo
                          ? Icons.warning_amber_outlined
                          : Icons.check_circle_outline,
                      size: 14,
                      color: repuesto.stockBajo
                          ? Colors.red : Colors.green),
                  const SizedBox(width: 6),
                  Text(
                      repuesto.stockBajo
                          ? 'Stock bajo — requiere reposición'
                          : 'Stock OK',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: repuesto.stockBajo
                              ? Colors.red : Colors.green)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maquinasAsync = expandido
        ? ref.watch(maquinasPorRepuestoProvider(repuesto.id))
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── FILA 1: Descripción ───────────────
                Row(children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: repuesto.stockBajo
                        ? Colors.red.withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    child: Icon(
                        repuesto.stockBajo
                            ? Icons.warning_amber_outlined
                            : Icons.check_circle_outline,
                        size: 13,
                        color: repuesto.stockBajo
                            ? Colors.red : Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(repuesto.descripcion,
                        style: const TextStyle(
                            fontWeight: FontWeight.w400, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 10),

                // ── FILAS 2 y 3: Foto + Info ──────────
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // Columna izquierda: FOTO
                      SizedBox(
                        width: 90,
                        child: repuesto.imagenUrl != null
                            ? RepuestoImagenThumb(
                                imagenUrl: repuesto.imagenUrl,
                                size: 90)
                            : Container(
                                height: 80,
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.grey.withOpacity(0.2))),
                                child: Icon(Icons.image_outlined,
                                    color: Colors.grey[300], size: 32)),
                      ),
                      const SizedBox(width: 12),

                      // Columna derecha: Info + Acciones
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                            // FILA 2: Ubicación + Stock
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (repuesto.ubicacion != null)
                                  Row(children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(repuesto.ubicacion!,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                    ),
                                  ]),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  StockBadge(
                                      stock: repuesto.stockActual,
                                      minimo: repuesto.stockMinimo),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text(
                                          'Mín: ${repuesto.stockMinimo}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w600))),
                                ]),
                              ],
                            ),

                            // FILA 3: Íconos
                            Row(children: [
                              if (isAdmin) ...[
                                InkWell(
                                  onTap: () => context
                                      .push('/repuestos/${repuesto.id}'),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(6)),
                                    child: const Icon(Icons.edit_outlined,
                                        size: 18, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              // ── Ícono brazo robótico ──
                              InkWell(
                                onTap: onToggle,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.precision_manufacturing_outlined,
                                            size: 18, color: Colors.blue),
                                        const SizedBox(width: 2),
                                        Icon(
                                            expandido
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            size: 14, color: Colors.blue),
                                      ]),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ── Ícono ojo ─────────────
                              InkWell(
                                onTap: () => _verDetalle(context),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      color: Colors.teal.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(
                                      Icons.visibility_outlined,
                                      size: 18, color: Colors.teal),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Panel expandible: máquinas ────────────
          if (expandido) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            if (maquinasAsync == null)
              const SizedBox.shrink()
            else
              maquinasAsync.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, _) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Error: $e',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 10))),
                data: (maquinas) {
                  if (maquinas.isEmpty) {
                    return const Padding(
                        padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Text('Sin máquinas asociadas',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey)));
                  }

                  final totalUnidades = maquinas.fold<int>(
                      0, (sum, m) => sum + m.cantidad);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MÁQUINAS QUE USAN ESTE REPUESTO',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ...maquinas.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            const Icon(
                                Icons.precision_manufacturing_outlined,
                                size: 13, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.maquinaNombre ?? '—',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                                if (m.ubicacionEnMaquina != null)
                                  Text(m.ubicacionEnMaquina!,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey)),
                              ],
                            )),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text('x${m.cantidad}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.teal))),
                          ]),
                        )),
                        const Divider(height: 12),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Total requerido en máquinas:',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey)),
                            const SizedBox(width: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text('$totalUnidades uds',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue))),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

// ── Widget fila de detalle ────────────────────────────────────
class _DetalleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _DetalleRow(this.icon, this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 10),
      Text('$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Expanded(child: Text(value,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: color ?? Colors.black87),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

