// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';
import '../repuestos/repuestos_screen.dart';

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
          final isPaniolero = profile.isPaniolero;

          final repuestosBajo = repuestosAsync.valueOrNull
              ?.where((r) => r.stockBajo).toList() ?? [];

          final ticketsAbiertos = ticketsAsync.valueOrNull
              ?.where((t) => t.estado == TicketEstados.abierto).toList() ?? [];

          // Tickets asignados al técnico logueado
          final ticketsAsignados = ticketsAsync.valueOrNull
              ?.where((t) =>
                  t.tecnicoId == profile.id &&
                  t.estado == TicketEstados.asignado)
              .toList() ?? [];

          return ListView(padding: const EdgeInsets.all(16), children: [

            // ── Tarjeta bienvenida ────────────────────
            Card(child: Padding(padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      radius: 20,
                      child: Text(profile.nombre.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white,
                              fontSize: 22, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bienvenido',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    Text(profile.nombre,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    RolBadge(profile.rolNombre),
                  ])),
                ]))),
            const SizedBox(height: 16),

            // ── Alerta stock bajo — admin y pañolero ──
            if (repuestosBajo.isNotEmpty && (isAdmin || isPaniolero))
              Card(
                color: Colors.red[50],
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 32),
                  title: Text(
                      '${repuestosBajo.length} repuesto(s) con stock bajo',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                          fontSize: 9)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ProviderScope(
                          parent: ProviderScope.containerOf(context),
                          child: const RepuestosScreen(soloStockBajo: true)))),
                )),

            // ── Alerta tickets sin asignar — solo admin ──
            if (ticketsAbiertos.isNotEmpty && isAdmin)
              Card(
                color: Colors.orange[50],
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.assignment_late_outlined,
                      color: Colors.orange, size: 32),
                  title: Text(
                      '${ticketsAbiertos.length} ticket(s) sin asignar',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                          fontSize: 12)),
                  subtitle: const Text('Pendientes de asignación',
                      style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.orange),
                  onTap: () => context.push('/tickets'),
                )),

            // ── Alerta tickets asignados — solo técnico ──
            if (ticketsAsignados.isNotEmpty && isTecnico)
              Card(
                color: Colors.blue[50],
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.engineering_outlined,
                      color: Colors.blue, size: 32),
                  title: Text(
                      '${ticketsAsignados.length} ticket(s) asignado(s) a vos',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                          fontSize: 12)),
                  subtitle: Text(
                      ticketsAsignados.length == 1
                          ? 'Máquina: ${ticketsAsignados.first.maquinaNombre ?? ''}'
                          : 'Pendientes de ejecución',
                      style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.blue),
                  onTap: () => context.push('/tickets'),
                )),

            const SizedBox(height: 8),

            // ── Repuestos — admin, técnico y pañolero ─
            if (isAdmin || isTecnico || isPaniolero)
              _MenuCard(
                  icon: Icons.inventory_2_outlined, title: 'Repuestos',
                  subtitle: 'Stock y catálogo de repuestos', color: Colors.blue,
                  onTap: () => context.push('/repuestos')),

            // ── Máquinas — admin, técnico y pañolero ──
            if (isAdmin || isTecnico || isPaniolero)
              _MenuCard(
                  icon: Icons.precision_manufacturing_outlined, title: 'Máquinas',
                  subtitle: 'Máquinas y sus repuestos', color: Colors.teal,
                  onTap: () => context.push('/maquinas')),

            // ── Ingresos — admin y pañolero ───────────
            if (isAdmin || isPaniolero)
              _MenuCard(
                  icon: Icons.input_outlined, title: 'Ingresos',
                  subtitle: 'Ingresos de repuestos', color: Colors.green,
                  onTap: () => context.push('/ingresos')),

            // ── Salidas — admin y pañolero ────────────
            if (isAdmin || isPaniolero)
              _MenuCard(
                  icon: Icons.output_outlined, title: 'Salidas',
                  subtitle: 'Salidas de repuestos', color: Colors.red,
                  onTap: () => context.push('/salidas')),

            // ── Tickets — solo admin ──────────────────
            if (isAdmin)
              _MenuCard(
                  icon: Icons.confirmation_number_outlined, title: 'Tickets',
                  subtitle: 'Gestión de órdenes de trabajo', color: Colors.orange,
                  onTap: () => context.push('/tickets')),

            // ── Sectores y Usuarios — solo admin ──────
            if (isAdmin) ...[
              _MenuCard(
                  icon: Icons.domain_outlined, title: 'Sectores',
                  subtitle: 'Sectores de la planta', color: Colors.indigo,
                  onTap: () => context.push('/sectores')),
              _MenuCard(
                  icon: Icons.people_outline, title: 'Usuarios',
                  subtitle: 'Gestión de usuarios', color: Colors.purple,
                  onTap: () => context.push('/usuarios')),
            ],

            // ── Tickets — técnico, encargado y pañolero ──
            if (!isAdmin)
              _MenuCard(
                  icon: Icons.confirmation_number_outlined, title: 'Tickets',
                  subtitle: 'Gestión de órdenes de trabajo', color: Colors.orange,
                  onTap: () => context.push('/tickets')),
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

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 15)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 12)),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
              ]),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text(subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
