// lib/screens/maquinas/maquinas_screen.dart
// REEMPLAZAR el archivo completo con este
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import 'repuestos_maquina_screen.dart';

class MaquinasScreen extends ConsumerWidget {
  const MaquinasScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(maquinasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Máquinas')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: const Text('Nueva'),
        onPressed: () => context.push('/maquinas/nuevo')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (maquinas) => RefreshIndicator(
          onRefresh: () => ref.refresh(maquinasProvider.future),
          child: ListView.builder(
            itemCount: maquinas.length,
            itemBuilder: (_, i) {
              final m = maquinas[i];
              final color = m.estado == 'en_reparacion' ? Colors.red
                  : m.estado == 'inactivo' ? Colors.grey : Colors.green;
              return Card(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Fila principal
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Icon(Icons.precision_manufacturing_outlined, color: color)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('${m.codigo} • ${m.sectorNombre ?? 'Sin sector'}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ])),
                    // Badge estado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(m.estado,
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 4),
                    // Editar máquina
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => context.push('/maquinas/${m.id}')),
                  ]),
                  const SizedBox(height: 8),
                  // Botón repuestos
                  SizedBox(width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      label: const Text('Ver / gestionar repuestos'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                        side: BorderSide(color: Colors.blue.withOpacity(0.4)),
                        foregroundColor: Colors.blue),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProviderScope(
                          parent: ProviderScope.containerOf(context),
                          child: RepuestosMaquinaScreen(
                            maquinaId:     m.id,
                            maquinaNombre: m.nombre))))),
                  ),
                ]),
              ));
            }),
        )),
    );
  }
}
