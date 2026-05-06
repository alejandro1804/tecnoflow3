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
        data: (sectores) {
          final ordenados = [...sectores]
            ..sort((a, b) =>
                a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

          return RefreshIndicator(
            onRefresh: () => ref.refresh(sectoresProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: ordenados.length,
              itemBuilder: (_, i) {
                final s = ordenados[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // ── Ícono ─────────────────────────
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.indigo.withOpacity(0.1),
                          child: const Icon(Icons.domain_outlined,
                              color: Colors.indigo, size: 18)),
                        const SizedBox(width: 12),

                        // ── Contenido ─────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // FILA 1: Nombre del sector
                              Text(s.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),

                              // FILA 2: Descripción (si existe)
                              if (s.descripcion != null) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.notes_outlined,
                                      size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(s.descripcion!,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),

                        // ── Ícono editar ──────────────────
                        InkWell(
                          onTap: () => context.push('/sectores/${s.id}'),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.edit_outlined,
                                size: 18, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          );
        }),
    );
  }
}
