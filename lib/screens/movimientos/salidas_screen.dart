// lib/screens/movimientos/salidas_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';
import 'salida_form_screen.dart';

class SalidasScreen extends ConsumerWidget {
  const SalidasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async   = ref.watch(salidasProvider);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final uid     = profile?.id ?? '';
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Salidas de repuestos')),
      floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Nueva salida'),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProviderScope(
                  parent: ProviderScope.containerOf(context),
                  child: const SalidaFormScreen())))),
      body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data: (salidas) => RefreshIndicator(
            onRefresh: () => ref.refresh(salidasProvider.future),
            child: salidas.isEmpty
                ? const Center(child: Text('Sin salidas registradas'))
                : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: salidas.length,
                itemBuilder: (_, i) {
                  final s      = salidas[i];
                  final esMia  = s.registradoPor == uid;
                  final canEdit = isAdmin || esMia;

                  return Card(child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFEBEE),
                        child: Icon(Icons.output_outlined, color: Colors.red)),
                    title: Text(
                        '${s.repuestoCodigo ?? ''} — ${s.repuestoDescripcion ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Cantidad: ${s.cantidad} • ${s.fecha}',
                            style: const TextStyle(fontSize: 12)),
                        if (s.ticketId != null)
                          Text('Ticket: ${s.ticketId!.substring(0, 8)}...',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        if (s.ticketId == null)
                          const Text('Sin ticket asociado',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.orange)),
                        if (s.observacion != null)
                          Text(s.observacion!,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      // Badge cantidad
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('-${s.cantidad}',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14))),
                      if (canEdit) ...[
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (v) {
                            if (v == 'editar') {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ProviderScope(
                                      parent: ProviderScope.containerOf(context),
                                      child: SalidaFormScreen(salida: s))));
                            } else if (v == 'eliminar') {
                              _eliminar(context, ref, s.id);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'editar',
                                child: Row(children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ])),
                            const PopupMenuItem(value: 'eliminar',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Eliminar',
                                      style: TextStyle(color: Colors.red)),
                                ])),
                          ],
                        ),
                      ],
                    ]),
                  ));
                }),
          )),
    );
  }

  Future<void> _eliminar(
      BuildContext context, WidgetRef ref, String id) async {
    final ok = await confirmarEliminacion(
        context, '¿Eliminar esta salida de repuesto?');
    if (!ok) return;
    try {
      await ref.read(movimientosRepoProvider).deleteSalida(id);
      ref.invalidate(salidasProvider);
      ref.invalidate(repuestosProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Salida eliminada'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: Colors.red));
      }
    }
  }
}