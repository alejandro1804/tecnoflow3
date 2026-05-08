// lib/screens/maquinas/repuestos_maquina_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class RepuestosMaquinaScreen extends ConsumerWidget {
  final String maquinaId;
  final String maquinaNombre;

  const RepuestosMaquinaScreen({
    super.key,
    required this.maquinaId,
    required this.maquinaNombre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async       = ref.watch(repuestosMaquinasProvider(maquinaId));
    final profile     = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin     = profile?.isAdmin ?? false;
    final isPaniolero = profile?.isPaniolero ?? false;
    final canEdit     = isAdmin || (profile?.isTecnico ?? false) || isPaniolero;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(title: Text('Repuestos — $maquinaNombre')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Agregar repuesto'),
              onPressed: () => _mostrarModal(context, ref, maquinaId, isAdmin),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Sin repuestos asociados a esta máquina'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── FILA 1: Ícono + Descripción ──────
                          Row(children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              child: const Icon(Icons.settings_outlined,
                                  color: Colors.blue, size: 16)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.repuestoDescripcion ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                          const SizedBox(height: 6),

                          // ── FILA 2: Código | Cantidad | Ubicación ──
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(item.repuestoCodigo ?? '',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            _InfoChip('Cant: ${item.cantidad}', Colors.blue),
                            if (item.ubicacionEnMaquina != null) ...[
                              const SizedBox(width: 6),
                              _InfoChip(item.ubicacionEnMaquina!, Colors.teal),
                            ],
                          ]),

                          // Observación
                          if (item.observacion != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.notes_outlined,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(item.observacion!,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ),
                            ]),
                          ],

                          // ── FILA 3: Acciones ──────────────────
                          if (canEdit) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              const Spacer(),
                              InkWell(
                                onTap: () => _mostrarModal(
                                    context, ref, maquinaId, isAdmin,
                                    repuestoMaquina: item),
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
                              if (isAdmin || isPaniolero) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _eliminar(
                                      context, ref, item.id, maquinaId),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                  ),
                                ),
                              ],
                            ]),
                          ],
                        ],
                      ),
                    ),
                  );
                },
            ),
      ),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref,
      String id, String maquinaId) async {
    final ok = await confirmarEliminacion(
        context, '¿Eliminar este repuesto de la máquina?');
    if (!ok) return;
    try {
      await ref.read(repuestosMaquinasRepoProvider).delete(id);
      ref.invalidate(repuestosMaquinasProvider(maquinaId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Repuesto eliminado de la máquina'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _mostrarModal(BuildContext context, WidgetRef ref,
      String maquinaId, bool isAdmin,
      {RepuestoMaquina? repuestoMaquina}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _RepuestoMaquinaModal(
          maquinaId:       maquinaId,
          isAdmin:         isAdmin,
          repuestoMaquina: repuestoMaquina,
          onSaved: () => ref.invalidate(repuestosMaquinasProvider(maquinaId)),
        ),
      ),
    );
  }
}

// ── Modal agregar/editar ──────────────────────────────────────
class _RepuestoMaquinaModal extends ConsumerStatefulWidget {
  final String maquinaId;
  final bool isAdmin;
  final RepuestoMaquina? repuestoMaquina;
  final VoidCallback onSaved;

  const _RepuestoMaquinaModal({
    required this.maquinaId,
    required this.isAdmin,
    required this.onSaved,
    this.repuestoMaquina,
  });

  @override
  ConsumerState<_RepuestoMaquinaModal> createState() => _ModalState();
}

class _ModalState extends ConsumerState<_RepuestoMaquinaModal> {
  final _formKey     = GlobalKey<FormState>();
  final _cantCtrl    = TextEditingController(text: '1');
  final _ubicCtrl    = TextEditingController();
  final _obsCtrl     = TextEditingController();
  final _busqCtrl    = TextEditingController();
  final _codCtrl     = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _minCtrl     = TextEditingController(text: '0');
  final _ubicRepCtrl = TextEditingController();

  bool _crearNuevo   = false;
  bool _loading      = false;
  String? _error;
  String? _repuestoSelId;
  String  _busqueda  = '';

