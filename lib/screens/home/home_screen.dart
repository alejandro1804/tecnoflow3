//// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/image_viewer.dart';
import '../repuestos/repuestos_screen.dart';
import '../qr/QrScannerScreen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync   = ref.watch(myProfileProvider);
    final repuestosAsync = ref.watch(repuestosProvider);
    final ticketsAsync   = ref.watch(ticketsProvider);
    final inactivosAsync = ref.watch(repuestosInactivosProvider);
    final notifAsync     = ref.watch(misNotificacionesProvider);

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

          final ticketsAsignados = ticketsAsync.valueOrNull
              ?.where((t) =>
                  t.tecnicoId == profile.id &&
                  t.estado == TicketEstados.asignado)
              .toList() ?? [];

          final ticketsEnRevision = ticketsAsync.valueOrNull
              ?.where((t) => t.estado == TicketEstados.enRevision)
              .toList() ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(misNotificacionesProvider);
              ref.invalidate(ticketsProvider);
              ref.invalidate(repuestosProvider);
              ref.invalidate(repuestosInactivosProvider);
            },
            child: ListView(padding: const EdgeInsets.all(16), children: [

              // ── Tarjeta bienvenida ────────────────────
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(children: [
                      CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          radius: 16,
                          child: Text(profile.nombre.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 16, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(profile.nombre,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      RolBadge(profile.rolNombre),
                    ]))),

              // ── Botón escanear QR ─────────────────────
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.teal.shade50,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderScope(
                        parent: ProviderScope.containerOf(context),
                        child: QrScannerScreen(),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.qr_code_scanner,
                            color: Colors.teal, size: 22)),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Escanear QR de máquina',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.teal)),
                            SizedBox(height: 2),
                            Text('Identificá un equipo y accedé a su ticket activo',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.teal)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.teal, size: 20),
                    ]),
                  ),
                ),
              ),

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

              // ── Alerta tickets en revisión — solo admin ──
              if (ticketsEnRevision.isNotEmpty && isAdmin)
                Card(
                  color: Colors.indigo.shade50,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: const Icon(Icons.rate_review_outlined,
                        color: Colors.indigo, size: 32),
                    title: Text(
                        '${ticketsEnRevision.length} ticket(s) para revisar',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.indigo,
                            fontSize: 12)),
                    subtitle: Text(
                        ticketsEnRevision.length == 1
                            ? 'Máquina: ${ticketsEnRevision.first.maquinaNombre ?? ''}'
                            : 'Reportados como completados por los técnicos',
                        style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.indigo),
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

              // ── Notificaciones ticket cerrado — encargado ──
              if (profile.isEncargado)
                ...notifAsync.valueOrNull
                    ?.where((n) => n.tipo == TiposNotificacion.ticketCerrado)
                    .map((n) => _NotifEncargadoCard(
                          notif: n,
                          onTap: () async {
                            await ref
                                .read(notificacionesRepoProvider)
                                .marcarLeida(n.id);
                            final usuarios = await ref
                                .read(usuariosRepoProvider)
                                .getAll();
                            final admins = usuarios
                                .where((u) => u.isAdmin)
                                .toList();
                            final uid = Supabase.instance.client
                                .auth.currentUser!.id;
                            for (final admin in admins) {
                              await ref
                                  .read(notificacionesRepoProvider)
                                  .crear(
                                    tipo:          TiposNotificacion.confirmacionEncargado,
                                    mensaje:       '${profile.nombre} confirmó recepción: ${n.mensaje}',
                                    paraUsuarioId: admin.id,
                                    ticketId:      n.ticketId,
                                    deUsuarioId:   uid,
                                  );
                            }
                            ref.invalidate(misNotificacionesProvider);
                            if (n.ticketId != null) {
                              ref.invalidate(
                                  confirmacionesTicketProvider(n.ticketId!));
                            }
                            if (context.mounted && n.ticketId != null) {
                              context.push('/tickets/${n.ticketId}');
                            }
                          },
                        ))
                    .toList() ?? [],

              // ── Notificaciones confirmación — solo admin ──
              if (isAdmin)
                ...notifAsync.valueOrNull
                    ?.where((n) =>
                        n.tipo == TiposNotificacion.confirmacionEncargado)
                    .map((n) => _NotifAdminCard(
                          notif: n,
                          onTap: () async {
                            await ref
                                .read(notificacionesRepoProvider)
                                .marcarLeida(n.id);
                            ref.invalidate(misNotificacionesProvider);
                            if (context.mounted && n.ticketId != null) {
                              context.push('/tickets/${n.ticketId}');
                            }
                          },
                        ))
                    .toList() ?? [],

              const SizedBox(height: 8),

              if (isAdmin || isTecnico || isPaniolero)
                _MenuCard(
                    icon: Icons.inventory_2_outlined, title: 'Repuestos',
                    color: Colors.blue,
                    onTap: () => context.push('/repuestos')),

              if (isAdmin || isTecnico || isPaniolero)
                _MenuCard(
                    icon: Icons.precision_manufacturing_outlined, title: 'Máquinas',
                    color: Colors.teal,
                    onTap: () => context.push('/maquinas')),

              if (isAdmin || isPaniolero)
                _MenuCard(
                    icon: Icons.input_outlined, title: 'Ingresos',
                    color: Colors.green,
                    onTap: () => context.push('/ingresos')),

              if (isAdmin || isPaniolero)
                _MenuCard(
                    icon: Icons.output_outlined, title: 'Salidas',
                    color: Colors.red,
                    onTap: () => context.push('/salidas')),

              if (isAdmin)
                _MenuCard(
                    icon: Icons.confirmation_number_outlined, title: 'Tickets',
                    color: Colors.orange,
                    onTap: () => context.push('/tickets')),

              if (isAdmin)
                inactivosAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                  data: (inactivos) => inactivos.isEmpty
                      ? const SizedBox.shrink()
                      : _RepuestosInactivosCard(repuestos: inactivos),
                ),

              if (isAdmin) ...[
                _MenuCard(
                    icon: Icons.domain_outlined, title: 'Sectores',
                    color: Colors.indigo,
                    onTap: () => context.push('/sectores')),
                _MenuCard(
                    icon: Icons.people_outline, title: 'Usuarios',
                    color: Colors.purple,
                    onTap: () => context.push('/usuarios')),
              ],

              if (isTecnico)
                _MenuCard(
                    icon: Icons.input_outlined, title: 'Ingresos',
                    color: Colors.green,
                    onTap: () => context.push('/ingresos')),

              if (isTecnico)
                _MenuCard(
                    icon: Icons.output_outlined, title: 'Salidas',
                    color: Colors.red,
                    onTap: () => context.push('/salidas')),

              if (!isAdmin)
                _MenuCard(
                    icon: Icons.confirmation_number_outlined, title: 'Tickets',
                    color: Colors.orange,
                    onTap: () => context.push('/tickets')),

              // ── Footer versión ────────────────────────
              const SizedBox(height: 24),
              const _VersionFooter(),
              const SizedBox(height: 8),
            ]),
          );
        }),
    );
  }
}

