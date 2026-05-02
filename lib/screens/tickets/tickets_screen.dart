// lib/screens/tickets/tickets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async   = ref.watch(ticketsProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final canCreate = profile?.isAdmin == true || profile?.isEncargado == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Tickets')),
      floatingActionButton: canCreate ? FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: const Text('Nuevo ticket'),
        onPressed: () => context.push('/tickets/nuevo')) : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (tickets) => RefreshIndicator(
          onRefresh: () => ref.refresh(ticketsProvider.future),
          child: tickets.isEmpty
              ? const Center(child: Text('Sin tickets registrados'))
              : ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (_, i) {
                    final t = tickets[i];
                    return Card(child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Row(children: [
                        Expanded(child: Text(t.maquinaNombre ?? 'Sin máquina',
                            style: const TextStyle(fontWeight: FontWeight.w700))),
                        EstadoBadge(t.estado),
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 4),
                        Text(t.descripcionDesperfecto, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(t.creadoPorNombre ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (t.tecnicoNombre != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.engineering_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(t.tecnicoNombre!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ]),
                      ]),
                      onTap: () => context.push('/tickets/${t.id}'),
                    ));
                  }),
        )),
    );
  }
}
