// lib/screens/tickets/ticket_detalle_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

// ── Helper de formato de fechas (UTC → hora local) ────────────
String _fmtFecha(dynamic fecha, {bool soloFecha = false}) {
  if (fecha == null) return '—';
  final dt = (fecha is DateTime) ? fecha : DateTime.parse(fecha.toString());
  final local = dt.toLocal();
  return soloFecha
      ? DateFormat('dd/MM/yyyy').format(local)
      : DateFormat('dd/MM/yyyy HH:mm').format(local);
}

class TicketDetalleScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketDetalleScreen({super.key, required this.ticketId});
  @override
  ConsumerState<TicketDetalleScreen> createState() => _State();
}

class _State extends ConsumerState<TicketDetalleScreen> {
  bool _loading      = false;
  bool _generandoPdf = false;
  bool _subiendoFoto = false;
  String? _error;

  // ── helpers de label/color compartidos ───────────────────────
  static String labelEstado(String e) {
    switch (e) {
      case 'abierto':      return 'Abierto';
      case 'asignado':     return 'Asignado';
      case 'en_ejecucion': return 'En ejecución';
      case 'en_espera':    return 'En espera';
      case 'en_revision':  return 'En revisión';
      case 'cerrado':      return 'Cerrado';
      default:             return e;
    }
  }

  static PdfColor colorEstadoPdf(String e) {
    switch (e) {
      case 'abierto':      return PdfColors.orange;
      case 'asignado':     return PdfColors.blue;
      case 'en_ejecucion': return PdfColors.teal;
      case 'en_espera':    return PdfColors.purple;
      case 'en_revision':  return PdfColors.indigo;
      case 'cerrado':      return PdfColors.grey;
      default:             return PdfColors.grey;
    }
  }

