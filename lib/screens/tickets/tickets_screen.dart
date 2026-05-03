// lib/screens/tickets/tickets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  final String? filtroInicial;
  const TicketsScreen({super.key, this.filtroInicial});

  @override
  ConsumerState<TicketsScreen> createState() => _State();
}

class _State extends ConsumerState<TicketsScreen> {
  late String _filtroEstado;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _filtroEstado = widget.filtroInicial ?? 'todos';
  }

  // Color e ícono por estado
  Color _colorEstado(String estado) {
    switch (estado) {
      case TicketEstados.abierto:      return Colors.orange;
      case TicketEstados.asignado:     return Colors.blue;
      case TicketEstados.enEjecucion:  return Colors.green;
      case TicketEstados.enEspera:     return Colors.purple;
      case TicketEstados.cerrado:      return Colors.grey;
      default:                         return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async     = ref.watch(ticketsProvider);
    final profile   = ref.watch(myProfileProvider).valueOrNull;
    final canCreate = profile?.isAdmin == true || profile?.isEncargado == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Tickets')),
      floatingActionButton: canCreate ? FloatingActionButton.extended(
          icon: const Icon(Icons.add), label: const Text('Nuevo ticket'),
          onPressed: () => context.push('/tickets/nuevo')) : null,
      body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data: (todos) {
            // Contadores por estado
            final contadores = {
              'todos':                   todos.length,
              TicketEstados.abierto:     todos.where((t) => t.estado == TicketEstados.abierto).length,
              TicketEstados.asignado:    todos.where((t) => t.estado == TicketEstados.asignado).length,
              TicketEstados.enEjecucion: todos.where((t) => t.estado == TicketEstados.enEjecucion).length,
              TicketEstados.enEspera:    todos.where((t) => t.estado == TicketEstados.enEspera).length,
              TicketEstados.cerrado:     todos.where((t) => t.estado == TicketEstados.cerrado).length,
            };

            // Filtro por estado
            var tickets = _filtroEstado == 'todos'
                ? todos
                : todos.where((t) => t.estado == _filtroEstado).toList();

            // Filtro por texto
            if (_busqueda.isNotEmpty) {
              tickets = tickets.where((t) =>
              (t.maquinaNombre ?? '').toLowerCase().contains(_busqueda.toLowerCase()) ||
                  t.descripcionDesperfecto.toLowerCase().contains(_busqueda.toLowerCase()) ||
                  (t.creadoPorNombre ?? '').toLowerCase().contains(_busqueda.toLowerCase()) ||
                  (t.tecnicoNombre ?? '').toLowerCase().contains(_busqueda.toLowerCase()))
                  .toList();
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(ticketsProvider.future),
              child: Column(children: [
                // ── Barra de filtros ─────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(children: [
                    // Buscador
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por máquina, técnico...',
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
                    // Chips de estado
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Chip Todos
                          _FilterChip(
                              label: 'Todos (${contadores['todos']})',
                              selected: _filtroEstado == 'todos',
                              color: Theme.of(context).colorScheme.primary,
                              onTap: () => setState(() => _filtroEstado = 'todos')),
                          const SizedBox(width: 6),
                          // Chips por estado
                          ...[
                            TicketEstados.abierto,
                            TicketEstados.asignado,
                            TicketEstados.enEjecucion,
                            TicketEstados.enEspera,
                            TicketEstados.cerrado,
                          ].map((estado) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _FilterChip(
                                label: '${_labelEstado(estado)} (${contadores[estado]})',
                                selected: _filtroEstado == estado,
                                color: _colorEstado(estado),
                                onTap: () => setState(() => _filtroEstado = estado)),
                          )),
                        ],
                      ),
                    ),
                    // Contador resultados
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            '${tickets.length} ticket${tickets.length != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 1),

                // ── Listado ──────────────────────────────
                Expanded(
                  child: tickets.isEmpty
                      ? Center(child: Text(
                      _filtroEstado == 'todos'
                          ? 'Sin tickets registrados'
                          : 'Sin tickets con estado "${_labelEstado(_filtroEstado)}"'))
                      : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: tickets.length,
                      itemBuilder: (_, i) {
                        final t = tickets[i];
                        return Card(child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          title: Row(children: [
                            Expanded(child: Text(t.maquinaNombre ?? 'Sin máquina',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            EstadoBadge(t.estado),
                          ]),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(t.descripcionDesperfecto,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(t.creadoPorNombre ?? '',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (t.tecnicoNombre != null) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.engineering_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(t.tecnicoNombre!,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ]),
                            ],
                          ),
                          onTap: () => context.push('/tickets/${t.id}'),
                        ));
                      }),
                ),
              ]),
            );
          }),
    );
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case TicketEstados.abierto:      return 'Abierto';
      case TicketEstados.asignado:     return 'Asignado';
      case TicketEstados.enEjecucion:  return 'En ejecución';
      case TicketEstados.enEspera:     return 'En espera';
      case TicketEstados.cerrado:      return 'Cerrado';
      default:                         return estado;
    }
  }
}

// ── Chip de filtro ─────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : Colors.grey[600])),
      ),
    );
  }
}
