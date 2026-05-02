// lib/screens/movimientos/salidas_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class SalidasScreen extends ConsumerWidget {
  const SalidasScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salidasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Salidas de repuestos')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (salidas) => RefreshIndicator(
          onRefresh: () => ref.refresh(salidasProvider.future),
          child: salidas.isEmpty
              ? const Center(child: Text('Sin salidas registradas'))
              : ListView.builder(
                  itemCount: salidas.length,
                  itemBuilder: (_, i) {
                    final s = salidas[i];
                    return Card(child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFEBEE),
                          child: Icon(Icons.output_outlined, color: Colors.red)),
                      title: Text('${s.repuestoCodigo ?? ''} — ${s.repuestoDescripcion ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Cantidad: ${s.cantidad} • ${s.fecha}'),
                        Text('Ticket: ${s.ticketId.substring(0, 8)}...', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('-${s.cantidad}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 16))),
                    ));
                  }),
        )),
    );
  }
}
