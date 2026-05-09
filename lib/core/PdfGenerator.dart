// lib/core/pdf_generator.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfGenerator {
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
    if (busqueda.isNotEmpty) filtroTexto += ' — búsqueda: "$busqueda"';
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Listado de Repuestos'),
      footer: (ctx) => _buildFooterRepuestos(ctx, repuestos.length, totalBajo),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaRepuestos(repuestos)],
    ));
    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: 'repuestos_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  // ── PDF de Salidas ────────────────────────────────────────
  static Future<void> generarSalidas({
    required List<SalidaRepuesto> salidas,
    required String busqueda,
  }) async {
    final pdf   = pw.Document();
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    String filtroTexto = 'Todas las salidas';
    if (busqueda.isNotEmpty) filtroTexto += ' — búsqueda: "$busqueda"';
    final totalUnidades = salidas.fold<int>(0, (s, e) => s + e.cantidad);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Salidas de Repuestos'),
      footer: (ctx) => _buildFooterSalidas(ctx, salidas.length, totalUnidades),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaSalidas(salidas)],
    ));
    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: 'salidas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  // ── PDF de Ingresos ───────────────────────────────────────
  static Future<void> generarIngresos({
    required List<IngresoRepuesto> ingresos,
    required String busqueda,
  }) async {
    final pdf   = pw.Document();
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    String filtroTexto = 'Todos los ingresos';
    if (busqueda.isNotEmpty) filtroTexto += ' — búsqueda: "$busqueda"';
    final totalUnidades = ingresos.fold<int>(0, (s, e) => s + e.cantidad);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Ingresos de Repuestos'),
      footer: (ctx) => _buildFooterIngresos(ctx, ingresos.length, totalUnidades),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaIngresos(ingresos)],
    ));
    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: 'ingresos_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  // ── PDF de Máquinas ───────────────────────────────────────
  static Future<void> generarMaquinas({
    required List<Maquina> maquinas,
    required String busqueda,
    required String sectorNombre,
  }) async {
    final pdf   = pw.Document();
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    String filtroTexto = 'Sector: $sectorNombre';
    if (busqueda.isNotEmpty) filtroTexto += ' — búsqueda: "$busqueda"';
    final activas      = maquinas.where((m) => m.estado == 'activo').length;
    final inactivas    = maquinas.where((m) => m.estado == 'inactivo').length;
    final enReparacion = maquinas.where((m) => m.estado == 'en_reparacion').length;
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Listado de Máquinas'),
      footer: (ctx) => _buildFooterMaquinas(
          ctx, maquinas.length, activas, inactivas, enReparacion),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaMaquinas(maquinas)],
    ));
    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: 'maquinas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
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
    if (busqueda.isNotEmpty) filtroTexto += ' — búsqueda: "$busqueda"';

    final abiertos    = tickets.where((t) => t.estado == 'abierto').length;
    final asignados   = tickets.where((t) => t.estado == 'asignado').length;
    final enEjecucion = tickets.where((t) => t.estado == 'en_ejecucion').length;
    final enEspera    = tickets.where((t) => t.estado == 'en_espera').length;
    final cerrados    = tickets.where((t) => t.estado == 'cerrado').length;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _buildHeader(ahora, filtroTexto, 'Listado de Tickets'),
      footer: (ctx) => _buildFooterTickets(
          ctx, tickets.length, abiertos, asignados, enEjecucion, enEspera, cerrados),
      build: (ctx) => [pw.SizedBox(height: 16), _buildTablaTickets(tickets, labelEstado)],
    ));

    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: 'tickets_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  // ── Encabezado compartido ─────────────────────────────────
  static pw.Widget _buildHeader(String fecha, String filtro, String titulo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              bottom: pw.BorderSide(
                  color: PdfColors.blueGrey300, width: 1))),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
            pw.Text('TECNOFLOW3',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
            pw.Text('Control de stock de repuestos',
                style: pw.TextStyle(
                    fontSize: 11, color: PdfColors.blueGrey600)),
          ]),
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
            pw.Text(titulo,
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Emitido: $fecha',
                style: pw.TextStyle(
                    fontSize: 10, color: PdfColors.blueGrey600)),
          ]),
        ]),
        pw.SizedBox(height: 6),
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Row(children: [
            pw.Text('Filtro aplicado: ',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700)),
            pw.Text(filtro,
                style: pw.TextStyle(
                    fontSize: 10, color: PdfColors.blueGrey700)),
          ]),
        ),
      ]),
    );
  }

  // ── Tabla Repuestos — con columna REF ─────────────────────
  static pw.Widget _buildTablaRepuestos(List<Repuesto> repuestos) {
    return pw.TableHelper.fromTextArray(
      headers: ['REF', 'Código', 'Descripción', 'Ubicación',
                'Stock\nActual', 'Stock\nMínimo', 'Estado'],
      headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.blue800),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8), // REF
        1: const pw.FlexColumnWidth(1.4), // Código
        2: const pw.FlexColumnWidth(3.0), // Descripción
        3: const pw.FlexColumnWidth(1.4), // Ubicación
        4: const pw.FlexColumnWidth(0.9), // Stock actual
        5: const pw.FlexColumnWidth(0.9), // Stock mínimo
        6: const pw.FlexColumnWidth(1.0), // Estado
      },
      data: repuestos.map((r) => [
        r.ref?.toString() ?? '—',
        r.codigo,
        r.descripcion,
        r.ubicacion ?? '—',
        r.stockActual.toString(),
        r.stockMinimo.toString(),
        r.stockBajo ? '⚠ Bajo' : '✓ OK',
      ]).toList(),
      cellDecoration: (index, data, rowIndex) {
        if (rowIndex >= repuestos.length)
          return const pw.BoxDecoration(color: PdfColors.white);
        final r = repuestos[rowIndex];
        if (r.stockBajo)
          return const pw.BoxDecoration(color: PdfColors.red50);
        return pw.BoxDecoration(
            color: rowIndex % 2 == 0
                ? PdfColors.white
                : PdfColors.blueGrey50);
      },
    );
  }

  // ── Tabla Salidas — con columna REF ──────────────────────
  static pw.Widget _buildTablaSalidas(List<SalidaRepuesto> salidas) {
    return pw.TableHelper.fromTextArray(
      headers: ['REF', 'Código', 'Descripción', 'Cantidad', 'Fecha', 'Ticket'],
      headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.red800),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8), // REF
        1: const pw.FlexColumnWidth(1.4), // Código
        2: const pw.FlexColumnWidth(3.0), // Descripción
        3: const pw.FlexColumnWidth(0.9), // Cantidad
        4: const pw.FlexColumnWidth(1.2), // Fecha
        5: const pw.FlexColumnWidth(1.5), // Ticket
      },
      data: salidas.map((s) => [
        '—',  // salidas no tienen ref directo — se muestra el del repuesto si se tuviera
        s.repuestoCodigo ?? '—',
        s.repuestoDescripcion ?? '—',
        '-${s.cantidad}',
        s.fecha,
        s.ticketId != null
            ? '${s.ticketId!.substring(0, 8)}...'
            : 'Sin ticket',
      ]).toList(),
      cellDecoration: (index, data, rowIndex) => pw.BoxDecoration(
          color: rowIndex % 2 == 0 ? PdfColors.white : PdfColors.red50),
    );
  }

  // ── Tabla Ingresos — con columna REF ─────────────────────
  static pw.Widget _buildTablaIngresos(List<IngresoRepuesto> ingresos) {
    return pw.TableHelper.fromTextArray(
      headers: ['REF', 'Código', 'Descripción', 'Cantidad', 'Fecha', 'Quien entrega'],
      headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.green800),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8), // REF
        1: const pw.FlexColumnWidth(1.4), // Código
        2: const pw.FlexColumnWidth(3.0), // Descripción
        3: const pw.FlexColumnWidth(0.9), // Cantidad
        4: const pw.FlexColumnWidth(1.2), // Fecha
        5: const pw.FlexColumnWidth(2.0), // Quien entrega
      },
      data: ingresos.map((ing) => [
        '—',  // ingresos no traen el ref del repuesto — se muestra — por ahora
        ing.repuestoCodigo ?? '—',
        ing.repuestoDescripcion ?? '—',
        '+${ing.cantidad}',
        ing.fecha,
        ing.quienEntrega,
      ]).toList(),
      cellDecoration: (index, data, rowIndex) => pw.BoxDecoration(
          color: rowIndex % 2 == 0 ? PdfColors.white : PdfColors.green50),
    );
  }

  // ── Tabla Máquinas ────────────────────────────────────────
  static pw.Widget _buildTablaMaquinas(List<Maquina> maquinas) {
    return pw.TableHelper.fromTextArray(
      headers: ['Nombre', 'Código', 'Sector', 'Estado'],
      headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.teal700),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
        m.sectorNombre ?? '—',
        m.estado == 'en_reparacion'
            ? 'En reparación'
            : m.estado == 'inactivo'
                ? 'Inactivo'
                : 'Activo',
      ]).toList(),
      cellDecoration: (index, data, rowIndex) {
        if (rowIndex >= maquinas.length)
          return const pw.BoxDecoration(color: PdfColors.white);
        final m = maquinas[rowIndex];
        if (m.estado == 'en_reparacion')
          return const pw.BoxDecoration(color: PdfColors.red50);
        if (m.estado == 'inactivo')
          return const pw.BoxDecoration(color: PdfColors.grey200);
        return pw.BoxDecoration(
            color: rowIndex % 2 == 0
                ? PdfColors.white
                : PdfColors.teal50);
      },
    );
  }

  // ── Tabla Tickets ─────────────────────────────────────────
  static pw.Widget _buildTablaTickets(
      List<Ticket> tickets, String Function(String) labelEstado) {
    return pw.TableHelper.fromTextArray(
      headers: ['Máquina', 'Descripción', 'Estado', 'Creado por', 'Técnico'],
      headerStyle: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.orange900),
      headerAlignment: pw.Alignment.centerLeft,
      headerPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
        t.maquinaNombre ?? '—',
        t.descripcionDesperfecto,
        labelEstado(t.estado),
        t.creadoPorNombre ?? '—',
        t.tecnicoNombre ?? '—',
      ]).toList(),
      cellDecoration: (index, data, rowIndex) {
        if (rowIndex >= tickets.length)
          return const pw.BoxDecoration(color: PdfColors.white);
        final estado = tickets[rowIndex].estado;
        if (estado == 'abierto')
          return const pw.BoxDecoration(color: PdfColors.orange50);
        if (estado == 'en_ejecucion')
          return const pw.BoxDecoration(color: PdfColors.green50);
        if (estado == 'en_espera')
          return const pw.BoxDecoration(color: PdfColors.purple50);
        if (estado == 'cerrado')
          return const pw.BoxDecoration(color: PdfColors.grey200);
        return pw.BoxDecoration(
            color: rowIndex % 2 == 0
                ? PdfColors.white
                : PdfColors.blueGrey50);
      },
    );
  }

  // ── Pies de página ────────────────────────────────────────
  static pw.Widget _buildFooterRepuestos(
      pw.Context ctx, int total, int totalBajo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
        pw.Row(children: [
          pw.Text(
              'Total: $total repuesto${total != 1 ? 's' : ''}   |   ',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColors.blueGrey600)),
          pw.Text('Stock bajo: $totalBajo',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: totalBajo > 0
                      ? PdfColors.red700
                      : PdfColors.green700,
                  fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
                fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }

  static pw.Widget _buildFooterSalidas(
      pw.Context ctx, int total, int totalUnidades) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
        pw.Row(children: [
          pw.Text('Total registros: $total   |   ',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColors.blueGrey600)),
          pw.Text('Unidades retiradas: $totalUnidades',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.red700,
                  fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
                fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }

  static pw.Widget _buildFooterIngresos(
      pw.Context ctx, int total, int totalUnidades) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
        pw.Row(children: [
          pw.Text('Total registros: $total   |   ',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColors.blueGrey600)),
          pw.Text('Unidades ingresadas: $totalUnidades',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.green700,
                  fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
                fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }

  static pw.Widget _buildFooterMaquinas(pw.Context ctx, int total,
      int activas, int inactivas, int enReparacion) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
        pw.Text(
            'Total: $total   |   Activas: $activas   |   Inactivas: $inactivas   |   En reparación: $enReparacion',
            style: pw.TextStyle(
                fontSize: 9, color: PdfColors.blueGrey600)),
        pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
                fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }

  static pw.Widget _buildFooterTickets(
      pw.Context ctx,
      int total,
      int abiertos,
      int asignados,
      int enEjecucion,
      int enEspera,
      int cerrados) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              top: pw.BorderSide(
                  color: PdfColors.blueGrey300, width: 1))),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
        pw.Text(
            'Total: $total   |   Abiertos: $abiertos   |   Asignados: $asignados   |   En ejecución: $enEjecucion   |   En espera: $enEspera   |   Cerrados: $cerrados',
            style: pw.TextStyle(
                fontSize: 8, color: PdfColors.blueGrey600)),
        pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(
                fontSize: 9, color: PdfColors.blueGrey600)),
      ]),
    );
  }
}