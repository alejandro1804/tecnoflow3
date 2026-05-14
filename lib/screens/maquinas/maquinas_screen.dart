// lib/screens/maquinas/maquinas_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/PdfGenerator.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'repuestos_maquina_screen.dart';

class MaquinasScreen extends ConsumerStatefulWidget {
  const MaquinasScreen({super.key});
  @override
  ConsumerState<MaquinasScreen> createState() => _State();
}

class _State extends ConsumerState<MaquinasScreen> {
  String _busqueda      = '';
  String _sectorId      = '';
  bool   _generandoPdf  = false;
  String? _generandoQr; // id de la máquina cuyo QR se está generando

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(maquinasProvider));
  }

  Future<void> _exportarPdf(List<Maquina> maquinas, String sectorNombre) async {
    setState(() => _generandoPdf = true);
    try {
      await PdfGenerator.generarMaquinas(
        maquinas:     maquinas,
        busqueda:     _busqueda,
        sectorNombre: sectorNombre,
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

  Future<void> _generarQr(Maquina maquina) async {
    setState(() => _generandoQr = maquina.id);
    try {
      // Cargar repuestos asociados a esta máquina
      final repuestos = await ref
          .read(repuestosMaquinasRepoProvider)
          .getByMaquina(maquina.id);

      await PdfGenerator.generarQrMaquina(
        maquina:   maquina,
        repuestos: repuestos,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al generar QR: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _generandoQr = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maquinasAsync = ref.watch(maquinasProvider);
    final sectores      = ref.watch(sectoresProvider).valueOrNull ?? [];
    final profile       = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin       = profile?.isAdmin ?? false;
    final isPaniolero   = profile?.isPaniolero ?? false;
    final canManage     = isAdmin || isPaniolero;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Máquinas'),
        actions: [
          maquinasAsync.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (todasMaquinas) {
              final maquinas = [...todasMaquinas]
                ..sort((a, b) => a.nombre.toLowerCase()
                    .compareTo(b.nombre.toLowerCase()));
              final porSector = _sectorId.isEmpty
                  ? maquinas
                  : maquinas.where((m) => m.sectorId == _sectorId).toList();
              final filtradas = _busqueda.isEmpty
                  ? porSector
                  : porSector.where((m) =>
                      m.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
                      m.codigo.toLowerCase().contains(_busqueda.toLowerCase()) ||
                      (m.sectorNombre ?? '').toLowerCase()
                          .contains(_busqueda.toLowerCase()))
                  .toList();
              final sectorNombre = _sectorId.isEmpty
                  ? 'Todos los sectores'
                  : sectores.firstWhere((s) => s.id == _sectorId,
                      orElse: () => sectores.first).nombre;

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
                          : () => _exportarPdf(filtradas, sectorNombre));
            }),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add), label: const Text('Nueva'),
              onPressed: () => context.push('/maquinas/nuevo'))
          : null,
      body: maquinasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (todasMaquinas) {
          final maquinas = [...todasMaquinas]
            ..sort((a, b) => a.nombre.toLowerCase()
                .compareTo(b.nombre.toLowerCase()));

          final porSector = _sectorId.isEmpty
              ? maquinas
              : maquinas.where((m) => m.sectorId == _sectorId).toList();

          final filtradas = _busqueda.isEmpty
              ? porSector
              : porSector.where((m) =>
                  m.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
                  m.codigo.toLowerCase().contains(_busqueda.toLowerCase()) ||
                  (m.sectorNombre ?? '').toLowerCase()
                      .contains(_busqueda.toLowerCase()))
              .toList();

          final sectorNombre = _sectorId.isEmpty
              ? 'Todos los sectores'
              : sectores.firstWhere((s) => s.id == _sectorId,
                  orElse: () => sectores.first).nombre;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(maquinasProvider.future),
            child: Column(children: [
              // ── Barra de filtros ──────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o código...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
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

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _sectorId.isEmpty ? '' : _sectorId,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            size: 18, color: Colors.grey),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87),
                        items: [
                          DropdownMenuItem<String>(
                            value: '',
                            child: Row(children: [
                              const Icon(Icons.domain_outlined,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text('Todos los sectores',
                                  style: TextStyle(fontSize: 12)),
                            ]),
                          ),
                          ...([...sectores]..sort((a, b) => a.nombre
                                  .toLowerCase()
                                  .compareTo(b.nombre.toLowerCase())))
                              .map((s) => DropdownMenuItem<String>(
                                value: s.id,
                                child: Row(children: [
                                  Icon(Icons.domain_outlined,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(s.nombre,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                ]),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _sectorId = v ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        '${filtradas.length} máquina${filtradas.length != 1 ? 's' : ''}'
                        '${_sectorId.isNotEmpty ? ' en $sectorNombre' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // ── Listado ───────────────────────────────
              Expanded(
                child: filtradas.isEmpty
                    ? const Center(child: Text('Sin resultados'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filtradas.length,
                        itemBuilder: (_, i) {
                          final m     = filtradas[i];
                          final color = m.estado == 'en_reparacion'
                              ? Colors.red
                              : m.estado == 'inactivo'
                                  ? Colors.grey
                                  : Colors.green;
                          final generandoEsteQr = _generandoQr == m.id;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // FILA 1: Nombre
                                  Row(children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: color.withOpacity(0.1),
                                      child: Icon(
                                          Icons.precision_manufacturing_outlined,
                                          color: color, size: 18)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(m.nombre,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),

                                  // FILA 2: Foto + Info
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Miniatura
                                      SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: m.imagenUrl != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  m.imagenUrl!,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (_, child, progress) =>
                                                      progress == null
                                                          ? child
                                                          : Container(
                                                              decoration: BoxDecoration(
                                                                  color: Colors.grey[100],
                                                                  borderRadius: BorderRadius.circular(8)),
                                                              child: const Center(
                                                                  child: CircularProgressIndicator(strokeWidth: 2))),
                                                  errorBuilder: (_, __, ___) =>
                                                      _SinImagen(color: color),
                                                ))
                                            : _SinImagen(color: color),
                                      ),
                                      const SizedBox(width: 12),

                                      // Datos
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: Colors.grey.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6)),
                                                child: Text(m.codigo,
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                        fontWeight: FontWeight.w600)),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Row(children: [
                                                  const Icon(Icons.domain_outlined,
                                                      size: 12, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                        m.sectorNombre ?? 'Sin sector',
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey),
                                                        overflow: TextOverflow.ellipsis),
                                                  ),
                                                ]),
                                              ),
                                            ]),
                                            const SizedBox(height: 6),

                                            if (m.descripcion != null &&
                                                m.descripcion!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 6),
                                                child: Text(m.descripcion!,
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis),
                                              ),

                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                  color: color.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: color.withOpacity(0.3))),
                                              child: Text(
                                                  m.estado == 'en_reparacion'
                                                      ? 'En reparación'
                                                      : m.estado == 'inactivo'
                                                          ? 'Inactivo'
                                                          : 'Activo',
                                                  style: TextStyle(
                                                      color: color,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // FILA 3: Acciones
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Botón QR
                                      generandoEsteQr
                                          ? const SizedBox(
                                              width: 34, height: 34,
                                              child: Center(
                                                  child: SizedBox(
                                                      width: 18, height: 18,
                                                      child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.teal))))
                                          : _IconBtn(
                                              icon: Icons.qr_code_outlined,
                                              color: Colors.teal,
                                              tooltip: 'Generar QR',
                                              onTap: () => _generarQr(m),
                                            ),
                                      const SizedBox(width: 8),

                                      if (canManage) ...[
                                        _IconBtn(
                                          icon: Icons.edit_outlined,
                                          color: Colors.grey,
                                          tooltip: 'Editar',
                                          onTap: () => context.push('/maquinas/${m.id}'),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      _IconBtn(
                                        icon: Icons.settings_outlined,
                                        color: Colors.blue,
                                        tooltip: 'Repuestos',
                                        onTap: () => Navigator.push(context,
                                            MaterialPageRoute(
                                                builder: (_) => ProviderScope(
                                                    parent: ProviderScope
                                                        .containerOf(context),
                                                    child: RepuestosMaquinaScreen(
                                                        maquinaId:     m.id,
                                                        maquinaNombre: m.nombre)))),
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

// ── Placeholder sin imagen ────────────────────────────────────
class _SinImagen extends StatelessWidget {
  final Color color;
  const _SinImagen({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15))),
    child: Icon(Icons.precision_manufacturing_outlined,
        color: color.withOpacity(0.4), size: 28),
  );
}

// ── Ícono botón ───────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final String?      tooltip;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 20, color: color),
      ),
    ),
  );
}
