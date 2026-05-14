// lib/core/PdfGenerator.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import '../models/models.dart';

class PdfGenerator {

  static Future<void> _compartir(pw.Document pdf, String nombre) async {
    final bytes   = await pdf.save();
    final tempDir = await getTemporaryDirectory();
    final file    = File('${tempDir.path}/$nombre');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: nombre,
    );
  }

  // ── Genera imagen PNG del QR como bytes para incrustar en PDF ──
  static Future<Uint8List> _qrComoBytes(String data, double size) async {
    final qrPainter = QrPainter(
      data:                 data,
      version:              QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color:                const ui.Color(0xFF000000),
      emptyColor:           const ui.Color(0xFFFFFFFF),
    );
    final image    = await qrPainter.toImage(size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ── PDF QR de Máquina ─────────────────────────────────────
  // PDF A4 estándar con recuadro A6 apaisado centrado y línea de corte.
  static Future<void> generarQrMaquina({
    required Maquina               maquina,
    required List<RepuestoMaquina> repuestos,
  }) async {
    final qrBytes = await _qrComoBytes(maquina.id, 512);
    final qrImage = pw.MemoryImage(qrBytes);
    final pdf     = pw.Document();
    final ahora   = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // A6 apaisado en puntos
    const double a6W = 148 * PdfPageFormat.mm;
    const double a6H = 105 * PdfPageFormat.mm;
    // A4 vertical en puntos: 210mm × 297mm
    const double a4W = 210 * PdfPageFormat.mm;
    const double a4H = 297 * PdfPageFormat.mm;
    // Offsets para centrar A6 dentro de A4
    const double offX = (a4W - a6W) / 2;
    const double offY = (a4H - a6H) / 2;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin:     pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(
          children: [

            // Línea de corte punteada
            pw.Positioned(
              left: offX,
              top:  offY,
              child: pw.Container(
                width:  a6W,
                height: a6H,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.blueGrey300,
                    width: 0.5,
                    style: pw.BorderStyle.dashed,
                  ),
                ),
              ),
            ),

            // Texto guía de recorte
            pw.Positioned(
              left: offX,
              top:  offY - 11,
              child: pw.Text(
                'Recortar por la línea punteada',
                style: pw.TextStyle(
                    fontSize: 7, color: PdfColors.blueGrey300),
              ),
            ),

            // Contenido interno con padding
            pw.Positioned(
              left: offX + 14,
              top:  offY + 14,
              child: pw.SizedBox(
                width:  a6W - 28,
                height: a6H - 28,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [

                    // Encabezado
                    pw.Container(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                              bottom: pw.BorderSide(
                                  color: PdfColors.blueGrey300,
                                  width: 0.5))),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TECNOFLOW3',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue800)),
                          pw.Text('Ficha de máquina — $ahora',
                              style: const pw.TextStyle(
                                  fontSize: 7,
                                  color: PdfColors.blueGrey500)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 7),

                    // Cuerpo: QR izquierda | Datos derecha
                    pw.Expanded(
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [

                          // QR 6 cm
                          pw.Image(qrImage,
                              width: 170, height: 170,
                              fit: pw.BoxFit.contain),
                          pw.SizedBox(width: 12),

                          // Datos
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [

                                pw.Text(maquina.nombre,
                                    style: pw.TextStyle(
                                        fontSize: 12,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.blueGrey900),
                                    maxLines: 2),
                                pw.SizedBox(height: 4),

                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                      color: PdfColors.blueGrey50,
                                      borderRadius:
                                          pw.BorderRadius.circular(3)),
                                  child: pw.Text(maquina.codigo,
                                      style: const pw.TextStyle(
                                          fontSize: 9,
                                          color: PdfColors.blueGrey700)),
                                ),
                                pw.SizedBox(height: 4),

                                pw.Row(children: [
                                  pw.Text('Sector: ',
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          color: PdfColors.blueGrey500)),
                                  pw.Text(maquina.sectorNombre ?? '—',
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.blueGrey800)),
                                ]),
                                pw.SizedBox(height: 8),

                                if (maquina.descripcion != null &&
                                    maquina.descripcion!.isNotEmpty) ...[
                                  pw.Text(maquina.descripcion!,
                                      style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.blueGrey500),
                                      maxLines: 2),
                                  pw.SizedBox(height: 6),
                                ],

                                if (repuestos.isNotEmpty) ...[
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: pw.BoxDecoration(
                                        color: PdfColors.teal700,
                                        borderRadius:
                                            pw.BorderRadius.circular(3)),
                                    child: pw.Text(
                                        'REPUESTOS (${repuestos.length})',
                                        style: pw.TextStyle(
                                            fontSize: 7,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColors.white)),
                                  ),
                                  pw.SizedBox(height: 4),
                                  ...repuestos.take(10).map((r) => pw.Padding(
                                        padding: const pw.EdgeInsets.only(
                                            bottom: 2),
                                        child: pw.Row(
                                          crossAxisAlignment:
                                              pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text('• ',
                                                style: const pw.TextStyle(
                                                    fontSize: 7,
                                                    color: PdfColors.teal700)),
                                            pw.Expanded(
                                              child: pw.Text(
                                                r.repuestoDescripcion ?? '—',
                                                style: const pw.TextStyle(
                                                    fontSize: 7,
                                                    color: PdfColors.blueGrey800),
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  if (repuestos.length > 10)
                                    pw.Text(
                                        '... y ${repuestos.length - 10} más',
                                        style: const pw.TextStyle(
                                            fontSize: 7,
                                            color: PdfColors.blueGrey400)),
                                ] else
                                  pw.Text('Sin repuestos registrados',
                                      style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.blueGrey400)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pie con ID
                    pw.Container(
                      padding: const pw.EdgeInsets.only(top: 4),
                      decoration: const pw.BoxDecoration(
                          border: pw.Border(
                              top: pw.BorderSide(
                                  color: PdfColors.blueGrey200,
                                  width: 0.5))),
                      child: pw.Text(
                        'ID: ${maquina.id}',
                        style: const pw.TextStyle(
                            fontSize: 6, color: PdfColors.blueGrey300),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await _compartir(
      pdf,
      'qr_${maquina.codigo}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ── PDF de Repuestos ──────────────────────────────────────
  static Future<void> generarRepuestos({
    required List<Repuesto> repuestos,
    required bool soloStockBajo,
    required String busqueda,
  }) async {
    final pdf       = pw.Document();
    final ahora     = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalBajo = repuestos.where((r) => r.stockBajo).length;
    String filtroTexto = 'Todos los repuestos';
    if (soloStockBajo) filtroTexto = 'Solo repuestos con stock bajo';
    if (busqueda.isNotEmpty) filtroTexto += ' - busqueda: "$busqueda"';
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 1000,
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Listado de Repuestos'),
      footer: (ctx) => _buildFooterRepuestos(ctx, repuestos.length, totalBajo),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaRepuestos(repuestos)],
    ));
    await _compartir(pdf, 'repuestos_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
  }

  // ── PDF de Salidas ────────────────────────────────────────
  static Future<void> generarSalidas({
    required List<SalidaRepuesto> salidas,
    required String busqueda,
  }) async {
    final pdf   = pw.Document();
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    String filtroTexto = 'Todas las salidas';
    if (busqueda.isNotEmpty) filtroTexto += ' - busqueda: "$busqueda"';
    final totalUnidades = salidas.fold<int>(0, (s, e) => s + e.cantidad);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 1000,
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Salidas de Repuestos'),
      footer: (ctx) => _buildFooterSalidas(ctx, salidas.length, totalUnidades),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaSalidas(salidas)],
    ));
    await _compartir(pdf, 'salidas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
  }

  // ── PDF de Ingresos ───────────────────────────────────────
  static Future<void> generarIngresos({
    required List<IngresoRepuesto> ingresos,
    required String busqueda,
  }) async {
    final pdf   = pw.Document();
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    String filtroTexto = 'Todos los ingresos';
    if (busqueda.isNotEmpty) filtroTexto += ' - busqueda: "$busqueda"';
    final totalUnidades = ingresos.fold<int>(0, (s, e) => s + e.cantidad);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 1000,
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Ingresos de Repuestos'),
      footer: (ctx) => _buildFooterIngresos(ctx, ingresos.length, totalUnidades),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaIngresos(ingresos)],
    ));
    await _compartir(pdf, 'ingresos_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
  }

  // ── PDF de Maquinas ───────────────────────────────────────
  static Future<void> generarMaquinas({
    required List<Maquina> maquinas,
    required String busqueda,
    required String sectorNombre,
  }) async {
    final pdf   = pw.Document();
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    String filtroTexto = 'Sector: $sectorNombre';
    if (busqueda.isNotEmpty) filtroTexto += ' - busqueda: "$busqueda"';
    final activas      = maquinas.where((m) => m.estado == 'activo').length;
    final inactivas    = maquinas.where((m) => m.estado == 'inactivo').length;
    final enReparacion = maquinas.where((m) => m.estado == 'en_reparacion').length;
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 1000,
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Listado de Maquinas'),
      footer: (ctx) => _buildFooterMaquinas(ctx, maquinas.length, activas, inactivas, enReparacion),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaMaquinas(maquinas)],
    ));
    await _compartir(pdf, 'maquinas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
  }

  // ── PDF de Tickets ────────────────────────────────────────
  static Future<void> generarTickets({
    required List<Ticket> tickets,
    required String filtroEstado,
    required String busqueda,
    required String Function(String) labelEstado,
  }) async {
    final pdf   = pw.Document();
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    String filtroTexto = filtroEstado == 'todos'
        ? 'Todos los tickets'
        : 'Estado: ${labelEstado(filtroEstado)}';
    if (busqueda.isNotEmpty) filtroTexto += ' - busqueda: "$busqueda"';
    final abiertos    = tickets.where((t) => t.estado == 'abierto').length;
    final asignados   = tickets.where((t) => t.estado == 'asignado').length;
    final enEjecucion = tickets.where((t) => t.estado == 'en_ejecucion').length;
    final enEspera    = tickets.where((t) => t.estado == 'en_espera').length;
    final cerrados    = tickets.where((t) => t.estado == 'cerrado').length;
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 1000,
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Listado de Tickets'),
      footer: (ctx) => _buildFooterTickets(
          ctx, tickets.length, abiertos, asignados, enEjecucion, enEspera, cerrados),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaTickets(tickets, labelEstado)],
    ));
    await _compartir(pdf, 'tickets_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
  }

  // ── Encabezado compartido ─────────────────────────────────
  static pw.Widget _buildHeader(String fecha, String filtro, String titulo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 1))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('TECNOFLOW3',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Text('Control de stock de repuestos',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.blueGrey600)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(titulo,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Emitido: $fecha',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey600)),
          ]),
        ]),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(children: [
            pw.Text('Filtro aplicado: ',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
            pw.Text(filtro,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700)),
          ]),
        ),
      ]),
    );
  }

  // ── Tabla Repuestos ───────────────────────────────────────
  static pw.Widget _buildTablaRepuestos(List<Repuesto> repuestos) {
    return pw.TableHelper.fromTextArray(
      headers: ['REF', 'Codigo', 'Descripcion', 'Ubicacion', 'Stock\nActual', 'Stock\nMinimo', 'Estado'],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(3.0),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(0.9),
        5: const pw.FlexColumnWidth(0.9),
        6: const pw.FlexColumnWidth(1.0),
      },
      data: repuestos.map((r) => [
        r.ref?.toString() ?? '-',
        r.codigo,
        r.descripcion,
        r.ubicacion ?? '-',
        r.stockActual.toString(),
        r.stockMinimo.toString(),
        r.stockBajo ? '! Bajo' : 'OK',
      ]).toList(),
      cellDecoration: (index, data, rowIndex) {
        if (rowIndex >= repuestos.length) return const pw.BoxDecoration(color: PdfColors.white);
        final r = repuestos[rowIndex];
        if (r.stockBajo) return const pw.BoxDecoration(color: PdfColors.red50);
        return pw.BoxDecoration(color: rowIndex % 2 == 0 ? PdfColors.white : PdfColors.blueGrey50);
      },
    );
  }

  // ── Tabla Salidas ─────────────────────────────────────────
  static pw.Widget _buildTablaSalidas(List<SalidaRepuesto> salidas) {
    return pw.TableHelper.fromTextArray(
      headers: ['REF', 'Codigo', 'Descripcion', 'Cantidad', 'Fecha', 'Ticket'],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(3.0),
        3: const pw.FlexColumnWidth(0.9),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.5),
      },
      data: salidas.map((s) => [
        '-',
        s.repuestoCodigo ?? '-',
        s.repuestoDescripcion ?? '-',
        '-${s.cantidad}',
        s.fecha,
        s.ticketId != null ? '${s.ticketId!.substring(0, 8)}...' : 'Sin ticket',
      ]).toList(),
      cellDecoration: (index, data, rowIndex) => pw.BoxDecoration(
          color: rowIndex % 2 == 0 ? PdfColors.white : PdfColors.red50),
    );
  }

  // ── Tabla Ingresos ────────────────────────────────────────
  static pw.Widget _buildTablaIngresos(List<IngresoRepuesto> ingresos) {
    return pw.TableHelper.fromTextArray(
      headers: ['REF', 'Codigo', 'Descripcion', 'Cantidad', 'Fecha', 'Quien entrega'],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(3.0),
        3: const pw.FlexColumnWidth(0.9),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(2.0),
      },
      data: ingresos.map((ing) => [
        '-',
        ing.repuestoCodigo ?? '-',
        ing.repuestoDescripcion ?? '-',
        '+${ing.cantidad}',
        ing.fecha,
        ing.quienEntrega,
      ]).toList(),
      cellDecoration: (index, data, rowIndex) => pw.BoxDecoration(
          color: rowIndex % 2 == 0 ? PdfColors.white : PdfColors.green50),
    );
  }

  // ── Tabla Maquinas ────────────────────────────────────────
  static pw.Widget _buildTablaMaquinas(List<Maquina> maquinas) {
    return pw.TableHelper.fromTextArray(
      headers: ['Nombre', 'Codigo', 'Sector', 'Estado'],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
      },
      data: maquinas.map((m) => [
        m.nombre,
        m.codigo,
        m.sectorNombre ?? '-',
        m.estado == 'en_reparacion' ? 'En reparacion' : m.estado == 'inactivo' ? 'Inactivo' : 'Activo',
      ]).toList(),
      cellDecoration: (index, data, rowIndex) {
        if (rowIndex >= maquinas.length) return const pw.BoxDecoration(color: PdfColors.white);
        final m = maquinas[rowIndex];
        if (m.estado == 'en_reparacion') return const pw.BoxDecoration(color: PdfColors.red50);
        if (m.estado == 'inactivo') return const pw.BoxDecoration(color: PdfColors.grey200);
        return pw.BoxDecoration(color: rowIndex % 2 == 0 ? PdfColors.white : PdfColors.teal50);
      },
    );
  }

  // ── Tabla Tickets ─────────────────────────────────────────
  static pw.Widget _buildTablaTickets(List<Ticket> tickets, String Function(String) labelEstado) {
    return pw.TableHelper.fromTextArray(
      headers: ['Maquina', 'Descripcion', 'Estado', 'Creado por', 'Tecnico'],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      data: tickets.map((t) => [
        t.maquinaNombre ?? '-',
        t.descripcionDesperfecto,
        labelEstado(t.estado),
        t.creadoPorNombre ?? '-',
        t.tecnicoNombre ?? '-',
      ]).toList(),
      cellDecoration: (index, data, rowIndex) {
        if (rowIndex >= tickets.length) return const pw.BoxDecoration(color: PdfColors.white);
        final estado = tickets[rowIndex].estado;
        if (estado == 'abierto') return const pw.BoxDecoration(color: PdfColors.orange50);
        if (estado == 'en_ejecucion') return const pw.BoxDecoration(color: PdfColors.green50);
        if (estado == 'en_espera') return const pw.BoxDecoration(color: PdfColors.purple50);
        if (estado == 'cerrado') return const pw.BoxDecoration(color: PdfColors.grey200);
        return pw.BoxDecoration(color: rowIndex % 2 == 0 ? PdfColors.white : PdfColors.blueGrey50);
      },
    );
  }

  // ── Pies de pagina ────────────────────────────────────────
  static pw.Widget _buildFooterRepuestos(pw.Context ctx, int total, int totalBajo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Row(children: [
          pw.Text('Total: $total repuesto${total != 1 ? 's' : ''}   |   ',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
          pw.Text('Stock bajo: $totalBajo',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: totalBajo > 0 ? PdfColors.red700 : PdfColors.green700,
                  fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Pag. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }

  static pw.Widget _buildFooterSalidas(pw.Context ctx, int total, int totalUnidades) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Row(children: [
          pw.Text('Total registros: $total   |   ',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
          pw.Text('Unidades retiradas: $totalUnidades',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Pag. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }

  static pw.Widget _buildFooterIngresos(pw.Context ctx, int total, int totalUnidades) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Row(children: [
          pw.Text('Total registros: $total   |   ',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
          pw.Text('Unidades ingresadas: $totalUnidades',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Pag. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }

  static pw.Widget _buildFooterMaquinas(pw.Context ctx, int total,
      int activas, int inactivas, int enReparacion) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(
            'Total: $total   |   Activas: $activas   |   Inactivas: $inactivas   |   En reparacion: $enReparacion',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
        pw.Text('Pag. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }

  static pw.Widget _buildFooterTickets(pw.Context ctx, int total,
      int abiertos, int asignados, int enEjecucion, int enEspera, int cerrados) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(
            'Total: $total   |   Abiertos: $abiertos   |   Asignados: $asignados   |   En ejecucion: $enEjecucion   |   En espera: $enEspera   |   Cerrados: $cerrados',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey600)),
        pw.Text('Pag. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }
}