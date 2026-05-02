// lib/screens/sectores/sectores_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';

class SectoresScreen extends ConsumerWidget {
  const SectoresScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sectoresProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sectores')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: const Text('Nuevo'),
        onPressed: () => context.push('/sectores/nuevo')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (sectores) => RefreshIndicator(
          onRefresh: () => ref.refresh(sectoresProvider.future),
          child: ListView.builder(
            itemCount: sectores.length,
            itemBuilder: (_, i) {
              final s = sectores[i];
              return Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.domain_outlined)),
                title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: s.descripcion != null ? Text(s.descripcion!) : null,
                trailing: IconButton(icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/sectores/${s.id}')),
              ));
            }),
        )),
    );
  }
}
