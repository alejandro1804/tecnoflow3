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
    final pdf   = pw.Document();
    final ahora = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalBajo = repuestos.where((r) => r.stockBajo).length;

    String filtroTexto = 'Todos los repuestos';
    if (soloStockBajo) filtroTexto = 'Solo repuestos con stock bajo';
    if (busqueda.isNotEmpty) filtroTexto += ' — búsqueda: "$busqueda"';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(ahora, filtroTexto),
        footer: (context) => _buildFooter(context, repuestos.length, totalBajo),
        build: (context) => [
          pw.SizedBox(height: 16),
          _buildTabla(repuestos),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'repuestos_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  // ── Encabezado ────────────────────────────────────────────
  static pw.Widget _buildHeader(String fecha, String filtro) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
          border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blueGrey300, width: 1))),
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
                        pw.Text('Listado de Repuestos',
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold)),
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

  // ── Tabla ─────────────────────────────────────────────────
  static pw.Widget _buildTabla(List<Repuesto> repuestos) {
    return pw.TableHelper.fromTextArray(
      headers: [
        'Código', 'Descripción', 'Ubicación',
        'Stock\nActual', 'Stock\nMínimo', 'Estado'
      ],
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
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1.2),
      },
      data: repuestos
          .map((r) => [
                r.codigo,
                r.descripcion,
                r.ubicacion ?? '—',
                r.stockActual.toString(),
                r.stockMinimo.toString(),
                r.stockBajo ? '⚠ Bajo' : '✓ OK',
              ])
          .toList(),
      cellDecoration: (index, data, rowIndex) {
        if (rowIndex >= repuestos.length) {
          return const pw.BoxDecoration(color: PdfColors.white);
        }
        final r = repuestos[rowIndex];
        if (r.stockBajo) {
          return const pw.BoxDecoration(color: PdfColors.red50);
        }
        return pw.BoxDecoration(
            color: rowIndex % 2 == 0
                ? PdfColors.white
                : PdfColors.blueGrey50);
      },
    );
  }

  // ── Pie de página ─────────────────────────────────────────
  static pw.Widget _buildFooter(
      pw.Context context, int total, int totalBajo) {
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
            pw.Text(
                'Pág. ${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(
                    fontSize: 9, color: PdfColors.blueGrey600)),
          ]),
    );
  }
}