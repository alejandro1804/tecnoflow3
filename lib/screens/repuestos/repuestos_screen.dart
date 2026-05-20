// lib/screens/repuestos/repuestos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../core/PdfGenerator.dart';
import '../../core/image_viewer.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../movimientos/ingreso_form_screen.dart';
import '../movimientos/salida_form_screen.dart';

class RepuestosScreen extends ConsumerStatefulWidget {
  final bool soloStockBajo;
  const RepuestosScreen({super.key, this.soloStockBajo = false});

  @override
  ConsumerState<RepuestosScreen> createState() => _State();
}

class _State extends ConsumerState<RepuestosScreen> {
  late bool _soloStockBajo;
  String  _busqueda     = '';
  String  _busquedaRef  = '';
  bool    _generandoPdf = false;
  final Set<String> _expandidos = {};
  final _refCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _soloStockBajo = widget.soloStockBajo;
    Future.microtask(() => ref.invalidate(repuestosProvider));
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  List<Repuesto> _filtrar(List<Repuesto> todos) {
    var lista = _soloStockBajo
        ? todos.where((r) => r.stockBajo).toList()
        : todos.toList();

    if (_busquedaRef.isNotEmpty) {
      final refNum = int.tryParse(_busquedaRef);
      if (refNum != null) {
        lista = lista.where((r) => r.ref == refNum).toList();
      }
      return lista;
    }

    if (_busqueda.isNotEmpty) {
      lista = lista.where((r) =>
          (r.codigo ?? '').toLowerCase().contains(_busqueda.toLowerCase()) ||
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
    final async       = ref.watch(repuestosProvider);
    final profile     = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin     = profile?.isAdmin ?? false;
    final isPaniolero = profile?.isPaniolero ?? false;
    final canManage   = isAdmin || isPaniolero;

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
      floatingActionButton: canManage
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

                  TextField(
                    controller: _refCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: 'Buscar por N° REF...',
                      prefixIcon: const Icon(Icons.tag, size: 20,
                          color: Colors.purple),
                      suffixIcon: _busquedaRef.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _refCtrl.clear();
                                setState(() => _busquedaRef = '');
                              })
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: Colors.purple.withOpacity(0.3))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Colors.purple)),
                    ),
                    onChanged: (v) => setState(() => _busquedaRef = v),
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
                            repuesto:    r,
                            isAdmin:     isAdmin,
                            isPaniolero: isPaniolero,
                            expandido:   expandido,
                            onToggle:    () => setState(() {
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
  final bool         isPaniolero;
  final bool         expandido;
  final VoidCallback onToggle;

  const _RepuestoCard({
    required this.repuesto,
    required this.isAdmin,
    required this.isPaniolero,
    required this.expandido,
    required this.onToggle,
  });

  bool get canManage => isAdmin || isPaniolero;

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
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: Text('DETALLE DE REPUESTO', style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.grey, letterSpacing: 1),
                    overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                if (repuesto.ref != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.purple.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.tag, size: 12, color: Colors.purple),
                      const SizedBox(width: 3),
                      Text('REF ${repuesto.ref}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.purple,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 12),

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

              _DetalleRow(Icons.qr_code_outlined, 'Código',
                  repuesto.codigo ?? '—'),
              _DetalleRow(Icons.description_outlined, 'Descripción',
                  repuesto.descripcion),
              _DetalleRow(Icons.straighten_outlined, 'Unidad de medida',
                  repuesto.unidadMedida),
              _DetalleRow(Icons.location_on_outlined, 'Ubicación',
                  repuesto.ubicacion ?? '—'),

              const Divider(height: 20),

              _DetalleRow(Icons.inventory_2_outlined, 'Stock actual',
                  repuesto.stockActual.toString(),
                  color: repuesto.stockBajo ? Colors.red : Colors.green),
              _DetalleRow(Icons.warning_amber_outlined, 'Stock mínimo',
                  repuesto.stockMinimo.toString()),
              const SizedBox(height: 8),
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
                      color: repuesto.stockBajo ? Colors.red : Colors.green),
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

              if (repuesto.notas != null && repuesto.notas!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.amber.withOpacity(0.3))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_outlined,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NOTAS',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber,
                                    letterSpacing: 0.8)),
                            const SizedBox(height: 4),
                            Text(repuesto.notas!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActivo(BuildContext context, WidgetRef ref) async {
    final nuevoEstado = !repuesto.activo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(nuevoEstado ? 'Activar repuesto' : 'Desactivar repuesto'),
        content: Text(
            '¿Querés ${nuevoEstado ? 'activar' : 'desactivar'} "${repuesto.descripcion}"?\n\n'
            '${nuevoEstado ? 'El repuesto volverá a aparecer en el listado.' : 'Dejará de aparecer en el listado pero sus registros históricos se conservan.'}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      nuevoEstado ? Colors.green : Colors.orange),
              onPressed: () => Navigator.pop(context, true),
              child: Text(nuevoEstado ? 'Activar' : 'Desactivar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(repuestosRepoProvider)
          .toggleActivo(repuesto.id, nuevoEstado);
      ref.invalidate(repuestosProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(nuevoEstado
                ? 'Repuesto activado'
                : 'Repuesto desactivado'),
            backgroundColor:
                nuevoEstado ? Colors.green : Colors.orange));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Bottom sheet: asociar nueva máquina ───────────────────
  Future<void> _asociarMaquina(BuildContext context, WidgetRef ref,
      List<RepuestoMaquina> yaAsociadas) async {
    final maquinas = await ref.read(maquinasRepoProvider).getAll();
    final idsYaAsociados = yaAsociadas.map((m) => m.maquinaId).toSet();
    final disponibles =
        maquinas.where((m) => !idsYaAsociados.contains(m.id)).toList();

    if (!context.mounted) return;

    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Todas las máquinas ya están asociadas a este repuesto'),
          backgroundColor: Colors.orange));
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AsociarMaquinaSheet(
        repuesto:    repuesto,
        disponibles: disponibles,
        onGuardado:  () => ref.invalidate(maquinasPorRepuestoProvider(repuesto.id)),
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

                // ── FILA 1: Descripción + REF badge ──
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
                  if (repuesto.ref != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.purple.withOpacity(0.3))),
                      child: Text('# ${repuesto.ref}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.purple,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),

                // ── FILA 2: Foto + Info ───────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: repuesto.imagenUrl != null
                          ? RepuestoImagenThumb(
                              imagenUrl: repuesto.imagenUrl,
                              size: 80)
                          : Container(
                              decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.grey.withOpacity(0.2))),
                              child: Icon(Icons.image_outlined,
                                  color: Colors.grey[300], size: 28)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
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
                                        fontSize: 11, color: Colors.grey)),
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
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    'Mín: ${repuesto.stockMinimo}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w600))),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── FILA 3: Íconos ────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _IconBtn(
                      icon: Icons.visibility_outlined,
                      color: Colors.teal,
                      onTap: () => _verDetalle(context),
                    ),
                    if (canManage)
                      _IconBtn(
                        icon: repuesto.activo
                            ? Icons.toggle_on_outlined
                            : Icons.toggle_off_outlined,
                        color: repuesto.activo
                            ? Colors.green
                            : Colors.orange,
                        onTap: () => _toggleActivo(context, ref),
                      ),
                    if (canManage)
                      _IconBtn(
                        icon: Icons.edit_outlined,
                        color: Colors.grey,
                        onTap: () =>
                            context.push('/repuestos/${repuesto.id}'),
                      ),
                    if (canManage)
                      _IconBtn(
                        icon: Icons.add_circle_outline,
                        color: Colors.green,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => ProviderScope(
                                    parent: ProviderScope
                                        .containerOf(context),
                                    child: IngresoFormScreen(
                                        repuestoPreseleccionado:
                                            repuesto)))),
                      ),
                    if (canManage)
                      _IconBtn(
                        icon: Icons.remove_circle_outline,
                        color: Colors.red,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => ProviderScope(
                                    parent: ProviderScope
                                        .containerOf(context),
                                    child: SalidaFormScreen(
                                        repuestoPreseleccionado:
                                            repuesto)))),
                      ),
                    _IconBtn(
                      icon: expandido
                          ? Icons.precision_manufacturing
                          : Icons.precision_manufacturing_outlined,
                      color: Colors.blue,
                      onTap: onToggle,
                      trailing: Icon(
                          expandido
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 12, color: Colors.blue),
                    ),
                  ],
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
                data: (maquinas) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Encabezado ────────────────
                      const Text('MÁQUINAS QUE USAN ESTE REPUESTO',
                          style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: Colors.grey, letterSpacing: 0.5)),
                      if (canManage) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _asociarMaquina(context, ref, maquinas),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.blue.withOpacity(0.3))),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 12, color: Colors.blue),
                                SizedBox(width: 4),
                                Text('Asociar máquina',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // ── Lista de máquinas ─────────
                      if (maquinas.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('Sin máquinas asociadas',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[500])),
                        )
                      else ...[
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
                                child: Text(
                                    '${maquinas.fold<int>(0, (s, m) => s + m.cantidad)} uds',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Bottom sheet: asociar máquina ─────────────────────────────
class _AsociarMaquinaSheet extends ConsumerStatefulWidget {
  final Repuesto      repuesto;
  final List<Maquina> disponibles;
  final VoidCallback  onGuardado;

  const _AsociarMaquinaSheet({
    required this.repuesto,
    required this.disponibles,
    required this.onGuardado,
  });

  @override
  ConsumerState<_AsociarMaquinaSheet> createState() => _AsociarMaquinaSheetState();
}

class _AsociarMaquinaSheetState extends ConsumerState<_AsociarMaquinaSheet> {
  final _cantCtrl  = TextEditingController(text: '1');
  final _ubicCtrl  = TextEditingController();
  final _obsCtrl   = TextEditingController();
  final _busCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  Maquina? _seleccionada;
  String   _busqueda = '';
  bool     _loading  = false;
  String?  _error;

  @override
  void dispose() {
    _cantCtrl.dispose();
    _ubicCtrl.dispose();
    _obsCtrl.dispose();
    _busCtrl.dispose();
    super.dispose();
  }

  List<Maquina> get _filtradas => _busqueda.isEmpty
      ? widget.disponibles
      : widget.disponibles
          .where((m) =>
              m.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
              m.codigo.toLowerCase().contains(_busqueda.toLowerCase()))
          .toList();

  Future<void> _guardar() async {
    if (_seleccionada == null) {
      setState(() => _error = 'Seleccioná una máquina');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });
    try {
      final rm = RepuestoMaquina(
        id:                 '',
        repuestoId:         widget.repuesto.id,
        maquinaId:          _seleccionada!.id,
        cantidad:           int.tryParse(_cantCtrl.text) ?? 1,
        ubicacionEnMaquina: _ubicCtrl.text.trim().isEmpty
            ? null : _ubicCtrl.text.trim(),
        observacion:        _obsCtrl.text.trim().isEmpty
            ? null : _obsCtrl.text.trim(),
      );
      await ref
          .read(repuestosMaquinasRepoProvider)
          .create(rm, _seleccionada!.id);

      widget.onGuardado();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Máquina "${_seleccionada!.nombre}" asociada correctamente'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Column(
          children: [
            // ── Handle ───────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              ),
            ),

            // ── Título ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                const Icon(Icons.precision_manufacturing_outlined,
                    color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Asociar máquina',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(widget.repuesto.descripcion,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
            ),
            const Divider(height: 1),

            // ── Contenido scrollable ─────────────
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Buscador de máquinas ──
                      TextField(
                        controller: _busCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar máquina...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _busqueda.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _busCtrl.clear();
                                    setState(() => _busqueda = '');
                                  })
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) => setState(() => _busqueda = v),
                      ),
                      const SizedBox(height: 8),

                      // ── Lista de máquinas ─────
                      if (filtradas.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text('Sin resultados',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12)),
                          ),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(10)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtradas.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final m = filtradas[i];
                                final sel = _seleccionada?.id == m.id;
                                return ListTile(
                                  dense: true,
                                  selected: sel,
                                  selectedTileColor:
                                      Colors.blue.withOpacity(0.08),
                                  leading: Icon(
                                      Icons.precision_manufacturing_outlined,
                                      size: 18,
                                      color: sel
                                          ? Colors.blue
                                          : Colors.grey),
                                  title: Text(m.nombre,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: sel
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: sel
                                              ? Colors.blue
                                              : Colors.black87)),
                                  subtitle: Text(m.codigo,
                                      style: const TextStyle(fontSize: 10)),
                                  trailing: sel
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.blue, size: 16)
                                      : null,
                                  onTap: () =>
                                      setState(() => _seleccionada = m),
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // ── Cantidad ──────────────
                      TextFormField(
                        controller: _cantCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Cantidad',
                            prefixIcon:
                                Icon(Icons.numbers_outlined)),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          if ((int.tryParse(v) ?? 0) < 1) {
                            return 'Debe ser mayor a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── Ubicación en máquina ──
                      TextFormField(
                        controller: _ubicCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Ubicación en máquina (opcional)',
                            hintText: 'Ej: eje principal, polea tensora...',
                            prefixIcon:
                                Icon(Icons.location_on_outlined)),
                      ),
                      const SizedBox(height: 12),

                      // ── Observación ───────────
                      TextFormField(
                        controller: _obsCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Observación (opcional)',
                            prefixIcon: Icon(Icons.notes_outlined),
                            alignLabelWithHint: true),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        ErrorContainer(_error!),
                      ],
                      const SizedBox(height: 20),

                      // ── Botón guardar ─────────
                      LoadingButton(
                        loading: _loading,
                        onPressed: _guardar,
                        label: 'Asociar máquina',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ícono botón reutilizable ──────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final Widget?      trailing;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6)),
      child: trailing == null
          ? Icon(icon, size: 20, color: color)
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: color),
              trailing!,
            ]),
    ),
  );
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