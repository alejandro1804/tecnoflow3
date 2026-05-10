// lib/screens/tickets/ticket_detalle_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../maquinas/repuestos_maquina_screen.dart';
import '../movimientos/salida_form_screen.dart';

final _ticketProvider = FutureProvider.family<Ticket?, String>(
    (ref, id) => ref.watch(ticketsRepoProvider).getById(id));

final _historialProvider = FutureProvider.family<List<TicketHistorial>, String>(
    (ref, id) => ref.watch(ticketsRepoProvider).getHistorial(id));

class TicketDetalleScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetalleScreen({super.key, required this.ticketId});
  @override
  ConsumerState<TicketDetalleScreen> createState() => _State();
}

class _State extends ConsumerState<TicketDetalleScreen> {
  bool _loading      = false;
  bool _generandoPdf = false;
  String? _error;

  // ── Generar PDF del ticket ────────────────────────────────
  Future<void> _exportarPdf(Ticket ticket, List<TicketHistorial> historial) async {
    setState(() => _generandoPdf = true);
    try {
      final pdf   = pw.Document();
      final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      String labelEstado(String e) {
        switch (e) {
          case 'abierto':      return 'Abierto';
          case 'asignado':     return 'Asignado';
          case 'en_ejecucion': return 'En ejecución';
          case 'en_espera':    return 'En espera';
          case 'cerrado':      return 'Cerrado';
          default:             return e;
        }
      }

      PdfColor colorEstado(String e) {
        switch (e) {
          case 'abierto':      return PdfColors.orange;
          case 'asignado':     return PdfColors.blue;
          case 'en_ejecucion': return PdfColors.teal;
          case 'en_espera':    return PdfColors.purple;
          case 'cerrado':      return PdfColors.grey;
          default:             return PdfColors.grey;
        }
      }

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(
                  color: PdfColors.blueGrey300, width: 1))),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('TECNOFLOW3', style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800)),
              pw.Text('Control de stock de repuestos',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.blueGrey600)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Detalle de Ticket', style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Emitido: $ahora',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600)),
            ]),
          ]),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(
                  color: PdfColors.blueGrey300, width: 1))),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Text('Ticket ID: ${ticket.id.substring(0, 8)}...',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey400)),
            pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
          ]),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 16),

          // ── Datos del ticket ──────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blueGrey200)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                pw.Text(ticket.maquinaNombre ?? 'Sin máquina',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                      color: colorEstado(ticket.estado),
                      borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text(labelEstado(ticket.estado),
                      style: pw.TextStyle(
                          fontSize: 11, color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ]),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.blueGrey200),
              pw.SizedBox(height: 8),
              _pdfFila('Creado por', ticket.creadoPorNombre ?? '—'),
              _pdfFila('Técnico', ticket.tecnicoNombre ?? 'Sin asignar'),
              _pdfFila('Fecha', ticket.createdAt.toString().substring(0, 10)),
            ]),
          ),
          pw.SizedBox(height: 16),

          // ── Descripción del desperfecto ───────────
          pw.Text('DESPERFECTO', style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey600,
              letterSpacing: 1)),
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blueGrey200)),
            child: pw.Text(ticket.descripcionDesperfecto,
                style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 12),

          // ── Observación encargado ─────────────────
          if (ticket.observacionEncargado != null) ...[
            pw.Text('OBSERVACIÓN ENCARGADO', style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey600, letterSpacing: 1)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.orange200)),
              child: pw.Text(ticket.observacionEncargado!,
                  style: const pw.TextStyle(fontSize: 11)),
            ),
            pw.SizedBox(height: 12),
          ],

          // ── Observación técnico ───────────────────
          if (ticket.observacionTecnico != null) ...[
            pw.Text('OBSERVACIÓN TÉCNICO', style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey600, letterSpacing: 1)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.teal50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.teal200)),
              child: pw.Text(ticket.observacionTecnico!,
                  style: const pw.TextStyle(fontSize: 11)),
            ),
            pw.SizedBox(height: 12),
          ],

          // ── Historial ─────────────────────────────
          pw.SizedBox(height: 4),
          pw.Text('HISTORIAL DE CAMBIOS', style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey600, letterSpacing: 1)),
          pw.SizedBox(height: 8),

          if (historial.isEmpty)
            pw.Text('Sin cambios registrados',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Fecha', 'Usuario', 'Estado anterior', 'Estado nuevo', 'Comentario'],
              headerStyle: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              headerPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2.5),
              },
              data: historial.map((h) => [
                h.fecha.toString().substring(0, 16),
                h.usuarioNombre ?? '—',
                h.estadoAnterior != null
                    ? labelEstado(h.estadoAnterior!) : '—',
                labelEstado(h.estadoNuevo),
                h.comentario ?? '—',
              ]).toList(),
              cellDecoration: (index, data, rowIndex) => pw.BoxDecoration(
                  color: rowIndex % 2 == 0
                      ? PdfColors.white : PdfColors.blueGrey50),
            ),
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (f) async => pdf.save(),
        name: 'ticket_${ticket.id.substring(0, 8)}_'
            '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  static pw.Widget _pdfFila(String label, String value) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Text('$label: ', style: pw.TextStyle(
              fontSize: 10, color: PdfColors.blueGrey600)),
          pw.Text(value, style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  Future<void> _asignarTecnico(String ticketId) async {
    final usuarios = await ref.read(usuariosRepoProvider).getAll();
    final tecnicos = usuarios.where((u) => u.isTecnico).toList();
    if (!mounted) return;
    final tecnicoId = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Asignar técnico'),
        children: tecnicos.map((t) => SimpleDialogOption(
          child: Text(t.nombre),
          onPressed: () => Navigator.pop(context, t.id),
        )).toList(),
      ),
    );
    if (tecnicoId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(ticketsRepoProvider).asignarTecnico(ticketId, tecnicoId);
      ref.invalidate(_ticketProvider(ticketId));
      ref.invalidate(ticketsProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cambiarEstado(String ticketId, String nuevoEstado) async {
    String? comentario;
    if (nuevoEstado == TicketEstados.enEspera) {
      final ctrl = TextEditingController();
      comentario = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Motivo de espera'),
          content: TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Descripción del motivo...')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, ctrl.text),
                child: const Text('Confirmar')),
          ],
        ),
      );
      if (comentario == null) return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(ticketsRepoProvider).updateEstado(ticketId, nuevoEstado,
          comentario: comentario);
      ref.invalidate(_ticketProvider(ticketId));
      ref.invalidate(_historialProvider(ticketId));
      ref.invalidate(ticketsProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cerrar(String ticketId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar ticket'),
        content: const Text('¿Confirmar cierre definitivo del ticket?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await ref.read(ticketsRepoProvider).cerrar(ticketId);
      ref.invalidate(_ticketProvider(ticketId));
      ref.invalidate(ticketsProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync    = ref.watch(_ticketProvider(widget.ticketId));
    final historialAsync = ref.watch(_historialProvider(widget.ticketId));
    final profile        = ref.watch(myProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de ticket'),
        actions: [
          // Botón PDF — solo si el ticket y el historial están cargados
          if (ticketAsync.valueOrNull != null)
            _generandoPdf
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)))
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Exportar PDF',
                    onPressed: () => _exportarPdf(
                        ticketAsync.value!,
                        historialAsync.valueOrNull ?? [])),
        ],
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (ticket) {
          if (ticket == null) {
            return const Center(child: Text('Ticket no encontrado'));
          }
          final isAdmin    = profile?.isAdmin ?? false;
          final isTecnico  = profile?.isTecnico ?? false;
          final esAsignado = ticket.tecnicoId == profile?.id;

          return ListView(padding: const EdgeInsets.all(16), children: [

            // ── Cabecera ──────────────────────────────
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(ticket.maquinaNombre ?? '',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800))),
                  EstadoBadge(ticket.estado),
                ]),
                const SizedBox(height: 12),
                _InfoRow(Icons.person_outline, 'Creado por',
                    ticket.creadoPorNombre ?? ''),
                _InfoRow(Icons.engineering_outlined, 'Técnico',
                    ticket.tecnicoNombre ?? 'Sin asignar'),
                _InfoRow(Icons.calendar_today_outlined, 'Fecha',
                    ticket.createdAt.toString().substring(0, 10)),
              ]),
            )),

            // ── Ver repuestos de la máquina ───────────
            if (isAdmin || isTecnico)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton.icon(
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: Text(
                        'Ver repuestos de ${ticket.maquinaNombre ?? 'la máquina'}'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 12),
                        side: BorderSide(color: Colors.blue.withOpacity(0.4)),
                        foregroundColor: Colors.blue),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProviderScope(
                            parent: ProviderScope.containerOf(context),
                            child: RepuestosMaquinaScreen(
                                maquinaId:     ticket.maquinaId ?? '',
                                maquinaNombre: ticket.maquinaNombre ?? 'Máquina')))))),

            // ── Registrar salida ──────────────────────
            if ((isAdmin || (isTecnico && esAsignado)) &&
                ticket.estado != TicketEstados.cerrado)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700]),
                    icon: const Icon(Icons.output_outlined),
                    label: const Text('Registrar salida de repuesto'),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProviderScope(
                            parent: ProviderScope.containerOf(context),
                            child: SalidaFormScreen(
                                ticketIdInicial: ticket.id,
                                maquinaId: ticket.maquinaId)))))),

            // ── Descripción ───────────────────────────
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('DESPERFECTO', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(ticket.descripcionDesperfecto),
                if (ticket.observacionEncargado != null) ...[
                  const SizedBox(height: 12),
                  const Text('OBSERVACIÓN ENCARGADO', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(ticket.observacionEncargado!),
                ],
                if (ticket.observacionTecnico != null) ...[
                  const SizedBox(height: 12),
                  const Text('OBSERVACIÓN TÉCNICO', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(ticket.observacionTecnico!),
                ],
              ]),
            )),

            // ── Acciones ──────────────────────────────
            if (_loading)
              const Center(child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator())),
            if (_error != null) ErrorContainer(_error!),

            if (isAdmin && ticket.estado == TicketEstados.abierto)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.engineering_outlined),
                    label: const Text('Asignar técnico'),
                    onPressed: _loading ? null : () => _asignarTecnico(ticket.id))),

            if (isAdmin &&
                ticket.estado != TicketEstados.cerrado &&
                ticket.estado != TicketEstados.abierto)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Cerrar ticket'),
                    onPressed: _loading ? null : () => _cerrar(ticket.id))),

            if (isTecnico && esAsignado &&
                ticket.estado == TicketEstados.asignado)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Iniciar ejecución'),
                    onPressed: _loading ? null
                        : () => _cambiarEstado(ticket.id, TicketEstados.enEjecucion))),

            if (isTecnico && esAsignado &&
                ticket.estado == TicketEstados.enEjecucion)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Poner en espera'),
                    onPressed: _loading ? null
                        : () => _cambiarEstado(ticket.id, TicketEstados.enEspera))),

            if (isTecnico && esAsignado &&
                ticket.estado == TicketEstados.enEspera)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Reanudar ejecución'),
                    onPressed: _loading ? null
                        : () => _cambiarEstado(ticket.id, TicketEstados.enEjecucion))),

            const SizedBox(height: 16),

            // ── Historial ─────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('HISTORIAL', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1))),

            historialAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Text('Error: $e'),
              data: (historial) => historial.isEmpty
                  ? const Card(child: ListTile(
                      title: Text('Sin cambios registrados')))
                  : Column(
                      children: historial.map((h) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                  radius: 16,
                                  child: Icon(Icons.history, size: 16)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 4, runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (h.estadoAnterior != null) ...[
                                          EstadoBadge(h.estadoAnterior!),
                                          const Icon(Icons.arrow_forward,
                                              size: 13, color: Colors.grey),
                                        ],
                                        EstadoBadge(h.estadoNuevo),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(h.usuarioNombre ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12)),
                                    if (h.comentario != null)
                                      Text(h.comentario!,
                                          style: const TextStyle(fontSize: 12)),
                                    Text(h.fecha.toString().substring(0, 16),
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList()),
            ),
          ]);
        }),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Expanded(child: Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12))),
      ]));
}
