// lib/screens/tickets/ticket_form_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class TicketFormScreen extends ConsumerStatefulWidget {
  const TicketFormScreen({super.key});
  @override
  ConsumerState<TicketFormScreen> createState() => _State();
}

class _State extends ConsumerState<TicketFormScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _obsCtrl  = TextEditingController();
  final _numCtrl  = TextEditingController();

  String  _maquinaId  = '';
  bool    _sinMaquina = false;
  bool    _loading    = false;
  String? _error;

  // ── foto ──────────────────────────────────────────────────────
  File?   _fotoFile;
  bool    _subiendoFoto = false;

  Future<void> _seleccionarFoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1200);
    if (picked == null) return;
    setState(() => _fotoFile = File(picked.path));
  }

  void _mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Tomar foto'),
            onTap: () {
              Navigator.pop(context);
              _seleccionarFoto(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galería'),
            onTap: () {
              Navigator.pop(context);
              _seleccionarFoto(ImageSource.gallery);
            },
          ),
          if (_fotoFile != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Quitar foto',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _fotoFile = null);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      String? fotoUrl;

      // Subir foto si hay una seleccionada (necesitamos el ID del ticket primero,
      // así que subimos con un path temporal y luego actualizamos)
      if (_fotoFile != null) {
        setState(() => _subiendoFoto = true);
        // Creamos el ticket primero para obtener el ID
        await ref.read(ticketsRepoProvider).create(
            maquinaId:   _sinMaquina ? null : _maquinaId,
            descripcion: _descCtrl.text.trim(),
            observacion: _obsCtrl.text.trim().isEmpty
                ? null : _obsCtrl.text.trim(),
            numero:      _numCtrl.text.trim().isEmpty
                ? null : _numCtrl.text.trim());

        // Obtener el ticket recién creado para tener su ID
        final tickets = await ref.read(ticketsRepoProvider).getAll();
        if (tickets.isNotEmpty) {
          final nuevoTicket = tickets.first; // ordenados por created_at desc
          fotoUrl = await ref.read(ticketFotosRepoProvider)
              .subirFoto(_fotoFile!, nuevoTicket.id);
          await ref.read(ticketsRepoProvider)
              .updateFotoUrl(nuevoTicket.id, fotoUrl);
        }
      } else {
        await ref.read(ticketsRepoProvider).create(
            maquinaId:   _sinMaquina ? null : _maquinaId,
            descripcion: _descCtrl.text.trim(),
            observacion: _obsCtrl.text.trim().isEmpty
                ? null : _obsCtrl.text.trim(),
            numero:      _numCtrl.text.trim().isEmpty
                ? null : _numCtrl.text.trim());
      }

      ref.invalidate(ticketsProvider);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ticket creado'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _loading = false; _subiendoFoto = false; });
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose(); _obsCtrl.dispose(); _numCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maquinas = ref.watch(maquinasProvider).valueOrNull ?? [];
    if (_maquinaId.isEmpty && maquinas.isNotEmpty && !_sinMaquina) {
      _maquinaId = maquinas.first.id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Número externo (opcional) ─────────────
              TextFormField(
                controller: _numCtrl,
                decoration: const InputDecoration(
                    labelText: 'N° de ticket externo (opcional)',
                    prefixIcon: Icon(Icons.tag_outlined),
                    hintText: 'Ej: TK-2024-001'),
              ),
              const SizedBox(height: 16),

              // ── Switch sin máquina ────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: _sinMaquina
                        ? Colors.orange.withOpacity(0.06)
                        : Colors.grey.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _sinMaquina
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2))),
                child: Row(children: [
                  Icon(Icons.precision_manufacturing_outlined,
                      size: 18,
                      color: _sinMaquina ? Colors.orange : Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Sin máquina asociada',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _sinMaquina
                                ? Colors.orange : Colors.black87)),
                  ),
                  Switch(
                    value: _sinMaquina,
                    activeColor: Colors.orange,
                    onChanged: (v) => setState(() {
                      _sinMaquina = v;
                      if (v) _maquinaId = '';
                    }),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Selector de máquina ───────────────────
              if (!_sinMaquina)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _maquinaId.isEmpty ? null : _maquinaId,
                  decoration: const InputDecoration(
                      labelText: 'Máquina',
                      prefixIcon: Icon(
                          Icons.precision_manufacturing_outlined)),
                  items: maquinas.map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(
                          '${m.nombre} (${m.sectorNombre ?? ''})',
                          overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _maquinaId = v!),
                  validator: (v) =>
                      (!_sinMaquina && (v == null || v.isEmpty))
                          ? 'Seleccione una máquina' : null),

              if (!_sinMaquina) const SizedBox(height: 16),

              // ── Descripción ───────────────────────────
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Descripción del desperfecto',
                    prefixIcon: Icon(Icons.report_problem_outlined)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 16),

              // ── Observación ───────────────────────────
              TextFormField(
                controller: _obsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Observación adicional (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined))),
              const SizedBox(height: 20),

              // ── Foto del desperfecto ──────────────────
              const Text('FOTO DEL DESPERFECTO', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 10),

              GestureDetector(
                onTap: _mostrarOpcionesFoto,
                child: _fotoFile != null
                    ? Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _fotoFile!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20)),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.edit_outlined,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ])
                    : Container(
                        height: 120,
                        decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                style: BorderStyle.solid)),
                        child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 32, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Agregar foto (opcional)',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ]),
                      ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorContainer(_error!),
              ],
              const SizedBox(height: 28),

              // Mensaje mientras se sube la foto
              if (_subiendoFoto)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Subiendo foto...', style: TextStyle(fontSize: 12)),
                  ]),
                ),

              LoadingButton(
                  loading: _loading,
                  onPressed: _submit,
                  label: 'Crear ticket'),
            ],
          ),
        ),
      ),
    );
  }
}