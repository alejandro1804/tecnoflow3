// lib/screens/tickets/ticket_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

class TicketFormScreen extends ConsumerStatefulWidget {
  const TicketFormScreen({super.key});
  @override
  ConsumerState<TicketFormScreen> createState() => _State();
}

class _State extends ConsumerState<TicketFormScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _descCtrl  = TextEditingController();
  final _obsCtrl   = TextEditingController();
  final _numCtrl   = TextEditingController();   // campo número externo
  String  _maquinaId  = '';
  bool    _sinMaquina = false;
  bool    _loading    = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(ticketsRepoProvider).create(
          maquinaId:   _sinMaquina ? null : _maquinaId,
          descripcion: _descCtrl.text.trim(),
          observacion: _obsCtrl.text.trim().isEmpty
              ? null : _obsCtrl.text.trim(),
          numero:      _numCtrl.text.trim().isEmpty
              ? null : _numCtrl.text.trim());
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
      if (mounted) setState(() => _loading = false);
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

              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorContainer(_error!),
              ],
              const SizedBox(height: 28),
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
