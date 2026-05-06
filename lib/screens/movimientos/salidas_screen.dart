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
  String _busqueda     = '';
  bool   _generandoPdf = false;

  List<SalidaRepuesto> _filtrar(List<SalidaRepuesto> todas) {
    if (_busqueda.isEmpty) return todas;
    return todas.where((s) =>
        (s.repuestoCodigo ?? '').toLowerCase().contains(_busqueda.toLowerCase()) ||
        (s.repuestoDescripcion ?? '').toLowerCase().contains(_busqueda.toLowerCase()))
    .toList();
  }

  Future<void> _exportarPdf(List<SalidaRepuesto> salidas) async {
    setState(() => _generandoPdf = true);
    try {
      await PdfGenerator.generarSalidas(
        salidas:   salidas,
        busqueda:  _busqueda,
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
    final async   = ref.watch(salidasProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final uid     = profile?.id ?? '';
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salidas de repuestos'),
        actions: [
          async.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (todas) {
              final filtradas = _filtrar(todas);
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
                      onPressed: filtradas.isEmpty
                          ? null
                          : () => _exportarPdf(filtradas));
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Nueva salida'),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProviderScope(
                  parent: ProviderScope.containerOf(context),
                  child: const SalidaFormScreen())))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (todas) {
          final salidas = _filtrar(todas);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(salidasProvider.future),
            child: Column(children: [
              // ── Buscador ──────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(children: [
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
                  const SizedBox(height: 6),
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

              // ── Listado ───────────────────────────
              Expanded(
                child: salidas.isEmpty
                    ? const Center(child: Text('Sin resultados'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: salidas.length,
                        itemBuilder: (_, i) {
                          final s       = salidas[i];
                          final esMia   = s.registradoPor == uid;
                          final canEdit = isAdmin || esMia;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 10, 12, 10),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [

                                  // ── Ícono ───────────────
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFFFEBEE),
                                    radius: 18,
                                    child: Icon(Icons.output_outlined,
                                        color: Colors.red, size: 18)),
                                  const SizedBox(width: 12),

                                  // ── Contenido ───────────
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [

                                        // FILA 1: Descripción
                                        Text(
                                          '${s.repuestoCodigo ?? ''} — ${s.repuestoDescripcion ?? ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 10),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),

                                        // FILA 2: Cantidad + Fecha
                                        Row(children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                                color: Colors.red
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        6)),
                                            child: Text('-${s.cantidad}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 12,
                                              color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(s.fecha,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ]),
                                        const SizedBox(height: 4),

                                        // FILA 3: Ticket
                                        Row(children: [
                                          const Icon(
                                              Icons
                                                  .confirmation_number_outlined,
                                              size: 12,
                                              color: Colors.grey),
                                          const SizedBox(width: 4),
                                          s.ticketId != null
                                              ? Text(
                                                  'Ticket: ${s.ticketId!.substring(0, 8)}...',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey))
                                              : const Text(
                                                  'Sin ticket asociado',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.orange)),
                                        ]),

                                        // Observación
                                        if (s.observacion != null) ...[
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            const Icon(Icons.notes_outlined,
                                                size: 12,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(s.observacion!,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                          ]),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // ── Acciones ────────────
                                  if (canEdit) ...[
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          size: 18),
                                      onSelected: (v) {
                                        if (v == 'editar') {
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
                                        } else if (v == 'eliminar') {
                                          _eliminar(context, ref, s);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                            value: 'editar',
                                            child: Row(children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 16),
                                              SizedBox(width: 8),
                                              Text('Editar'),
                                            ])),
                                        const PopupMenuItem(
                                            value: 'eliminar',
                                            child: Row(children: [
                                              Icon(Icons.delete_outline,
                                                  size: 16,
                                                  color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Eliminar',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ])),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
              ),
            ]),
          );
        }),
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
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  'Se devolverán ${s.cantidad} unidad${s.cantidad != 1 ? 'es' : ''} '
                      'de "$repuesto" al stock.',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.green),
                )),
              ]),
            ),
            const SizedBox(height: 8),
            const Text(
              'Solo confirmá si el repuesto fue devuelto físicamente al depósito.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Salida eliminada — ${s.cantidad} unidad${s.cantidad != 1 ? 'es' : ''} devueltas al stock'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    }
  }
}