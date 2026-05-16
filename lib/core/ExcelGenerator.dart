// lib/core/ExcelGenerator.dart
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class ExcelGenerator {

  // ── Estilos ──────────────────────────────────────────────────
  static CellStyle get _headerStyle => CellStyle(
    fontColorHex:       ExcelColor.fromHexString('#FFFFFF'),
    bold:               true,
    backgroundColorHex: ExcelColor.fromHexString('#1E2A38'),
  );
  static CellStyle get _stockBajoStyle => CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#FFEBEE'),
  );
  static CellStyle get _ingresoStyle => CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
  );
  static CellStyle get _salidaStyle => CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
  );

  // ── Helpers ──────────────────────────────────────────────────
  static void _cabecera(Sheet sheet, List<String> cols) {
    for (var i = 0; i < cols.length; i++) {
      final cell      = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value      = TextCellValue(cols[i]);
      cell.cellStyle  = _headerStyle;
    }
  }

  static CellValue _v(String? s)   => TextCellValue(s ?? '—');
  static CellValue _n(num? n)      =>
      n != null ? IntCellValue(n.toInt()) : TextCellValue('—');
  static CellValue _fecha(DateTime? d) => d != null
      ? TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(d))
      : TextCellValue('—');

  static void _fila(Sheet sheet, int row, List<CellValue> vals,
      {CellStyle? style}) {
    for (var c = 0; c < vals.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = vals[c];
      if (style != null) cell.cellStyle = style;
    }
  }

  // ── Hoja: Repuestos ──────────────────────────────────────────
  static void _hojaRepuestos(Excel excel, List<Repuesto> datos) {
    final sheet = excel['Repuestos'];
    _cabecera(sheet, [
      'REF', 'Código', 'Descripción', 'Ubicación',
      'Stock actual', 'Stock mínimo', 'Estado', 'Alerta',
    ]);
    for (var i = 0; i < datos.length; i++) {
      final r = datos[i];
      _fila(sheet, i + 1, [
        _n(r.ref),
        _v(r.codigo),
        _v(r.descripcion),
        _v(r.ubicacion),
        _n(r.stockActual),
        _n(r.stockMinimo),
        _v(r.activo ? 'Activo' : 'Inactivo'),
        _v(r.stockBajo ? '⚠ Stock bajo' : 'OK'),
      ], style: r.stockBajo ? _stockBajoStyle : null);
    }
  }

  // ── Hoja: Máquinas ───────────────────────────────────────────
  static void _hojaMaquinas(Excel excel, List<Maquina> datos) {
    final sheet = excel['Maquinas'];
    _cabecera(sheet, [
      'Código', 'Nombre', 'Sector', 'Estado', 'Descripción',
    ]);
    for (var i = 0; i < datos.length; i++) {
      final m = datos[i];
      _fila(sheet, i + 1, [
        _v(m.codigo),
        _v(m.nombre),
        _v(m.sectorNombre),
        _v(m.estado),
        _v(m.descripcion),
      ]);
    }
  }

  // ── Hoja: Usuarios ───────────────────────────────────────────
  static void _hojaUsuarios(Excel excel, List<Usuario> datos) {
    final sheet = excel['Usuarios'];
    _cabecera(sheet, [
      'Nombre', 'Email', 'Rol', 'Estado', 'Último acceso',
    ]);
    for (var i = 0; i < datos.length; i++) {
      final u = datos[i];
      _fila(sheet, i + 1, [
        _v(u.nombre),
        _v(u.email),
        _v(u.rolNombre),
        _v(u.estado),
        _fecha(u.ultimoAcceso),
      ]);
    }
  }

  // ── Hoja: Ingresos ───────────────────────────────────────────
  static void _hojaIngresos(Excel excel, List<IngresoRepuesto> datos) {
    final sheet = excel['Ingresos'];
    _cabecera(sheet, [
      'Fecha', 'REF', 'Código', 'Descripción',
      'Cantidad', 'Quien entrega', 'Observación',
    ]);
    for (var i = 0; i < datos.length; i++) {
      final ing = datos[i];
      _fila(sheet, i + 1, [
        _fecha(ing.fecha),
        _n(ing.repuestoRef),
        _v(ing.repuestoCodigo),
        _v(ing.repuestoDescripcion),
        _n(ing.cantidad),
        _v(ing.quienEntrega),
        _v(ing.descripcion),
      ], style: _ingresoStyle);
    }
  }

  // ── Hoja: Salidas ────────────────────────────────────────────
  static void _hojaSalidas(Excel excel, List<SalidaRepuesto> datos) {
    final sheet = excel['Salidas'];
    _cabecera(sheet, [
      'Fecha', 'REF', 'Código', 'Descripción',
      'Cantidad', 'Ticket', 'Quien retira', 'Observación',
    ]);
    for (var i = 0; i < datos.length; i++) {
      final sal = datos[i];
      _fila(sheet, i + 1, [
        _fecha(sal.fecha),
        _n(sal.repuestoRef),
        _v(sal.repuestoCodigo),
        _v(sal.repuestoDescripcion),
        _n(sal.cantidad),
        _v(sal.ticketNumero),
        _v(sal.quienRetira),
        _v(sal.observacion),
      ], style: _salidaStyle);
    }
  }

  // ── Método principal ─────────────────────────────────────────
  static Future<void> generarBackup({
    required List<Repuesto>        repuestos,
    required List<Maquina>         maquinas,
    required List<Usuario>         usuarios,
    required List<IngresoRepuesto> ingresos,
    required List<SalidaRepuesto>  salidas,
  }) async {
    final excel = Excel.createExcel();
    // Excel crea "Sheet1" por defecto — la eliminamos
    excel.delete('Sheet1');

    _hojaRepuestos(excel, repuestos);
    _hojaMaquinas(excel, maquinas);
    _hojaUsuarios(excel, usuarios);
    _hojaIngresos(excel, ingresos);
    _hojaSalidas(excel, salidas);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Error al codificar el archivo Excel');

    final fecha  = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final nombre = 'tecnoflow_backup_$fecha.xlsx';
    final dir    = await getTemporaryDirectory();
    final file   = File('${dir.path}/$nombre');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'Tecnoflow — Backup $fecha',
    );
  }
}