// ── Footer con versión ────────────────────────────────────────
class _VersionFooter extends StatefulWidget {
  const _VersionFooter();

  @override
  State<_VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<_VersionFooter> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = 'v${info.version}');
  }

  @override
  Widget build(BuildContext context) {
    if (_version.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Text(_version,
          style: TextStyle(
              fontSize: 11, color: Colors.grey[400], letterSpacing: 0.5)),
    );
  }
}

// ── Card notificación para encargado ─────────────────────────
class _NotifEncargadoCard extends StatelessWidget {
  final Notificacion notif;
  final VoidCallback onTap;
  const _NotifEncargadoCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.green[50],
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      leading: const Icon(Icons.check_circle_outline,
          color: Colors.green, size: 32),
      title: Text(notif.mensaje,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.green, fontSize: 12)),
      subtitle: const Text('Tocá para confirmar recepción',
          style: TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: Colors.green),
      onTap: onTap,
    ),
  );
}

// ── Card notificación para admin ──────────────────────────────
class _NotifAdminCard extends StatelessWidget {
  final Notificacion notif;
  final VoidCallback onTap;
  const _NotifAdminCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.teal[50],
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      leading: const Icon(Icons.how_to_reg_outlined,
          color: Colors.teal, size: 32),
      title: Text(notif.mensaje,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.teal, fontSize: 12)),
      subtitle: Text(
          'Recibido: ${notif.createdAt.toString().substring(0, 16)}',
          style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: Colors.teal),
      onTap: onTap,
    ),
  );
}

