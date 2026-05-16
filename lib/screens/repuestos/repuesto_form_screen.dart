// lib/screens/repuestos/repuesto_form_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../core/imageHelper.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class RepuestoFormScreen extends ConsumerStatefulWidget {
  final String? repuestoId;
  const RepuestoFormScreen({super.key, this.repuestoId});
  @override
  ConsumerState<RepuestoFormScreen> createState() => _State();
}

class _State extends ConsumerState<RepuestoFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _codCtrl  = TextEditingController();
  final _descCtrl = TextEditingController();
  final _minCtrl  = TextEditingController(text: '0');
  final _ubicCtrl = TextEditingController();

  bool       _loading     = false;
  bool       _loadingData = false;
  bool       _subiendoImg = false;
  String?    _error;
  String?    _imagenUrl;
  Uint8List? _imagenBytes;
  int?       _ref;

  bool get isEdit => widget.repuestoId != null;

  @override
  void initState() { super.initState(); if (isEdit) _load(); }

  Future<void> _load() async {
    setState(() => _loadingData = true);
    try {
      final lista = await ref.read(repuestosRepoProvider).getAll();
      final rep   = lista.firstWhere((r) => r.id == widget.repuestoId);
      _codCtrl.text  = rep.codigo ?? '';
      _descCtrl.text = rep.descripcion;
      _minCtrl.text  = rep.stockMinimo.toString();
      _ubicCtrl.text = rep.ubicacion ?? '';
      setState(() {
        _imagenUrl = rep.imagenUrl;
        _ref       = rep.ref;
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

      if (_imagenBytes != null) {
        setState(() => _subiendoImg = true);
        final tempId = widget.repuestoId ??
            'temp_${DateTime.now().millisecondsSinceEpoch}';
        urlFinal = await ImageHelper.subirImagen(_imagenBytes!, tempId);
        setState(() => _subiendoImg = false);
      }

      if (_imagenBytes == null && _imagenUrl == null && isEdit) {
        await ImageHelper.eliminarImagen(widget.repuestoId!);
      }

      final codigoFinal = _codCtrl.text.trim().isEmpty
          ? null
          : _codCtrl.text.trim();

      final rep = Repuesto(
        id:          widget.repuestoId ?? '',
        codigo:      codigoFinal,
        descripcion: _descCtrl.text.trim(),
        stockActual: 0,
        stockMinimo: int.tryParse(_minCtrl.text) ?? 0,
        ubicacion:   _ubicCtrl.text.trim().isEmpty
            ? null : _ubicCtrl.text.trim(),
        imagenUrl:   urlFinal,
      );

      if (isEdit) {
        await ref.read(repuestosRepoProvider).update(widget.repuestoId!, rep);
        if (_imagenBytes != null && urlFinal != null &&
            urlFinal.contains('temp_')) {
          final nueva = await ImageHelper.subirImagen(
              _imagenBytes!, widget.repuestoId!);
          await ref.read(repuestosRepoProvider).update(
              widget.repuestoId!, rep);
          urlFinal = nueva;
        }
      } else {
        await ref.read(repuestosRepoProvider).create(rep);
        if (_imagenBytes != null) {
          final todos = await ref.read(repuestosRepoProvider).getAll();
          final nuevo = todos.firstWhere((r) => r.descripcion == rep.descripcion);
          final urlNew = await ImageHelper.subirImagen(
              _imagenBytes!, nuevo.id);
          await ref.read(repuestosRepoProvider).update(
              nuevo.id, Repuesto(
                id:          nuevo.id,
                codigo:      rep.codigo,
                descripcion: rep.descripcion,
                stockActual: 0,
                stockMinimo: rep.stockMinimo,
                ubicacion:   rep.ubicacion,
                imagenUrl:   urlNew,
              ));
        }
      }

      ref.invalidate(repuestosProvider);
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

  Future<void> _delete() async {
    final ok = await confirmarEliminacion(
        context, '¿Eliminar "${_descCtrl.text}"?');
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await ImageHelper.eliminarImagen(widget.repuestoId!);
      await ref.read(repuestosRepoProvider).delete(widget.repuestoId!);
      ref.invalidate(repuestosProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codCtrl.dispose(); _descCtrl.dispose();
    _minCtrl.dispose(); _ubicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar repuesto' : 'Nuevo repuesto'),
        actions: [
          if (isEdit && isAdmin)
            IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red[200],
                onPressed: _loading ? null : _delete),
        ],
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

                    // ── REF (solo lectura en edición) ─────
                    if (isEdit && _ref != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.purple.withOpacity(0.3))),
                        child: Row(children: [
                          const Icon(Icons.tag,
                              color: Colors.purple, size: 20),
                          const SizedBox(width: 10),
                          const Text('N° Referencia',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.purple)),
                          const Spacer(),
                          Text('$_ref',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.purple)),
                        ]),
                      ),
                      const SizedBox(height: 20),
                    ],

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

                    // ── Campos ────────────────────────────
                    TextFormField(
                      controller: _codCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Código / SKU (opcional)',
                          prefixIcon: Icon(Icons.qr_code_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Descripción',
                          prefixIcon: Icon(Icons.description_outlined)),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Stock mínimo',
                          prefixIcon: Icon(Icons.warning_amber_outlined)),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ubicCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Ubicación / Depósito (opcional)',
                          prefixIcon: Icon(Icons.location_on_outlined))),

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
