// lib/screens/maquinas/maquina_form_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../core/imageHelper.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class MaquinaFormScreen extends ConsumerStatefulWidget {
  final String? maquinaId;
  const MaquinaFormScreen({super.key, this.maquinaId});
  @override
  ConsumerState<MaquinaFormScreen> createState() => _State();
}

class _State extends ConsumerState<MaquinaFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nomCtrl  = TextEditingController();
  final _codCtrl  = TextEditingController();
  final _descCtrl = TextEditingController();

  String     _sectorId    = '';
  String     _estado      = 'activo';
  bool       _loading     = false;
  bool       _loadingData = false;
  bool       _subiendoImg = false;
  String?    _error;
  String?    _imagenUrl;
  Uint8List? _imagenBytes;

  bool get isEdit => widget.maquinaId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loadingData = true);
    try {
      final maquinas = await ref.read(maquinasRepoProvider).getAll();
      final m = maquinas.firstWhere((m) => m.id == widget.maquinaId);
      _nomCtrl.text  = m.nombre;
      _codCtrl.text  = m.codigo;
      _descCtrl.text = m.descripcion ?? '';
      setState(() {
        _sectorId  = m.sectorId;
        _estado    = m.estado;
        _imagenUrl = m.imagenUrl;
      });
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _seleccionarImagen() async {
    final bytes = await ImageHelper.elegirImagen(context);
    if (bytes != null) setState(() => _imagenBytes = bytes);
  }

  void _quitarImagen() {
    setState(() { _imagenBytes = null; _imagenUrl = null; });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      String? urlFinal = _imagenUrl;

      // Si hay imagen nueva, subir primero con ID temporal
      if (_imagenBytes != null) {
        setState(() => _subiendoImg = true);
        final tempId = widget.maquinaId ??
            'temp_${DateTime.now().millisecondsSinceEpoch}';
        urlFinal = await ImageHelper.subirImagenMaquina(_imagenBytes!, tempId);
        setState(() => _subiendoImg = false);
      }

      // Si se quitó la imagen en edición, eliminar del bucket
      if (_imagenBytes == null && _imagenUrl == null && isEdit) {
        await ImageHelper.eliminarImagenMaquina(widget.maquinaId!);
      }

      final m = Maquina(
        id:          widget.maquinaId ?? '',
        sectorId:    _sectorId,
        nombre:      _nomCtrl.text.trim(),
        codigo:      _codCtrl.text.trim(),
        estado:      _estado,
        descripcion: _descCtrl.text.trim().isEmpty
            ? null : _descCtrl.text.trim(),
        imagenUrl:   urlFinal,
      );

      if (isEdit) {
        await ref.read(maquinasRepoProvider).update(widget.maquinaId!, m);
        // Si la imagen era temporal, reubicar con ID real
        if (_imagenBytes != null && urlFinal != null &&
            urlFinal.contains('temp_')) {
          final nueva = await ImageHelper.subirImagenMaquina(
              _imagenBytes!, widget.maquinaId!);
          await ref.read(maquinasRepoProvider).update(
              widget.maquinaId!, Maquina(
                id:          widget.maquinaId!,
                sectorId:    _sectorId,
                nombre:      m.nombre,
                codigo:      m.codigo,
                estado:      _estado,
                descripcion: m.descripcion,
                imagenUrl:   nueva,
              ));
          urlFinal = nueva;
        }
      } else {
        await ref.read(maquinasRepoProvider).create(m);
        // Tras crear, obtener el ID real y reubicar imagen si había
        if (_imagenBytes != null) {
          final todas = await ref.read(maquinasRepoProvider).getAll();
          final nueva = todas.firstWhere(
              (x) => x.nombre == m.nombre && x.codigo == m.codigo);
          final urlNew = await ImageHelper.subirImagenMaquina(
              _imagenBytes!, nueva.id);
          await ref.read(maquinasRepoProvider).update(
              nueva.id, Maquina(
                id:          nueva.id,
                sectorId:    _sectorId,
                nombre:      m.nombre,
                codigo:      m.codigo,
                estado:      _estado,
                descripcion: m.descripcion,
                imagenUrl:   urlNew,
              ));
        }
      }

      ref.invalidate(maquinasProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Guardado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _loading = false; _subiendoImg = false; });
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _codCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectores = ref.watch(sectoresProvider).valueOrNull ?? [];
    if (_sectorId.isEmpty && sectores.isNotEmpty) {
      _sectorId = sectores.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar máquina' : 'Nueva máquina'),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Imagen ────────────────────────────
                    const Text('IMAGEN', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    _ImagenSelector(
                      imagenBytes:   _imagenBytes,
                      imagenUrl:     _imagenUrl,
                      subiendoImg:   _subiendoImg,
                      onSeleccionar: _seleccionarImagen,
                      onQuitar:      _quitarImagen,
                    ),
                    const SizedBox(height: 20),

                    // ── Nombre ────────────────────────────
                    TextFormField(
                      controller: _nomCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(
                              Icons.precision_manufacturing_outlined)),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 16),

                    // ── Código ────────────────────────────
                    TextFormField(
                      controller: _codCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Código',
                          prefixIcon: Icon(Icons.qr_code_outlined)),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 16),

                    // ── Sector ────────────────────────────
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _sectorId.isEmpty ? null : _sectorId,
                      decoration: const InputDecoration(
                          labelText: 'Sector',
                          prefixIcon: Icon(Icons.domain_outlined)),
                      items: sectores.map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.nombre))).toList(),
                      onChanged: (v) => setState(() => _sectorId = v!),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 16),

                    // ── Estado ────────────────────────────
                    DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: const InputDecoration(
                          labelText: 'Estado',
                          prefixIcon: Icon(Icons.toggle_on_outlined)),
                      items: const [
                        DropdownMenuItem(
                            value: 'activo', child: Text('Activo')),
                        DropdownMenuItem(
                            value: 'inactivo', child: Text('Inactivo')),
                        DropdownMenuItem(
                            value: 'en_reparacion',
                            child: Text('En reparación')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!)),
                    const SizedBox(height: 16),

                    // ── Descripción ───────────────────────
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          prefixIcon: Icon(Icons.notes_outlined))),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorContainer(_error!),
                    ],
                    const SizedBox(height: 28),
                    LoadingButton(
                      loading: _loading,
                      onPressed: _submit,
                      label: _subiendoImg
                          ? 'Subiendo imagen...'
                          : 'Guardar'),
                  ],
                ),
              ),
          ),
    );
  }
}

// ── Widget selector de imagen ─────────────────────────────────
class _ImagenSelector extends StatelessWidget {
  final Uint8List? imagenBytes;
  final String?    imagenUrl;
  final bool       subiendoImg;
  final VoidCallback onSeleccionar;
  final VoidCallback onQuitar;

  const _ImagenSelector({
    required this.imagenBytes,
    required this.imagenUrl,
    required this.subiendoImg,
    required this.onSeleccionar,
    required this.onQuitar,
  });

  bool get tieneImagen => imagenBytes != null || imagenUrl != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300)),
      child: tieneImagen
          ? Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imagenBytes != null
                    ? Image.memory(imagenBytes!, fit: BoxFit.cover)
                    : Image.network(imagenUrl!, fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator())),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: onQuitar,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18)),
                )),
              Positioned(
                bottom: 8, right: 8,
                child: GestureDetector(
                  onTap: onSeleccionar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_outlined,
                          color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Cambiar',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ])),
                )),
              if (subiendoImg)
                Container(
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white))),
            ])
          : InkWell(
              onTap: onSeleccionar,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('Agregar imagen',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Cámara, galería o archivos',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 11)),
                ],
              ),
            ),
    );
  }
}