// ── Sección repuestos inactivos ───────────────────────────────
class _RepuestosInactivosCard extends ConsumerStatefulWidget {
  final List<Repuesto> repuestos;
  const _RepuestosInactivosCard({required this.repuestos});

  @override
  ConsumerState<_RepuestosInactivosCard> createState() => _InactivosState();
}

class _InactivosState extends ConsumerState<_RepuestosInactivosCard> {
  bool _expandido = false;

  Future<void> _activar(BuildContext context, Repuesto r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Activar repuesto'),
        content: Text(
            '¿Querés activar "${r.descripcion}"?\n\nVolverá a aparecer en el listado de repuestos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Activar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repuestosRepoProvider).toggleActivo(r.id, true);
      ref.invalidate(repuestosProvider);
      ref.invalidate(repuestosInactivosProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Repuesto activado'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _verDetalle(BuildContext context, Repuesto r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.35,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                const Text('DETALLE DE REPUESTO', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey, letterSpacing: 1)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('INACTIVO',
                      style: TextStyle(fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 12),
              if (r.imagenUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(r.imagenUrl!,
                      width: double.infinity, height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child
                              : Container(height: 200,
                                  color: Colors.grey[100],
                                  child: const Center(
                                      child: CircularProgressIndicator()))),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  width: double.infinity, height: 100,
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Center(child: Icon(Icons.image_outlined,
                      size: 36, color: Colors.grey[300])),
                ),
                const SizedBox(height: 16),
              ],
              _InfoFila(Icons.qr_code_outlined, 'Código', r.codigo ?? '—'),
              _InfoFila(Icons.description_outlined, 'Descripción', r.descripcion),
              _InfoFila(Icons.location_on_outlined, 'Ubicación', r.ubicacion ?? '—'),
              const Divider(height: 20),
              _InfoFila(Icons.inventory_2_outlined, 'Stock actual',
                  r.stockActual.toString(),
                  color: r.stockBajo ? Colors.red : Colors.green),
              _InfoFila(Icons.warning_amber_outlined, 'Stock mínimo',
                  r.stockMinimo.toString()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange[50],
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expandido = !_expandido),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined,
                  color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(
                  '${widget.repuestos.length} repuesto(s) inactivo(s)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.orange, fontSize: 12))),
              Icon(_expandido
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
                  color: Colors.orange),
            ]),
          ),
        ),

        if (_expandido) ...[
          const Divider(height: 1, color: Colors.orange),
          ...widget.repuestos.map((r) => Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.block_outlined,
                      size: 12, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r.descripcion,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 70, height: 70,
                    child: r.imagenUrl != null
                        ? RepuestoImagenThumb(imagenUrl: r.imagenUrl, size: 70)
                        : Container(
                            decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey.withOpacity(0.2))),
                            child: Icon(Icons.image_outlined,
                                color: Colors.grey[300], size: 24)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.ubicacion != null)
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: Colors.grey),
                          const SizedBox(width: 3),
                          Expanded(child: Text(r.ubicacion!,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey))),
                        ]),
                      const SizedBox(height: 4),
                      Wrap(spacing: 4, runSpacing: 4, children: [
                        StockBadge(
                            stock: r.stockActual,
                            minimo: r.stockMinimo),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('Mín: ${r.stockMinimo}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey,
                                    fontWeight: FontWeight.w600))),
                      ]),
                    ],
                  )),
                ]),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _IconBtn(
                      icon: Icons.visibility_outlined,
                      color: Colors.teal,
                      label: 'Ver',
                      onTap: () => _verDetalle(context, r),
                    ),
                    _IconBtn(
                      icon: Icons.toggle_off_outlined,
                      color: Colors.orange,
                      label: 'Activar',
                      onTap: () => _activar(context, r),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Colors.orange),
              ],
            ),
          )),
        ],
      ]),
    );
  }
}

// ── Ícono con label ───────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ── Fila de info en detalle ───────────────────────────────────
class _InfoFila extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   color;
  const _InfoFila(this.icon, this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.grey),
      const SizedBox(width: 10),
      Text('$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Expanded(child: Text(value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: color ?? Colors.black87),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ── MenuCard ──────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final Color        color;
  final VoidCallback onTap;
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 15)),
          const SizedBox(width: 10),
          Expanded(child: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13))),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
        ]),
      ),
    ),
  );
}