// lib/screens/qr/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../movimientos/salida_form_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _State();
}

class _State extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _procesando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _procesando = true);
    await _ctrl.stop();

    try {
      // 1. Buscar la máquina por id
      final maquinas = ref.read(maquinasProvider).valueOrNull ?? [];
      final maquina  = maquinas.cast<Maquina?>()
          .firstWhere((m) => m?.id == raw, orElse: () => null);

      if (!mounted) return;

      if (maquina == null) {
        _mostrarError('QR no reconocido como máquina del sistema.');
        return;
      }

      // 2. Buscar ticket activo más reciente de esta máquina
      final tickets = ref.read(ticketsProvider).valueOrNull ?? [];
      final ticketsActivos = tickets
          .where((t) =>
              t.maquinaId == maquina.id &&
              t.estado != TicketEstados.cerrado)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;

      if (ticketsActivos.isNotEmpty) {
        // Hay ticket activo → ir directo al detalle del más reciente
        Navigator.pop(context);
        context.push('/tickets/${ticketsActivos.first.id}');
      } else {
        // Sin ticket activo → mostrar bottom sheet con datos
        await _mostrarDetalleMaquina(maquina);
      }
    } catch (e) {
      _mostrarError('Error al procesar el QR: $e');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.qr_code_scanner, color: Colors.red),
          SizedBox(width: 8),
          Text('QR inválido'),
        ]),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _procesando = false);
              _ctrl.start();
            },
            child: const Text('Volver a escanear'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDetalleMaquina(Maquina maquina) async {
    // Cargar repuestos asociados a la máquina
    List<RepuestoMaquina> repuestos = [];
    try {
      repuestos = await ref
          .read(repuestosMaquinasRepoProvider)
          .getByMaquina(maquina.id);
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize:     0.35,
        maxChildSize:     0.90,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Asa
              Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),

              // Encabezado máquina
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(
                      Icons.precision_manufacturing_outlined,
                      color: Colors.teal, size: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(maquina.nombre,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(maquina.codigo,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // Sector
              Row(children: [
                const Icon(Icons.domain_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(maquina.sectorNombre ?? 'Sin sector',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ]),

              // Descripción opcional
              if (maquina.descripcion != null &&
                  maquina.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(maquina.descripcion!,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ],
              const SizedBox(height: 10),

              // Badge sin tickets activos
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline,
                      size: 14, color: Colors.green),
                  SizedBox(width: 6),
                  Text('Sin tickets activos',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Repuestos asociados
              Row(children: [
                const Text('REPUESTOS ASOCIADOS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 1)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('${repuestos.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.teal,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 8),

              if (repuestos.isEmpty)
                const Text('Sin repuestos registrados',
                    style: TextStyle(fontSize: 12, color: Colors.grey))
              else
                ...repuestos.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        const Icon(Icons.circle,
                            size: 6, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.repuestoDescripcion ?? '—',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5)),
                          child: Text('x${r.cantidad}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    )),

              const SizedBox(height: 20),

              // Botones de acción
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.output_outlined, size: 16),
                    label: const Text('Nueva salida',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(
                            color: Colors.red.withOpacity(0.5))),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderScope(
                            parent: ProviderScope.containerOf(context),
                            child: const SalidaFormScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                        Icons.confirmation_number_outlined,
                        size: 16),
                    label: const Text('Ver tickets',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: BorderSide(
                            color: Colors.orange.withOpacity(0.5))),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      Navigator.pop(context);
                      context.push('/tickets');
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // Botón compartir
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Compartir ficha',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                      side: BorderSide(
                          color: Colors.blueGrey.withOpacity(0.4))),
                  onPressed: () {
                    final buffer = StringBuffer();
                    buffer.writeln('🔧 TECNOFLOW3 — Ficha de máquina');
                    buffer.writeln('📌 ${maquina.nombre} (${maquina.codigo})');
                    buffer.writeln('🏭 Sector: ${maquina.sectorNombre ?? '—'}');
                    if (maquina.descripcion != null &&
                        maquina.descripcion!.isNotEmpty) {
                      buffer.writeln('📝 ${maquina.descripcion}');
                    }
                    if (repuestos.isNotEmpty) {
                      buffer.writeln('');
                      buffer.writeln(
                          '🔩 REPUESTOS ASOCIADOS (${repuestos.length})');
                      for (final r in repuestos) {
                        buffer.writeln(
                            '• ${r.repuestoDescripcion ?? '—'}  x${r.cantidad}');
                      }
                    } else {
                      buffer.writeln('');
                      buffer.writeln('Sin repuestos registrados');
                    }
                    Share.share(buffer.toString(),
                        subject: 'Ficha de máquina — ${maquina.nombre}');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Al cerrar el sheet sin navegar → reactivar scanner
    if (mounted) {
      setState(() => _procesando = false);
      _ctrl.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR de máquina'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            tooltip: 'Linterna',
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [

          // Cámara
          MobileScanner(
            controller: _ctrl,
            onDetect:   _onDetect,
          ),

          // Overlay oscuro con ventana de escaneo
          CustomPaint(
            size: Size.infinite,
            painter: _ScanOverlayPainter(),
          ),

          // Texto guía
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text(
                  'Apuntá al código QR de la máquina',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),

          // Spinner mientras procesa
          if (_procesando)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Overlay con recuadro de escaneo ──────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double boxSize = 240;
    final double left   = (size.width  - boxSize) / 2;
    final double top    = (size.height - boxSize) / 2 - 40;
    final Rect   window = Rect.fromLTWH(left, top, boxSize, boxSize);

    // Fondo oscuro con hueco central transparente
    final bgPaint = Paint()..color = Colors.black54;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(
            window, const Radius.circular(12))),
      ),
      bgPaint,
    );

    // Esquinas blancas del recuadro
    final cornerPaint = Paint()
      ..color       = Colors.white
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    const double cLen = 24;

    // Superior izquierda
    canvas.drawLine(Offset(left, top + cLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cLen, top), cornerPaint);
    // Superior derecha
    canvas.drawLine(Offset(left + boxSize - cLen, top),
        Offset(left + boxSize, top), cornerPaint);
    canvas.drawLine(Offset(left + boxSize, top),
        Offset(left + boxSize, top + cLen), cornerPaint);
    // Inferior izquierda
    canvas.drawLine(Offset(left, top + boxSize - cLen),
        Offset(left, top + boxSize), cornerPaint);
    canvas.drawLine(Offset(left, top + boxSize),
        Offset(left + cLen, top + boxSize), cornerPaint);
    // Inferior derecha
    canvas.drawLine(Offset(left + boxSize - cLen, top + boxSize),
        Offset(left + boxSize, top + boxSize), cornerPaint);
    canvas.drawLine(Offset(left + boxSize, top + boxSize),
        Offset(left + boxSize, top + boxSize - cLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}