  bool get isEdit => widget.repuestoMaquina != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final rm = widget.repuestoMaquina!;
      _cantCtrl.text = rm.cantidad.toString();
      _ubicCtrl.text = rm.ubicacionEnMaquina ?? '';
      _obsCtrl.text  = rm.observacion ?? '';
      _repuestoSelId = rm.repuestoId;
    }
  }

  @override
  void dispose() {
    _cantCtrl.dispose(); _ubicCtrl.dispose(); _obsCtrl.dispose();
    _busqCtrl.dispose(); _codCtrl.dispose(); _descCtrl.dispose();
    _minCtrl.dispose(); _ubicRepCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      String repId = _repuestoSelId ?? '';
      if (_crearNuevo) {
        final nuevoRep = Repuesto(
          id:          '',
          codigo:      _codCtrl.text.trim(),
          descripcion: _descCtrl.text.trim(),
          stockActual: 0,
          stockMinimo: int.tryParse(_minCtrl.text) ?? 0,
          ubicacion:   _ubicRepCtrl.text.trim().isEmpty
              ? null : _ubicRepCtrl.text.trim(),
        );
        await ref.read(repuestosRepoProvider).create(nuevoRep);
        final todos = await ref.read(repuestosRepoProvider).getAll();
        repId = todos.firstWhere((r) => r.codigo == nuevoRep.codigo).id;
        ref.invalidate(repuestosProvider);
      }

      final rm = RepuestoMaquina(
        id:                 widget.repuestoMaquina?.id ?? '',
        repuestoId:         repId,
        maquinaId:          widget.maquinaId,
        cantidad:           int.tryParse(_cantCtrl.text) ?? 1,
        ubicacionEnMaquina: _ubicCtrl.text.trim().isEmpty
            ? null : _ubicCtrl.text.trim(),
        observacion:        _obsCtrl.text.trim().isEmpty
            ? null : _obsCtrl.text.trim(),
      );

      if (isEdit) {
        await ref.read(repuestosMaquinasRepoProvider).update(
            widget.repuestoMaquina!.id, rm);
      } else {
        await ref.read(repuestosMaquinasRepoProvider).create(
            rm, widget.maquinaId);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit
                ? 'Asociación actualizada'
                : 'Repuesto agregado a la máquina'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repuestos = ref.watch(repuestosProvider).valueOrNull ?? [];
    final filtrados = repuestos
        .where((r) =>
            r.codigo.toLowerCase().contains(_busqueda.toLowerCase()) ||
            r.descripcion.toLowerCase().contains(_busqueda.toLowerCase()))
        .toList()
      ..sort((a, b) => a.descripcion.compareTo(b.descripcion));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(isEdit
                  ? 'Editar asociación'
                  : 'Agregar repuesto a máquina',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              if (!isEdit) ...[
                Row(children: [
                  const Text('¿El repuesto no existe aún?'),
                  const Spacer(),
                  Switch(
                    value: _crearNuevo,
                    onChanged: (v) => setState(
                        () { _crearNuevo = v; _repuestoSelId = null; })),
                ]),
                const SizedBox(height: 8),
              ],

              if (!_crearNuevo) ...[
                if (!isEdit) ...[
                  TextFormField(
                    controller: _busqCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Buscar repuesto',
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Código o descripción...'),
                    onChanged: (v) => setState(() => _busqueda = v)),
                  const SizedBox(height: 8),
                  if (_busqueda.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10)),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtrados.length,
                        itemBuilder: (_, i) {
                          final r   = filtrados[i];
                          final sel = _repuestoSelId == r.id;
                          return ListTile(
                            dense: true,
                            selected: sel,
                            selectedTileColor: Colors.blue.withOpacity(0.08),
                            leading: Icon(
                                sel ? Icons.check_circle : Icons.circle_outlined,
                                color: sel ? Colors.blue : Colors.grey,
                                size: 18),
                            title: Text('${r.codigo} — ${r.descripcion}',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text('Stock: ${r.stockActual}',
                                style: const TextStyle(fontSize: 11)),
                            onTap: () => setState(() {
                              _repuestoSelId = r.id;
                              _busqCtrl.text =
                                  '${r.codigo} — ${r.descripcion}';
                              _busqueda = '';
                            }),
                          );
                        }),
                    ),
                  if (_repuestoSelId == null && !isEdit)
                    const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Seleccione un repuesto',
                            style: TextStyle(
                                color: Colors.red, fontSize: 12))),
                  const SizedBox(height: 8),
                ],
                if (isEdit)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.blue.withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_outlined,
                          color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                          '${widget.repuestoMaquina!.repuestoCodigo} — '
                          '${widget.repuestoMaquina!.repuestoDescripcion}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13))),
                    ])),
              ],

              if (_crearNuevo) ...[
                const Text('DATOS DEL NUEVO REPUESTO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _codCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Código / SKU',
                        prefixIcon: Icon(Icons.qr_code_outlined)),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description_outlined)),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Stock mínimo',
                          prefixIcon: Icon(Icons.warning_amber_outlined)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                      controller: _ubicRepCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Ubicación depósito',
                          prefixIcon: Icon(Icons.location_on_outlined)))),
                ]),
                const SizedBox(height: 16),
                const Divider(),
                const Text('DATOS DE LA ASOCIACIÓN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 12),
              ],

              if (!_crearNuevo) const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(
                    controller: _cantCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        prefixIcon: Icon(Icons.numbers_outlined)),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser > 0';
                      return null;
                    })),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                    controller: _ubicCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Ubicación en máquina',
                        prefixIcon: Icon(Icons.place_outlined)))),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _obsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Observación (opcional)',
                      prefixIcon: Icon(Icons.notes_outlined))),

              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorContainer(_error!),
              ],

              const SizedBox(height: 20),
              LoadingButton(
                  loading: _loading,
                  onPressed: (!_crearNuevo &&
                          _repuestoSelId == null &&
                          !isEdit)
                      ? null
                      : _submit,
                  label: isEdit
                      ? 'Guardar cambios'
                      : 'Agregar a máquina'),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip de info ──────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _InfoChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Text(label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600)));
}
