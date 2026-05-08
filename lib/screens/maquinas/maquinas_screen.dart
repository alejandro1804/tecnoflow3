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
  String _busqueda     = '';
  String _sectorId     = '';
  bool   _generandoPdf = false;

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

  @override
  Widget build(BuildContext context) {
    final maquinasAsync = ref.watch(maquinasProvider);
    final sectores      = ref.watch(sectoresProvider).valueOrNull ?? [];

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
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add), label: const Text('Nueva'),
          onPressed: () => context.push('/maquinas/nuevo')),
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

                  // Buscador
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

                  // Dropdown de sectores
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
                          // Opción "Todos"
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
                          // Sectores
                          ...([...sectores]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()))).map((s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Row(children: [
                              Icon(Icons.domain_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary),
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

                  // Contador
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

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // FILA 1: Ícono + Nombre
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
                                  const SizedBox(height: 6),

                                  // FILA 2: Código | Sector
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text(m.codigo,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(children: [
                                      const Icon(Icons.domain_outlined,
                                          size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(m.sectorNombre ?? 'Sin sector',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                    ]),
                                  ]),
                                  const SizedBox(height: 8),

                                  // FILA 3: Estado | Editar | Repuestos
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
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
                                    const Spacer(),
                                    InkWell(
                                      onTap: () =>
                                          context.push('/maquinas/${m.id}'),
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
                                    InkWell(
                                      onTap: () => Navigator.push(context,
                                          MaterialPageRoute(
                                              builder: (_) => ProviderScope(
                                                  parent: ProviderScope
                                                      .containerOf(context),
                                                  child: RepuestosMaquinaScreen(
                                                      maquinaId:     m.id,
                                                      maquinaNombre: m.nombre)))),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: const Icon(Icons.settings_outlined,
                                            size: 18, color: Colors.blue),
                                      ),
                                    ),
                                  ]),
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
