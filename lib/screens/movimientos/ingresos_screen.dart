// lib/screens/movimientos/ingresos_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';

class IngresosScreen extends ConsumerWidget {
  const IngresosScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async   = ref.watch(ingresosProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Ingresos de repuestos')),
      floatingActionButton: isAdmin ? FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: const Text('Registrar ingreso'),
        onPressed: () => context.push('/ingresos/nuevo')) : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (ingresos) => RefreshIndicator(
          onRefresh: () => ref.refresh(ingresosProvider.future),
          child: ingresos.isEmpty
              ? const Center(child: Text('Sin ingresos registrados'))
              : ListView.builder(
                  itemCount: ingresos.length,
                  itemBuilder: (_, i) {
                    final ing = ingresos[i];
                    return Card(child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.input_outlined, color: Colors.green)),
                      title: Text('${ing.repuestoCodigo ?? ''} — ${ing.repuestoDescripcion ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Cantidad: ${ing.cantidad} • ${ing.fecha}'),
                        Text('Entrega: ${ing.quienEntrega}', style: const TextStyle(fontSize: 12)),
                        if (ing.descripcion != null)
                          Text(ing.descripcion!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('+${ing.cantidad}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 16))),
                    ));
                  }),
        )),
    );
  }
}
