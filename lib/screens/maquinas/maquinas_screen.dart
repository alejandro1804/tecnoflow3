// lib/screens/maquinas/maquinas_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import 'repuestos_maquina_screen.dart';

class MaquinasScreen extends ConsumerStatefulWidget {
  const MaquinasScreen({super.key});
  @override
  ConsumerState<MaquinasScreen> createState() => _State();
}

class _State extends ConsumerState<MaquinasScreen> {
  String _busqueda  = '';
  String _sectorId  = ''; // '' = todos los sectores

  @override
  Widget build(BuildContext context) {
    final maquinasAsync = ref.watch(maquinasProvider);
    final sectores      = ref.watch(sectoresProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Máquinas')),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add), label: const Text('Nueva'),
          onPressed: () => context.push('/maquinas/nuevo')),
      body: maquinasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data: (todasMaquinas) {
            // Ordenar alfabéticamente
            final maquinas = [...todasMaquinas]
              ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

            // Filtrar por sector
            final porSector = _sectorId.isEmpty
                ? maquinas
                : maquinas.where((m) => m.sectorId == _sectorId).toList();

            // Filtrar por texto
            final filtradas = _busqueda.isEmpty
                ? porSector
                : porSector.where((m) =>
            m.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
                m.codigo.toLowerCase().contains(_busqueda.toLowerCase()) ||
                (m.sectorNombre ?? '').toLowerCase().contains(_busqueda.toLowerCase()))
                .toList();

            return RefreshIndicator(
              onRefresh: () => ref.refresh(maquinasProvider.future),
              child: Column(children: [
                // ── Buscadores ──────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(children: [
                    // Buscador por texto
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o código...',
                        prefixIcon: const Icon(Icons.search, size: 16),
                        suffixIcon: _busqueda.isNotEmpty
                            ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () => setState(() => _busqueda = ''))
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busqueda = v),
                    ),
                    const SizedBox(height: 8),
                    // Filtro por sector
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Chip "Todos"
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: const Text('Todos'),
                              selected: _sectorId.isEmpty,
                              onSelected: (_) => setState(() => _sectorId = ''),
                              selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              labelStyle: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _sectorId.isEmpty
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[700]),
                            ),
                          ),
                          // Chips por sector
                          ...sectores.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(s.nombre),
                              selected: _sectorId == s.id,
                              onSelected: (_) => setState(() => _sectorId = s.id),
                              selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _sectorId == s.id
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey[700]),
                            ),
                          )),
                        ],
                      ),
                    ),
                    // Contador de resultados
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            '${filtradas.length} máquina${filtradas.length != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 1),

                // ── Listado ─────────────────────────────────
                Expanded(
                  child: filtradas.isEmpty
                      ? const Center(child: Text('Sin resultados'))
                      : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filtradas.length,
                      itemBuilder: (_, i) {
                        final m = filtradas[i];
                        final color = m.estado == 'en_reparacion' ? Colors.red
                            : m.estado == 'inactivo' ? Colors.grey : Colors.green;
                        return Card(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CircleAvatar(
                                  backgroundColor: color.withOpacity(0.1),
                                  child: Icon(Icons.precision_manufacturing_outlined, color: color)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10)),
                                Text('${m.codigo} • ${m.sectorNombre ?? 'Sin sector'}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ])),
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(m.estado,
                                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600))),
                              const SizedBox(width: 4),
                              IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 12),
                                  onPressed: () => context.push('/maquinas/${m.id}')),
                            ]),
                            const SizedBox(height: 6),
                            SizedBox(width: double.infinity,
                                child: OutlinedButton.icon(
                                    icon: const Icon(Icons.settings_outlined, size: 12),
                                    label: const Text('Ver / gestionar repuestos'),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        textStyle: const TextStyle(fontSize: 9),
                                        side: BorderSide(color: Colors.blue.withOpacity(0.4)),
                                        foregroundColor: Colors.blue),
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ProviderScope(
                                            parent: ProviderScope.containerOf(context),
                                            child: RepuestosMaquinaScreen(
                                                maquinaId:     m.id,
                                                maquinaNombre: m.nombre)))))),
                          ]),
                        ));
                      }),
                ),
              ]),
            );
          }),
    );
  }
}
