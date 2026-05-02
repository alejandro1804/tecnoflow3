// lib/screens/repuestos/repuestos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class RepuestosScreen extends ConsumerWidget {
  const RepuestosScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        data: (repuestos) => RefreshIndicator(
          onRefresh: () => ref.refresh(repuestosProvider.future),
          child: ListView.builder(
            itemCount: repuestos.length,
            itemBuilder: (_, i) {
              final r = repuestos[i];
              return Card(child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: r.stockBajo ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  child: Icon(r.stockBajo ? Icons.warning_amber_outlined : Icons.check_circle_outline,
                      color: r.stockBajo ? Colors.red : Colors.green)),
                title: Text('${r.codigo} — ${r.descripcion}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (r.ubicacion != null) Text(r.ubicacion!, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(children: [
                    StockBadge(stock: r.stockActual, minimo: r.stockMinimo),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('Mín: ${r.stockMinimo}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
                  ]),
                ]),
                trailing: isAdmin ? IconButton(icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/repuestos/${r.id}')) : null,
              ));
            }),
        )),
    );
  }
}
