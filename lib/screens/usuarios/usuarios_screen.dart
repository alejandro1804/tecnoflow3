// lib/screens/usuarios/usuarios_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Nuevo'),
          onPressed: () => context.push('/usuarios/nuevo')),
      body: usuariosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (usuarios) {
          final ordenados = [...usuarios]
            ..sort((a, b) =>
                a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
          return RefreshIndicator(
            onRefresh: () => ref.refresh(usuariosProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: ordenados.length,
              itemBuilder: (_, i) {
                final u     = ordenados[i];
                final color = u.isAdmin
                    ? Colors.deepPurple
                    : u.isEncargado
                        ? Colors.teal
                        : Colors.blue;

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // ── Avatar ──────────────────────
                        CircleAvatar(
                          backgroundColor: color.withOpacity(0.12),
                          radius: 18,
                          child: Text(
                            u.nombre.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        ),
                        const SizedBox(width: 12),

                        // ── Contenido ───────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // FILA 1: Nombre
                              Text(u.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),

                              // FILA 2: Email
                              Row(children: [
                                const Icon(Icons.email_outlined,
                                    size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(u.email,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                              const SizedBox(height: 4),

                              // FILA 3: Rol + Estado
                              Row(children: [
                                RolBadge(u.rolNombre),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: u.estado == 'activo'
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                      u.estado == 'activo'
                                          ? 'Activo'
                                          : 'Inactivo',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: u.estado == 'activo'
                                              ? Colors.green
                                              : Colors.grey)),
                                ),
                              ]),
                            ],
                          ),
                        ),

                        // ── Ícono editar ─────────────────
                        InkWell(
                          onTap: () => context.push('/usuarios/${u.id}'),
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