  // ── exportar PDF ─────────────────────────────────────────────
  Future<void> _exportarPdf(Ticket ticket, List<TicketHistorial> historial) async {
    setState(() => _generandoPdf = true);
    try {
      final pdf   = pw.Document();
      final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

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
            pw.Text(
                ticket.numero != null
                    ? 'N° ${ticket.numero!}  |  ID: ${ticket.id.substring(0, 8)}...'
                    : 'Ticket ID: ${ticket.id.substring(0, 8)}...',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey400)),
            pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
          ]),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 16),
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
                pw.Expanded(child: pw.Text(
                    ticket.maquinaNombre ?? 'Sin máquina',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold))),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                      color: colorEstadoPdf(ticket.estado),
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
              if (ticket.numero != null)
                _pdfFila('N° Externo', ticket.numero!),
              _pdfFila('Creado por', ticket.creadoPorNombre ?? '—'),
              _pdfFila('Técnico', ticket.tecnicoNombre ?? 'Sin asignar'),
              _pdfFila('Fecha', _fmtFecha(ticket.createdAt, soloFecha: true)),
            ]),
          ),
          pw.SizedBox(height: 16),
          pw.Text('DESPERFECTO', style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey600, letterSpacing: 1)),
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
              headerStyle: pw.TextStyle(fontSize: 9,
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8),
                1: const pw.FlexColumnWidth(1.8),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(2.5),
              },
              data: historial.map((h) => [
                _fmtFecha(h.fecha),
                h.usuarioNombre ?? '—',
                h.estadoAnterior != null ? labelEstado(h.estadoAnterior!) : '—',
                labelEstado(h.estadoNuevo),
                h.comentario ?? '—',
              ]).toList(),
              cellDecoration: (index, data, rowIndex) => pw.BoxDecoration(
                  color: rowIndex % 2 == 0 ? PdfColors.white : PdfColors.blueGrey50),
            ),
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (f) async => pdf.save(),
        name: 'ticket_${ticket.numero ?? ticket.id.substring(0, 8)}_'
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

  // ── foto: seleccionar fuente ──────────────────────────────────
  Future<File?> _elegirFoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return null;
    final p = await ImagePicker().pickImage(
        source: source, imageQuality: 80, maxWidth: 1200);
    return p == null ? null : File(p.path);
  }

  // ── actualizar foto principal ─────────────────────────────────
  Future<void> _actualizarFotoPrincipal(String ticketId) async {
    final archivo = await _elegirFoto();
    if (archivo == null) return;
    setState(() => _subiendoFoto = true);
    try {
      final url = await ref.read(ticketFotosRepoProvider)
          .subirFoto(archivo, ticketId);
      await ref.read(ticketsRepoProvider).updateFotoUrl(ticketId, url);
      ref.invalidate(_ticketProvider(ticketId));
      ref.invalidate(ticketsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir foto: $e'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  // ── agregar foto adicional ────────────────────────────────────
  Future<void> _agregarFotoAdicional(String ticketId) async {
    final archivo = await _elegirFoto();
    if (archivo == null) return;
    final descCtrl = TextEditingController();
    final descripcion = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descripción de la foto'),
        content: TextField(
          controller: descCtrl,
          decoration: const InputDecoration(
              hintText: 'Ej: Rodamiento dañado, cable quemado... (opcional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Sin descripción')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, descCtrl.text.trim()),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (descripcion == null) return;
    setState(() => _subiendoFoto = true);
    try {
      final url = await ref.read(ticketFotosRepoProvider)
          .subirFoto(archivo, ticketId);
      await ref.read(ticketFotosRepoProvider).agregarFoto(
          ticketId:    ticketId,
          fotoUrl:     url,
          descripcion: descripcion.isEmpty ? null : descripcion);
      ref.invalidate(ticketFotosProvider(ticketId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir foto: $e'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  // ── eliminar foto adicional ───────────────────────────────────
  Future<void> _eliminarFotoAdicional(TicketFoto foto, String ticketId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Confirmás que querés eliminar esta foto?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ticketFotosRepoProvider).eliminarFoto(foto);
      ref.invalidate(ticketFotosProvider(ticketId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red));
    }
  }

  // ── ver foto en pantalla completa ─────────────────────────────
  void _verFoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          Center(child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain))),
          Positioned(
            top: 40, right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ]),
      ),
    );
  }

  // ── asignar técnico ───────────────────────────────────────────
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

  // ── cambiar estado genérico ───────────────────────────────────
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

  // ── enviar a revisión (técnico) ───────────────────────────────
  Future<void> _enviarARevision(String ticketId) async {
    final ctrl = TextEditingController();
    final comentario = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.rate_review_outlined, color: Colors.indigo),
          SizedBox(width: 8),
          Text('Enviar a revisión'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Describí brevemente el trabajo realizado o el motivo por el que enviás el ticket a revisión.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ej: Reparación completada, se reemplazó rodamiento...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Enviar'),
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(context, ctrl.text.trim());
              }),
        ],
      ),
    );
    if (comentario == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(ticketsRepoProvider).updateEstado(
          ticketId, TicketEstados.enRevision,
          comentario: comentario);
      ref.invalidate(_ticketProvider(ticketId));
      ref.invalidate(_historialProvider(ticketId));
      ref.invalidate(ticketsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ticket enviado a revisión'),
            backgroundColor: Colors.indigo));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── cerrar ticket (admin) ─────────────────────────────────────
  Future<void> _cerrar(String ticketId, Ticket ticket) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.check_circle_outline, color: Colors.green),
          SizedBox(width: 8),
          Text('Cerrar ticket'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Icon(Icons.rate_review_outlined,
                    size: 14, color: Colors.indigo),
                const SizedBox(width: 6),
                const Text('En revisión — trabajo reportado:',
                    style: TextStyle(
                        fontSize: 11, color: Colors.indigo,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Text(
                ticket.observacionTecnico ?? 'Sin observación del técnico',
                style: const TextStyle(fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          const Text('Observación de cierre (opcional):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: Revisado y aprobado, máquina operativa...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Esta acción es definitiva. El ticket quedará cerrado.',
            style: TextStyle(fontSize: 11, color: Colors.red),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Confirmar cierre'),
              onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      final uid        = Supabase.instance.client.auth.currentUser!.id;
      final comentario = ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : null;
      final maquina    = ticket.maquinaNombre ?? 'Sin máquina';
      final numero     = ticket.numero != null ? ' (${ticket.numero})' : '';

      // 1. Cerrar el ticket
      await ref.read(ticketsRepoProvider).updateEstado(
          ticketId, TicketEstados.cerrado,
          comentario: comentario);

      // 2. Buscar todos los encargados activos
      final usuarios   = await ref.read(usuariosRepoProvider).getAll();
      final encargados = usuarios.where((u) => u.isEncargado).toList();

      // 3. Crear notificación para cada encargado
      for (final encargado in encargados) {
        await ref.read(notificacionesRepoProvider).crear(
          tipo:          TiposNotificacion.ticketCerrado,
          mensaje:       'Máquina operativa: $maquina$numero — ticket cerrado.',
          paraUsuarioId: encargado.id,
          ticketId:      ticketId,
          deUsuarioId:   uid,
        );
      }

      ref.invalidate(_ticketProvider(ticketId));
      ref.invalidate(_historialProvider(ticketId));
      ref.invalidate(ticketsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ticket cerrado correctamente'),
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
    final ticketAsync    = ref.watch(_ticketProvider(widget.ticketId));
    final historialAsync = ref.watch(_historialProvider(widget.ticketId));
    final fotosAsync     = ref.watch(ticketFotosProvider(widget.ticketId));
    final confirAsync    = ref.watch(confirmacionesTicketProvider(widget.ticketId));
    final profile        = ref.watch(myProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de ticket'),
        actions: [
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
          final isAdmin     = profile?.isAdmin ?? false;
          final isTecnico   = profile?.isTecnico ?? false;
          final isEncargado = profile?.isEncargado ?? false;
          final esAsignado  = ticket.tecnicoId == profile?.id;
          final puedeEditarFotoPrincipal =
              (isAdmin || isEncargado) &&
              ticket.estado != TicketEstados.cerrado;
          final puedeAgregarFotos =
              (isAdmin || (isTecnico && esAsignado)) &&
              ticket.estado != TicketEstados.cerrado;

          return ListView(padding: const EdgeInsets.all(16), children: [

            // ── Cabecera ──────────────────────────────
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticket.maquinaNombre ?? 'Sin máquina',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  if (ticket.numero != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.indigo.withOpacity(0.3))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.tag, size: 12, color: Colors.indigo),
                        const SizedBox(width: 3),
                        Text(ticket.numero!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.indigo,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  const Spacer(),
                  EstadoBadge(ticket.estado),
                ]),
                const SizedBox(height: 12),
                _InfoRow(Icons.person_outline, 'Creado por',
                    ticket.creadoPorNombre ?? ''),
                _InfoRow(Icons.engineering_outlined, 'Técnico',
                    ticket.tecnicoNombre ?? 'Sin asignar'),
                _InfoRow(Icons.calendar_today_outlined, 'Fecha',
                    _fmtFecha(ticket.createdAt, soloFecha: true)),
              ]),
            )),

            // ── Banner "en revisión" ──────────────────
            if (isAdmin && ticket.estado == TicketEstados.enRevision)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.withOpacity(0.3))),
                child: Row(children: const [
                  Icon(Icons.rate_review_outlined,
                      color: Colors.indigo, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El técnico reportó el trabajo como completado y aguarda tu revisión para cerrar el ticket.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.indigo,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ),

            // ── Ver repuestos de la máquina ───────────
            if ((isAdmin || isTecnico) && ticket.maquinaId != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 9),
                        side: BorderSide(color: Colors.blue.withOpacity(0.4)),
                        foregroundColor: Colors.blue),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProviderScope(
                            parent: ProviderScope.containerOf(context),
                            child: RepuestosMaquinaScreen(
                                maquinaId:     ticket.maquinaId ?? '',
                                maquinaNombre: ticket.maquinaNombre ?? 'Máquina')))),
                    child: Text(
                        'Ver repuestos de ${ticket.maquinaNombre ?? 'la máquina'}'))),

            // ── Registrar salida ──────────────────────
            if ((isAdmin || (isTecnico && esAsignado)) &&
                ticket.estado != TicketEstados.cerrado &&
                ticket.estado != TicketEstados.enRevision)
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

            // ── Sección FOTOS ─────────────────────────
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                const Text('FOTOS', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey, letterSpacing: 1)),
                const Spacer(),
                if (_subiendoFoto)
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
            ),

            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // ── Foto principal ────────────────────
                const Text('Foto del desperfecto', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.grey)),
                const SizedBox(height: 10),

                if (ticket.fotoUrl != null)
                  Stack(children: [
                    GestureDetector(
                      onTap: () => _verFoto(context, ticket.fotoUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          ticket.fotoUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null ? child
                                  : const SizedBox(height: 200,
                                      child: Center(
                                          child: CircularProgressIndicator())),
                        ),
                      ),
                    ),
                    if (puedeEditarFotoPrincipal)
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => _actualizarFotoPrincipal(ticket.id),
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(Icons.edit_outlined,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ])
                else if (puedeEditarFotoPrincipal)
                  GestureDetector(
                    onTap: () => _actualizarFotoPrincipal(ticket.id),
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.withOpacity(0.3))),
                      child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 28, color: Colors.grey),
                        SizedBox(height: 6),
                        Text('Agregar foto del desperfecto',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ]),
                    ),
                  )
                else
                  const Text('Sin foto del desperfecto',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),

                // ── Fotos adicionales ─────────────────
                const SizedBox(height: 20),
                Row(children: [
                  const Text('Fotos adicionales', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.grey)),
                  const Spacer(),
                  if (puedeAgregarFotos)
                    TextButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          size: 16),
                      label: const Text('Agregar',
                          style: TextStyle(fontSize: 12)),
                      onPressed: _subiendoFoto
                          ? null : () => _agregarFotoAdicional(ticket.id),
                    ),
                ]),
                const SizedBox(height: 8),

                fotosAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: Colors.red)),
                  data: (fotos) => fotos.isEmpty
                      ? const Text('Sin fotos adicionales',
                          style: TextStyle(color: Colors.grey, fontSize: 12))
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: fotos.length,
                          itemBuilder: (_, i) {
                            final foto = fotos[i];
                            return Stack(children: [
                              GestureDetector(
                                onTap: () => _verFoto(context, foto.fotoUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Column(children: [
                                    Expanded(
                                      child: Image.network(
                                        foto.fotoUrl,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (_, child, p) =>
                                            p == null ? child
                                                : const Center(child:
                                                    CircularProgressIndicator()),
                                      ),
                                    ),
                                    if (foto.descripcion != null)
                                      Container(
                                        width: double.infinity,
                                        color: Colors.black54,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        child: Text(foto.descripcion!,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                  ]),
                                ),
                              ),
                              if (isAdmin || foto.subidoPor == profile?.id)
                                Positioned(
                                  top: 4, right: 4,
                                  child: GestureDetector(
                                    onTap: () => _eliminarFotoAdicional(
                                        foto, ticket.id),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                            ]);
                          }),
                ),
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
                    onPressed: _loading ? null
                        : () => _asignarTecnico(ticket.id))),

            if (isAdmin && ticket.estado == TicketEstados.enRevision)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Cerrar ticket'),
                    onPressed: _loading ? null
                        : () => _cerrar(ticket.id, ticket))),

            if (isTecnico && esAsignado &&
                ticket.estado == TicketEstados.asignado)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Iniciar ejecución'),
                    onPressed: _loading ? null
                        : () => _cambiarEstado(
                            ticket.id, TicketEstados.enEjecucion))),

            if (isTecnico && esAsignado &&
                ticket.estado == TicketEstados.enEjecucion)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Poner en espera'),
                    onPressed: _loading ? null
                        : () => _cambiarEstado(
                            ticket.id, TicketEstados.enEspera))),

            if (isTecnico && esAsignado &&
                ticket.estado == TicketEstados.enEspera)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Reanudar ejecución'),
                    onPressed: _loading ? null
                        : () => _cambiarEstado(
                            ticket.id, TicketEstados.enEjecucion))),

            if (isTecnico && esAsignado &&
                (ticket.estado == TicketEstados.enEjecucion ||
                 ticket.estado == TicketEstados.enEspera))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Enviar a revisión'),
                    onPressed: _loading ? null
                        : () => _enviarARevision(ticket.id))),

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
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
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
                                    Text(_fmtFecha(h.fecha),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList()),
            ),

            // ── Confirmaciones de encargados ──────────
            if (ticket.estado == TicketEstados.cerrado) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('CONFIRMACIONES DE ENCARGADOS', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey, letterSpacing: 1))),
              confirAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (confirmaciones) => confirmaciones.isEmpty
                    ? const Card(child: ListTile(
                        leading: Icon(Icons.hourglass_empty_outlined,
                            color: Colors.grey),
                        title: Text('Sin confirmaciones aún',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey))))
                    : Column(
                        children: confirmaciones.map((c) => Card(
                          color: Colors.green[50],
                          child: ListTile(
                            leading: const Icon(Icons.how_to_reg_outlined,
                                color: Colors.green),
                            title: Text(c.deUsuarioNombre ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                            subtitle: Text(
                                _fmtFecha(c.createdAt),
                                style: const TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                          ),
                        )).toList()),
              ),
            ],
          ]);
        }),
    );
  }
}

// ── InfoRow ───────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Expanded(child: Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 10))),
      ]));
}
