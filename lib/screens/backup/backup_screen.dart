// lib/screens/backup/backup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ExcelGenerator.dart';
import '../../providers/providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _State();
}

class _State extends ConsumerState<BackupScreen> {
  bool    _generando = false;
  String? _error;
  String? _exito;

  Future<void> _generarExcel() async {
    setState(() { _generando = true; _error = null; _exito = null; });
    try {
      // Traer todos los datos en paralelo
      final results = await Future.wait([
        ref.read(repuestosRepoProvider).getAll(),
        ref.read(maquinasRepoProvider).getAll(),
        ref.read(usuariosRepoProvider).getAll(),
        ref.read(movimientosRepoProvider).getIngresos(),
        ref.read(movimientosRepoProvider).getSalidas(),
      ]);

      await ExcelGenerator.generarBackup(
        repuestos: results[0] as dynamic,
        maquinas:  results[1] as dynamic,
        usuarios:  results[2] as dynamic,
        ingresos:  results[3] as dynamic,
        salidas:   results[4] as dynamic,
      );

      if (mounted) {
        setState(() => _exito =
            'Archivo generado correctamente. Usá la opción compartir para guardarlo.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Exportar / Backup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Ícono central ────────────────────────────────
            Center(
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_chart_outlined,
                    size: 48, color: Colors.green),
              ),
            ),
            const SizedBox(height: 20),

            Text('Backup completo',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                'Genera un archivo Excel con todas las tablas del sistema '
                'y lo comparte para que puedas guardarlo donde quieras.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),

            const SizedBox(height: 32),

            // ── Detalle de hojas ─────────────────────────────
            _InfoCard(
              titulo: 'El archivo incluye 5 hojas',
              items: const [
                _HojaItem(
                  icono: Icons.build_outlined,
                  color: Colors.blue,
                  nombre: 'Repuestos',
                  detalle: 'REF, código, descripción, stock, estado',
                ),
                _HojaItem(
                  icono: Icons.precision_manufacturing_outlined,
                  color: Colors.teal,
                  nombre: 'Maquinas',
                  detalle: 'Código, nombre, sector, estado',
                ),
                _HojaItem(
                  icono: Icons.people_outline,
                  color: Colors.purple,
                  nombre: 'Usuarios',
                  detalle: 'Nombre, email, rol, último acceso',
                ),
                _HojaItem(
                  icono: Icons.add_circle_outline,
                  color: Colors.green,
                  nombre: 'Ingresos',
                  detalle: 'Fecha, repuesto, cantidad, quien entrega',
                ),
                _HojaItem(
                  icono: Icons.remove_circle_outline,
                  color: Colors.orange,
                  nombre: 'Salidas',
                  detalle: 'Fecha, repuesto, cantidad, ticket, quien retira',
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Mensajes de estado ───────────────────────────
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            if (_exito != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_exito!,
                        style: const TextStyle(
                            color: Colors.green, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Botón principal ──────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _generando ? null : _generarExcel,
                icon: _generando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_outlined),
                label: Text(
                    _generando ? 'Generando...' : 'Generar y compartir Excel',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),

            const SizedBox(height: 16),
            Text(
                'El nombre del archivo incluye la fecha actual.\n'
                'Ejemplo: tecnoflow_backup_${DateTime.now().toString().substring(0, 10)}.xlsx',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

// ── Widget: card informativa ──────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String titulo;
  final List<_HojaItem> items;
  const _InfoCard({required this.titulo, required this.items});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.5)),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(item.icono, size: 17, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(item.detalle,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            )),
          ]),
        )),
      ],
    ),
  );
}

class _HojaItem {
  final IconData icono;
  final Color    color;
  final String   nombre;
  final String   detalle;
  const _HojaItem({
    required this.icono,
    required this.color,
    required this.nombre,
    required this.detalle,
  });
}