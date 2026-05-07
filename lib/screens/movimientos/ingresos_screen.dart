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
  String _busqueda     = '';
  bool   _generandoPdf = false;

  List<IngresoRepuesto> _filtrar(List<IngresoRepuesto> todos) {
    if (_busqueda.isEmpty) return todos;
    return todos.where((ing) =>
        (ing.repuestoCodigo ?? '').toLowerCase().contains(_busqueda.toLowerCase()) ||
        (ing.repuestoDescripcion ?? '').toLowerCase().contains(_busqueda.toLowerCase()) ||
        ing.quienEntrega.toLowerCase().contains(_busqueda.toLowerCase()))
    .toList();
  }

  Future<void> _exportarPdf(List<IngresoRepuesto> ingresos) async {
    setState(() => _generandoPdf = true);
    try {
      await PdfGenerator.generarIngresos(
        ingresos: ingresos,
        busqueda: _busqueda,
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
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_outlined,
                    color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Se restarán ${ing.cantidad} unidad${ing.cantidad != 1 ? 'es' : ''} '
                      'de "$repuesto" del stock.',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                )),
              ]),
            ),
            const SizedBox(height: 8),
            const Text(
              'Solo confirmá si el repuesto fue retirado físicamente del depósito.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Ingreso eliminado — ${ing.cantidad} unidad${ing.cantidad != 1 ? 'es' : ''} restadas del stock'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
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
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('DETALLE DE INGRESO', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 12),
            _DetalleRow(Icons.inventory_2_outlined, 'Repuesto',
                ing.repuestoDescripcion ?? '—'),
            _DetalleRow(Icons.qr_code_outlined, 'Código',
                ing.repuestoCodigo ?? '—'),
            _DetalleRow(Icons.numbers_outlined, 'Cantidad',
                '+${ing.cantidad}', color: Colors.green),
            _DetalleRow(Icons.calendar_today_outlined, 'Fecha', ing.fecha),
            _DetalleRow(Icons.person_outline, 'Quien entrega',
                ing.quienEntrega),
            if (ing.descripcion != null)
              _DetalleRow(Icons.notes_outlined, 'Nota', ing.descripcion!),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async   = ref.watch(ingresosProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin     = profile?.isAdmin ?? false;
    final isPaniolero = profile?.isPaniolero ?? false;
    final canEdit     = isAdmin || isPaniolero;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingresos de repuestos'),
        actions: [
          async.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (todos) {
              final filtrados = _filtrar(todos);
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
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ProviderScope(
                      parent: ProviderScope.containerOf(context),
                      child: const IngresoFormScreen()))))
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (todos) {
          final ingresos = _filtrar(todos);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(ingresosProvider.future),
            child: Column(children: [
              // ── Buscador ──────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por código, descripción o quien entrega...',
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
                        '${ingresos.length} resultado${ingresos.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // ── Listado ───────────────────────────
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
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [

                                  // ── Ícono ───────────────
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFE8F5E9),
                                    radius: 18,
                                    child: Icon(Icons.input_outlined,
                                        color: Colors.green, size: 18)),
                                  const SizedBox(width: 12),

                                  // ── Contenido ───────────
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ing.repuestoDescripcion ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 10),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6)),
                                            child: Text('+${ing.cantidad}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w700)),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.calendar_today_outlined,
                                              size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(ing.fecha,
                                              style: const TextStyle(
                                                  fontSize: 12, color: Colors.grey)),
                                        ]),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          const Icon(Icons.person_outline,
                                              size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(ing.quienEntrega,
                                                style: const TextStyle(
                                                    fontSize: 12, color: Colors.grey),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ]),
                                        if (ing.descripcion != null) ...[
                                          const SizedBox(height: 4),
                                          Row(children: [
                                            const Icon(Icons.notes_outlined,
                                                size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(ing.descripcion!,
                                                  style: const TextStyle(
                                                      fontSize: 11, color: Colors.grey),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                          ]),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // ── Acciones ────────────
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Tres puntitos — admin
                                      if (isAdmin|| isPaniolero) ...[
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 18),
                                          onSelected: (v) {
                                            if (v == 'editar') {
                                              Navigator.push(context,
                                                  MaterialPageRoute(
                                                      builder: (_) => ProviderScope(
                                                          parent: ProviderScope.containerOf(context),
                                                          child: IngresoFormScreen(ingreso: ing))));
                                            } else if (v == 'eliminar') {
                                              _eliminar(context, ref, ing);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                                value: 'editar',
                                                child: Row(children: [
                                                  Icon(Icons.edit_outlined, size: 16),
                                                  SizedBox(width: 8),
                                                  Text('Editar'),
                                                ])),
                                            const PopupMenuItem(
                                                value: 'eliminar',
                                                child: Row(children: [
                                                  Icon(Icons.delete_outline,
                                                      size: 16, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Eliminar',
                                                      style: TextStyle(color: Colors.red)),
                                                ])),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      // Ícono ver detalle — todos
                                      InkWell(
                                        onTap: () => _verDetalle(context, ing),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                              color: Colors.teal.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(6)),
                                          child: const Icon(Icons.visibility_outlined,
                                              size: 18, color: Colors.teal),
                                        ),
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
        }),
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
      Text('$label: ', style: const TextStyle(
          fontSize: 12, color: Colors.grey)),
      Expanded(child: Text(value, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: color ?? Colors.black87),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}
