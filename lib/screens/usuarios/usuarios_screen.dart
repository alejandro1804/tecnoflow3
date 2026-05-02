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
        data: (usuarios) => RefreshIndicator(
          onRefresh: () => ref.refresh(usuariosProvider.future),
          child: ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (_, i) {
              final u = usuarios[i];
              return Card(child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Text(u.nombre.substring(0,1).toUpperCase(),
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))),
                title: Text(u.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(u.email),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  RolBadge(u.rolNombre),
                  const SizedBox(width: 4),
                  IconButton(icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push('/usuarios/${u.id}')),
                ]),
              ));
            }),
        )),
    );
  }
}
