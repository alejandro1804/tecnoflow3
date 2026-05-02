// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync   = ref.watch(myProfileProvider);
    final repuestosAsync = ref.watch(repuestosProvider);
    final ticketsAsync   = ref.watch(ticketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppStrings.btnLogout,
            onPressed: () async {
              await ref.read(authRepoProvider).signOut();
              if (context.mounted) context.go('/login');
            }),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Sin perfil'));
          final isAdmin     = profile.isAdmin;
          final isTecnico   = profile.isTecnico;

          // Alertas de stock bajo — solo admin
          final repuestosBajo = repuestosAsync.valueOrNull
              ?.where((r) => r.stockBajo).toList() ?? [];

          // Tickets abiertos — solo admin
          final ticketsAbiertos = ticketsAsync.valueOrNull
              ?.where((t) => t.estado == TicketEstados.abierto).toList() ?? [];

          return ListView(padding: const EdgeInsets.all(16), children: [
            // Tarjeta bienvenida
            Card(child: Padding(padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  radius: 28,
                  child: Text(profile.nombre.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bienvenido', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  Text(profile.nombre,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  RolBadge(profile.rolNombre),
                ])),
              ]))),
            const SizedBox(height: 16),

            // Alertas stock bajo — solo admin
            if (repuestosBajo.isNotEmpty && isAdmin)
              Card(
                color: Colors.red[50],
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                  title: Text('${repuestosBajo.length} repuesto(s) con stock bajo',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
                  subtitle: const Text('Requieren reposición urgente'),
                  onTap: () => context.push('/repuestos'),
                )),

            // Tickets abiertos — solo admin
            if (ticketsAbiertos.isNotEmpty && isAdmin)
              Card(
                color: Colors.orange[50],
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.assignment_late_outlined, color: Colors.orange, size: 32),
                  title: Text('${ticketsAbiertos.length} ticket(s) sin asignar',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.orange)),
                  subtitle: const Text('Pendientes de asignación'),
                  onTap: () => context.push('/tickets'),
                )),

            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text('MÓDULOS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey, letterSpacing: 1))),

            // Tickets — visible para todos
            _MenuCard(icon: Icons.confirmation_number_outlined, title: 'Tickets',
                subtitle: 'Gestión de órdenes de trabajo', color: Colors.orange,
                onTap: () => context.push('/tickets')),

            // Repuestos — solo admin y técnico
            if (isAdmin || isTecnico)
              _MenuCard(icon: Icons.inventory_2_outlined, title: 'Repuestos',
                  subtitle: 'Stock y catálogo de repuestos', color: Colors.blue,
                  onTap: () => context.push('/repuestos')),

            // Todo lo demás — solo admin
            if (isAdmin) ...[
              _MenuCard(icon: Icons.input_outlined, title: 'Ingresos',
                  subtitle: 'Registro de ingresos de stock', color: Colors.green,
                  onTap: () => context.push('/ingresos')),
              _MenuCard(icon: Icons.output_outlined, title: 'Salidas',
                  subtitle: 'Historial de salidas de repuestos', color: Colors.red,
                  onTap: () => context.push('/salidas')),
              _MenuCard(icon: Icons.precision_manufacturing_outlined, title: 'Máquinas',
                  subtitle: 'Gestión de máquinas de la planta', color: Colors.teal,
                  onTap: () => context.push('/maquinas')),
              _MenuCard(icon: Icons.domain_outlined, title: 'Sectores',
                  subtitle: 'Sectores de la planta', color: Colors.indigo,
                  onTap: () => context.push('/sectores')),
              _MenuCard(icon: Icons.people_outline, title: 'Usuarios',
                  subtitle: 'Gestión de usuarios del sistema', color: Colors.purple,
                  onTap: () => context.push('/usuarios')),
            ],
          ]);
        }),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
