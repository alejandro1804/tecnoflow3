// lib/screens/repuestos/repuestos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class RepuestosScreen extends ConsumerStatefulWidget {
  final bool soloStockBajo;
  const RepuestosScreen({super.key, this.soloStockBajo = false});

  @override
  ConsumerState<RepuestosScreen> createState() => _State();
}

class _State extends ConsumerState<RepuestosScreen> {
  late bool _soloStockBajo;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _soloStockBajo = widget.soloStockBajo;
  }

  @override
  Widget build(BuildContext context) {
    final async   = ref.watch(repuestosProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Repuestos')),
      floatingActionButton: isAdmin ? FloatingActionButton.extended(
          icon: const Icon(Icons.add), label: const Text('Nuevo'),
          onPressed: () => context.push('/repuestos/nuevo')) : null,
      body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data: (todos) {
            // Filtro stock bajo
            var repuestos = _soloStockBajo
                ? todos.where((r) => r.stockBajo).toList()
                : todos;

            // Filtro por texto
            if (_busqueda.isNotEmpty) {
              repuestos = repuestos.where((r) =>
              r.codigo.toLowerCase().contains(_busqueda.toLowerCase()) ||
                  r.descripcion.toLowerCase().contains(_busqueda.toLowerCase()) ||
                  (r.ubicacion ?? '').toLowerCase().contains(_busqueda.toLowerCase()))
                  .toList();
            }

            final bajosCount = todos.where((r) => r.stockBajo).length;

            return RefreshIndicator(
              onRefresh: () => ref.refresh(repuestosProvider.future),
              child: Column(children: [
                // ── Barra de filtros ─────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(children: [
                    // Buscador
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por código, descripción...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _busqueda.isNotEmpty
                            ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _busqueda = ''))
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busqueda = v),
                    ),
                    const SizedBox(height: 8),
                    // Chips de filtro
                    Row(children: [
                      FilterChip(
                        label: const Text('Todos'),
                        selected: !_soloStockBajo,
                        onSelected: (_) => setState(() => _soloStockBajo = false),
                        selectedColor: Theme.of(context)
                            .colorScheme.primary.withOpacity(0.15),
                        labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
                        onSelected: (_) => setState(() => _soloStockBajo = true),
                        selectedColor: Colors.red.withOpacity(0.12),
                        labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _soloStockBajo ? Colors.red : Colors.grey[700]),
                      ),
                      const Spacer(),
                      Text('${repuestos.length} resultado${repuestos.length != 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                        final r = repuestos[i];
                        return Card(child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                              backgroundColor: r.stockBajo
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              child: Icon(
                                  r.stockBajo
                                      ? Icons.warning_amber_outlined
                                      : Icons.check_circle_outline,
                                  color: r.stockBajo ? Colors.red : Colors.green)),
                          title: Text('${r.codigo} — ${r.descripcion}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (r.ubicacion != null)
                                Text(r.ubicacion!,
                                    style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Row(children: [
                                StockBadge(
                                    stock: r.stockActual,
                                    minimo: r.stockMinimo),
                                const SizedBox(width: 6),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text('Mín: ${r.stockMinimo}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600))),
                              ]),
                            ],
                          ),
                          trailing: isAdmin
                              ? IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  context.push('/repuestos/${r.id}'))
                              : null,
                        ));
                      }),
                ),
              ]),
            );
          }),
    );
  }
}
