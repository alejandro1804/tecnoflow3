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
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: !_soloStockBajo
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[700]),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.warning_amber_outlined,
                              size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('Stock bajo ($bajosCount)'),
                        ]),
                        selected: _soloStockBajo,
                        onSelected: (_) =>
                            setState(() => _soloStockBajo = true),
                        selectedColor: Colors.red.withOpacity(0.12),
                        labelStyle: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _soloStockBajo
                                ? Colors.red
                                : Colors.grey[700]),
                      ),
                      const Spacer(),
                      Text(
                          '${repuestos.length} resultado${repuestos.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ]),
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

// ── Card de repuesto con panel expandible ─────────────────────
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
          // ── Fila principal ───────────────────────
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              // Thumbnail imagen (si existe)
              if (repuesto.imagenUrl != null) ...[
                RepuestoImagenThumb(
                    imagenUrl: repuesto.imagenUrl, size: 48),
                const SizedBox(width: 8),
              ],
              // Ícono stock
              CircleAvatar(
                  backgroundColor: repuesto.stockBajo
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  child: Icon(
                      repuesto.stockBajo
                          ? Icons.warning_amber_outlined
                          : Icons.check_circle_outline,
                      color: repuesto.stockBajo
                          ? Colors.red
                          : Colors.green)),
            ]),
            title: Text(
                '${repuesto.codigo} — ${repuesto.descripcion}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (repuesto.ubicacion != null)
                  Text(repuesto.ubicacion!,
                      style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  StockBadge(
                      stock: repuesto.stockActual,
                      minimo: repuesto.stockMinimo),
                  const SizedBox(width: 6),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Mín: ${repuesto.stockMinimo}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600))),
                ]),
              ],
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              // Botón expandir máquinas
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.precision_manufacturing_outlined,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Icon(
                        expandido
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16, color: Colors.blue),
                  ]),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 4),
                IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        context.push('/repuestos/${repuesto.id}')),
              ],
            ]),
          ),

          // ── Panel expandible: máquinas ────────────
          if (expandido) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
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
                            color: Colors.red, fontSize: 12))),
                data: (maquinas) {
                  if (maquinas.isEmpty) {
                    return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Text('Sin máquinas asociadas',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)));
                  }

                  final totalUnidades = maquinas.fold<int>(
                      0, (sum, m) => sum + m.cantidad);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MÁQUINAS QUE USAN ESTE REPUESTO',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ...maquinas.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            const Icon(
                                Icons.precision_manufacturing_outlined,
                                size: 14, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.maquinaNombre ?? '—',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                if (m.ubicacionEnMaquina != null)
                                  Text(m.ubicacionEnMaquina!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey)),
                              ],
                            )),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(8)),
                                child: Text('x${m.cantidad}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.teal))),
                          ]),
                        )),
                        const Divider(height: 12),
                        // Total
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total requerido en máquinas:',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey)),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(8)),
                                child: Text('$totalUnidades uds',
                                    style: const TextStyle(
                                        fontSize: 13,
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

