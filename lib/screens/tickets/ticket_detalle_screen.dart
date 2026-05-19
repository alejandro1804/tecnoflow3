// lib/screens/tickets/ticket_detalle_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ── construir documento PDF ───────────────────────────────────
  Future<pw.Document> _buildPdf(
      Ticket ticket,
      List<TicketHistorial> historial,
      List<SalidaRepuesto> salidas) async {
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
            pw.Text('TALLER DE MANTENIMIENTO', style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold,
                color: PdfColors.black)),
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

        // ── Repuestos usados ──────────────────────────────────
        pw.SizedBox(height: 4),
        pw.Text('REPUESTOS USADOS', style: pw.TextStyle(
            fontSize: 11, fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey600, letterSpacing: 1)),
        pw.SizedBox(height: 8),
        if (salidas.isEmpty)
          pw.Text('Sin repuestos registrados',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Repuesto', 'Cantidad', 'Retiró'],
            headerStyle: pw.TextStyle(fontSize: 9,
                fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 5),
            cellStyle: const pw.TextStyle(fontSize: 9),
            columnWidths: {
              0: const pw.FlexColumnWidth(5.0),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(2.5),
            },
            data: salidas.map((s) => [
              s.repuestoDescripcion ?? '—',
              s.cantidad.toString(),
              s.quienRetira ?? '—',
            ]).toList(),
            cellDecoration: (index, data, rowIndex) => pw.BoxDecoration(
                color: rowIndex % 2 == 0
                    ? PdfColors.white : PdfColors.blueGrey50),
          ),
        pw.SizedBox(height: 12),

        // ── Historial ─────────────────────────────────────────
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

    return pdf;
  }

  String _nombreArchivo(Ticket ticket) =>
      'ticket_${ticket.numero ?? ticket.id.substring(0, 8)}_'
      '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

  Future<void> _imprimirPdf(
      Ticket ticket, List<TicketHistorial> historial,
      List<SalidaRepuesto> salidas) async {
    setState(() => _generandoPdf = true);
    try {
      final pdf = await _buildPdf(ticket, historial, salidas);
      await Printing.layoutPdf(
        onLayout: (f) async => pdf.save(),
        name: _nombreArchivo(ticket),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  Future<void> _compartirPdf(
      Ticket ticket, List<TicketHistorial> historial,
      List<SalidaRepuesto> salidas) async {
    setState(() => _generandoPdf = true);
    try {
      final pdf   = await _buildPdf(ticket, historial, salidas);
      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: _nombreArchivo(ticket),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al compartir PDF: $e'),
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

      await ref.read(ticketsRepoProvider).updateEstado(
          ticketId, TicketEstados.cerrado,
          comentario: comentario);

      final usuarios   = await ref.read(usuariosRepoProvider).getAll();
      final encargados = usuarios.where((u) => u.isEncargado).toList();

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

  // ── Bottom sheet: registrar salida de repuesto ────────────────
  Future<void> _mostrarBottomSheetSalida(
      Ticket ticket, String nombreTecnico, String? maquinaId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _SalidaBottomSheet(
          ticketId:      ticket.id,
          maquinaId:     maquinaId,
          nombreTecnico: nombreTecnico,
        ),
      ),
    );
    // Refrescar lista de repuestos usados al cerrar el sheet
    ref.invalidate(salidasPorTicketProvider(ticket.id));
    ref.invalidate(repuestosProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync    = ref.watch(_ticketProvider(widget.ticketId));
    final historialAsync = ref.watch(_historialProvider(widget.ticketId));
    final fotosAsync     = ref.watch(ticketFotosProvider(widget.ticketId));
    final confirAsync    = ref.watch(confirmacionesTicketProvider(widget.ticketId));
    final salidasAsync   = ref.watch(salidasPorTicketProvider(widget.ticketId));
    final profile        = ref.watch(myProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de ticket'),
        actions: [
          if (ticketAsync.valueOrNull != null)
            _generandoPdf
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)))
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'PDF',
                    onSelected: (v) {
                      final ticket    = ticketAsync.value!;
                      final historial = historialAsync.valueOrNull ?? [];
                      final salidas   = salidasAsync.valueOrNull ?? [];
                      if (v == 'imprimir') {
                        _imprimirPdf(ticket, historial, salidas);
                      } else {
                        _compartirPdf(ticket, historial, salidas);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'imprimir',
                        child: Row(children: [
                          Icon(Icons.print_outlined,
                              size: 18, color: Colors.blueGrey),
                          SizedBox(width: 10),
                          Text('Imprimir / Vista previa'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'compartir',
                        child: Row(children: [
                          Icon(Icons.share_outlined,
                              size: 18, color: Colors.blueGrey),
                          SizedBox(width: 10),
                          Text('Compartir PDF'),
                        ]),
                      ),
                    ],
                  ),
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
          final puedeRegistrarSalida =
              (isAdmin || (isTecnico && esAsignado)) &&
              ticket.estado != TicketEstados.cerrado &&
              ticket.estado != TicketEstados.enRevision;

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

            // ── Botón registrar salida ────────────────
            if (puedeRegistrarSalida)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700]),
                    icon: const Icon(Icons.output_outlined),
                    label: const Text('Registrar salida de repuesto'),
                    onPressed: () => _mostrarBottomSheetSalida(
                        ticket,
                        profile?.nombre ?? '',
                        ticket.maquinaId))),

            // ── REPUESTOS USADOS ──────────────────────
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('REPUESTOS USADOS', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1)),
            ),
            salidasAsync.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator())),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: Colors.red)),
              data: (salidas) => salidas.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: const [
                          Icon(Icons.inventory_2_outlined,
                              color: Colors.grey, size: 18),
                          SizedBox(width: 10),
                          Text('Sin repuestos registrados',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ]),
                      ))
                  : Card(
                      child: Column(
                        children: [
                          // encabezado de tabla
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(children: const [
                              Expanded(
                                flex: 5,
                                child: Text('Repuesto', style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                    letterSpacing: 0.5)),
                              ),
                              SizedBox(width: 8),
                              Text('Cant.', style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                            ]),
                          ),
                          const Divider(height: 1),
                          // filas
                          ...salidas.asMap().entries.map((entry) {
                            final i = entry.key;
                            final s = entry.value;
                            return Container(
                              color: i % 2 == 0
                                  ? Colors.transparent
                                  : Colors.grey.withOpacity(0.04),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.repuestoDescripcion ?? '—',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      if (s.quienRetira != null)
                                        Text(
                                          'Retiró: ${s.quienRetira}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: Colors.red
                                          .withOpacity(0.08),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.red
                                              .withOpacity(0.2))),
                                  child: Text(
                                    '${s.cantidad}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red),
                                  ),
                                ),
                              ]),
                            );
                          }),
                          // total
                          if (salidas.length > 1) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(children: [
                                const Expanded(
                                  flex: 5,
                                  child: Text('Total unidades',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${salidas.fold(0, (sum, s) => sum + s.cantidad)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red),
                                ),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),

            // ── Descripción ───────────────────────────
            const SizedBox(height: 8),
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

// ── Bottom Sheet: registrar salida de repuesto ────────────────
class _SalidaBottomSheet extends ConsumerStatefulWidget {
  final String  ticketId;
  final String? maquinaId;
  final String  nombreTecnico;

  const _SalidaBottomSheet({
    required this.ticketId,
    required this.maquinaId,
    required this.nombreTecnico,
  });

  @override
  ConsumerState<_SalidaBottomSheet> createState() => _SalidaBottomSheetState();
}

class _SalidaBottomSheetState extends ConsumerState<_SalidaBottomSheet> {
  final _cantCtrl  = TextEditingController(text: '0');
  final _busqCtrl  = TextEditingController();
  final _refCtrl   = TextEditingController();

  String?          _repuestoId;
  String?          _repuestoDescripcion;
  int?             _stockDisponible;
  String           _busqueda    = '';
  String           _busquedaRef = '';
  bool             _loading     = false;
  String?          _error;

  List<Repuesto>?  _repuestosMaquina;
  bool             _cargandoRepuestos = false;

  @override
  void initState() {
    super.initState();
    if (widget.maquinaId != null) {
      Future.microtask(() => _cargarRepuestosMaquina());
    }
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _busqCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarRepuestosMaquina() async {
    setState(() => _cargandoRepuestos = true);
    try {
      final items = await ref
          .read(repuestosMaquinasRepoProvider)
          .getByMaquina(widget.maquinaId!);
      final todosRepuestos = ref.read(repuestosProvider).valueOrNull ?? [];
      final idsEnMaquina   = items.map((m) => m.repuestoId).toSet();
      final filtrados = todosRepuestos
          .where((r) => idsEnMaquina.contains(r.id))
          .toList()
        ..sort((a, b) => a.descripcion.compareTo(b.descripcion));
      setState(() {
        _repuestosMaquina  = filtrados.isEmpty ? null : filtrados;
        _cargandoRepuestos = false;
      });
    } catch (_) {
      setState(() => _cargandoRepuestos = false);
    }
  }

  Future<void> _registrar() async {
    if (_repuestoId == null) {
      setState(() => _error = 'Seleccioná un repuesto');
      return;
    }
    final cantidad = int.tryParse(_cantCtrl.text) ?? 0;
    if (cantidad <= 0) {
      setState(() => _error = 'La cantidad debe ser mayor a 0');
      return;
    }
    if (_stockDisponible != null && cantidad > _stockDisponible!) {
      setState(() => _error = 'Stock insuficiente (disponible: $_stockDisponible)');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(movimientosRepoProvider).createSalida(
        repuestoId:  _repuestoId!,
        cantidad:    cantidad,
        ticketId:    widget.ticketId,
        quienRetira: widget.nombreTecnico.isNotEmpty
            ? widget.nombreTecnico : null,
      );
      ref.invalidate(salidasProvider);
      ref.invalidate(repuestosProvider);
      ref.invalidate(salidasPorTicketProvider(widget.ticketId));
      if (mounted) {
        Navigator.pop(context);
        // El snackbar se muestra desde el contexto del padre
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Salida registrada'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.contains('Stock insuficiente')
          ? 'Stock insuficiente. Verificá la cantidad disponible.'
          : 'Error al registrar. Intentá nuevamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todosRepuestos = ref.watch(repuestosProvider).valueOrNull ?? [];
    final fuente = _repuestosMaquina ?? todosRepuestos;

    List<Repuesto> filtrados;
    if (_busquedaRef.isNotEmpty) {
      final refNum = int.tryParse(_busquedaRef);
      filtrados = refNum != null
          ? fuente.where((r) => r.ref == refNum).toList()
          : [];
    } else if (_busqueda.isNotEmpty) {
      filtrados = fuente.where((r) =>
          (r.codigo ?? '').toLowerCase().contains(_busqueda.toLowerCase()) ||
          r.descripcion.toLowerCase().contains(_busqueda.toLowerCase()))
          .toList()
        ..sort((a, b) => a.descripcion.compareTo(b.descripcion));
    } else {
      filtrados = [];
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Título ────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.output_outlined,
                    color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Registrar salida de repuesto',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),

            // ── Técnico (solo lectura) ────────────────
            if (widget.nombreTecnico.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.teal.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.engineering_outlined,
                      size: 16, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text('Retira: ${widget.nombreTecnico}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.teal,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],

            // ── Repuesto seleccionado ─────────────────
            if (_repuestoId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _repuestoDescripcion ?? '',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_stockDisponible != null)
                    Text('Stock: $_stockDisponible',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _repuestoId          = null;
                      _repuestoDescripcion = null;
                      _stockDisponible     = null;
                      _busqCtrl.clear();
                      _refCtrl.clear();
                      _busqueda    = '';
                      _busquedaRef = '';
                    }),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.grey),
                  ),
                ]),
              ),
            ],

            // ── Buscador ──────────────────────────────
            if (_repuestoId == null) ...[
              const SizedBox(height: 16),
              if (_repuestosMaquina != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.precision_manufacturing_outlined,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                        'Repuestos de la máquina (${_repuestosMaquina!.length})',
                        style: const TextStyle(
                            fontSize: 9, color: Colors.blue)),
                  ]),
                ),
              if (_cargandoRepuestos)
                const Center(child: CircularProgressIndicator())
              else ...[
                TextField(
                  controller: _busqCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                      labelText: 'Buscar por código o descripción',
                      prefixIcon: Icon(Icons.search),
                      labelStyle: TextStyle(fontSize: 11),
                      isDense: true),
                  onChanged: (v) => setState(() {
                    _busqueda    = v;
                    _busquedaRef = '';
                    _refCtrl.clear();
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _refCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Buscar por N° REF',
                    prefixIcon: const Icon(Icons.tag,
                        color: Colors.purple, size: 20),
                    labelStyle: const TextStyle(
                        fontSize: 11, color: Colors.purple),
                    isDense: true,
                    suffixIcon: _busquedaRef.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _refCtrl.clear();
                              setState(() {
                                _busquedaRef = '';
                              });
                            })
                        : null,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.purple.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Colors.purple)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() {
                    _busquedaRef = v;
                    _busqueda    = '';
                    _busqCtrl.clear();
                  }),
                ),
                if (filtrados.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtrados.length,
                      itemBuilder: (_, i) {
                        final r       = filtrados[i];
                        final sinStock = r.stockActual == 0;
                        return ListTile(
                          dense: true,
                          enabled: !sinStock,
                          leading: StockBadge(
                              stock: r.stockActual,
                              minimo: r.stockMinimo),
                          title: Text(r.descripcion,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: sinStock
                                      ? Colors.grey : null)),
                          subtitle: Text(
                              sinStock
                                  ? 'Sin stock'
                                  : 'Stock: ${r.stockActual}'
                                    '${r.ref != null ? '  •  REF ${r.ref}' : ''}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: sinStock
                                      ? Colors.red : null)),
                          onTap: sinStock
                              ? null
                              : () => setState(() {
                                    _repuestoId          = r.id;
                                    _repuestoDescripcion = r.descripcion;
                                    _stockDisponible     = r.stockActual;
                                    _busqueda            = '';
                                    _busquedaRef         = '';
                                    _busqCtrl.clear();
                                    _refCtrl.clear();
                                  }),
                        );
                      },
                    ),
                  ),
                ] else if (_busqueda.isNotEmpty || _busquedaRef.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Sin resultados',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ],
            ],

            // ── Cantidad ──────────────────────────────
            const SizedBox(height: 16),
            Row(children: [
              const Text('CANTIDAD', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.grey, letterSpacing: 1)),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: () {
                      final v = int.tryParse(_cantCtrl.text) ?? 0;
                      if (v > 0) setState(() => _cantCtrl.text = '${v - 1}');
                    },
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      _cantCtrl.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () {
                      final v = int.tryParse(_cantCtrl.text) ?? 0;
                      if (_stockDisponible == null || v < _stockDisponible!) {
                        setState(() => _cantCtrl.text = '${v + 1}');
                      }
                    },
                  ),
                ]),
              ),
            ]),

            if (_error != null) ...[
              const SizedBox(height: 10),
              ErrorContainer(_error!),
            ],

            // ── Botón confirmar ───────────────────────
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.output_outlined),
              label: Text(
                _loading ? 'Registrando...' : 'Confirmar salida',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onPressed: (_loading || _repuestoId == null) ? null : _registrar,
            ),
          ],
        ),
      ),
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