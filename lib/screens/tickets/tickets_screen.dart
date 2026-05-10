// lib/screens/tickets/tickets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/PdfGenerator.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

class TicketsScreen extends ConsumerStatefulWidget {
  final String? filtroInicial;
  const TicketsScreen({super.key, this.filtroInicial});

  @override
  ConsumerState<TicketsScreen> createState() => _State();
}

class _State extends ConsumerState<TicketsScreen> {
  late String _filtroEstado;
  String _busqueda     = '';
  bool   _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    _filtroEstado = widget.filtroInicial ?? 'todos';
    Future.microtask(() => ref.invalidate(ticketsProvider));
  }

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

  Future<void> _exportarPdf(List<Ticket> tickets) async {
    setState(() => _generandoPdf = true);
    try {
      await PdfGenerator.generarTickets(
        tickets:      tickets,
        filtroEstado: _filtroEstado,
        busqueda:     _busqueda,
        labelEstado:  _labelEstado,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  List<Ticket> _filtrar(List<Ticket> todos) {
    var lista = _filtroEstado == 'todos'
        ? todos
        : todos.where((t) => t.estado == _filtroEstado).toList();
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      lista = lista.where((t) =>
          (t.maquinaNombre ?? '').toLowerCase().contains(q) ||
          t.descripcionDesperfecto.toLowerCase().contains(q) ||
          (t.creadoPorNombre ?? '').toLowerCase().contains(q) ||
          (t.tecnicoNombre ?? '').toLowerCase().contains(q) ||
          (t.numero ?? '').toLowerCase().contains(q)).toList();
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final async     = ref.watch(ticketsProvider);
    final profile   = ref.watch(myProfileProvider).valueOrNull;
    final canCreate = profile?.isAdmin == true || profile?.isEncargado == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        actions: [
          async.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (todos) {
              final tickets = _filtrar(todos);
              return _generandoPdf
                  ? const Padding(padding: EdgeInsets.all(14),
                      child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      tooltip: 'Exportar PDF',
                      onPressed: tickets.isEmpty
                          ? null : () => _exportarPdf(tickets));
            }),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add), label: const Text('Nuevo ticket'),
              onPressed: () => context.push('/tickets/nuevo'))
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (todos) {
          final contadores = {
            'todos':                   todos.length,
            TicketEstados.abierto:     todos.where((t) => t.estado == TicketEstados.abierto).length,
            TicketEstados.asignado:    todos.where((t) => t.estado == TicketEstados.asignado).length,
            TicketEstados.enEjecucion: todos.where((t) => t.estado == TicketEstados.enEjecucion).length,
            TicketEstados.enEspera:    todos.where((t) => t.estado == TicketEstados.enEspera).length,
            TicketEstados.cerrado:     todos.where((t) => t.estado == TicketEstados.cerrado).length,
          };

          final tickets = _filtrar(todos);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(ticketsProvider.future),
            child: Column(children: [
              // ── Barra de filtros ─────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por máquina, técnico, número...',
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
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                            label: 'Todos (${contadores['todos']})',
                            selected: _filtroEstado == 'todos',
                            color: Theme.of(context).colorScheme.primary,
                            onTap: () =>
                                setState(() => _filtroEstado = 'todos')),
                        const SizedBox(width: 6),
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
                              onTap: () =>
                                  setState(() => _filtroEstado = estado)),
                        )),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          '${tickets.length} ticket${tickets.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // ── Listado ──────────────────────────────
              Expanded(
                child: tickets.isEmpty
                    ? Center(child: Text(_filtroEstado == 'todos'
                        ? 'Sin tickets registrados'
                        : 'Sin tickets con estado "${_labelEstado(_filtroEstado)}"'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: tickets.length,
                        itemBuilder: (_, i) {
                          final t = tickets[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => context.push('/tickets/${t.id}'),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    14, 12, 14, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [

                                    // ── Fila 1: Máquina ──────────
                                    Text(
                                      t.maquinaNombre ?? 'Sin máquina',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11),
                                    ),
                                    const SizedBox(height: 6),

                                    // ── Fila 2: Número + Estado ──
                                    Row(children: [
                                      // Número externo (izquierda)
                                      if (t.numero != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: Colors.indigo
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: Colors.indigo
                                                      .withOpacity(0.3))),
                                          child: Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                          /*  const Icon(Icons.tag,
                                                size: 12,
                                                color: Colors.indigo),  */
                                            const SizedBox(width: 3),
                                            Text(t.numero!,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.indigo,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ]),
                                        )
                                      else
                                        // Placeholder vacío para mantener alineación
                                        const SizedBox.shrink(),
                                      const Spacer(),
                                      // Estado (derecha)
                                      EstadoBadge(t.estado),
                                    ]),
                                    const SizedBox(height: 6),

                                    // ── Fila 3: Personas ─────────
                                    Row(children: [
                                      const Icon(Icons.person_outline,
                                          size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(t.creadoPorNombre ?? '',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      if (t.tecnicoNombre != null) ...[
                                        const SizedBox(width: 12),
                                        const Icon(
                                            Icons.engineering_outlined,
                                            size: 13, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(t.tecnicoNombre!,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey),
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ]),
                                  ],
                                ),
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

// ── Chip de filtro ────────────────────────────────────────────
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
          color: selected
              ? color.withOpacity(0.15)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 1.5),
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

