// lib/core/image_helper.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class ImageHelper {
  static final _picker = ImagePicker();
  static final _client = Supabase.instance.client;
  static const _bucketRepuestos = 'repuestos';
  static const _bucketMaquinas  = 'maquinas';

  // ── Elegir fuente de imagen ───────────────────────────────
  static Future<Uint8List?> elegirImagen(BuildContext context) async {
    if (kIsWeb) return _elegirDesdeGaleria();

    final fuente = await showModalBottomSheet<ImageSource?>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Seleccionar imagen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.camera_alt_outlined, color: Colors.blue)),
                title: const Text('Cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.photo_outlined, color: Colors.green)),
                title: const Text('Galería de fotos'),
                onTap: () => Navigator.pop(context, ImageSource.gallery)),
            ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.folder_outlined, color: Colors.orange)),
                title: const Text('Archivos del dispositivo'),
                onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ]),
        ),
      ),
    );

    if (fuente == null) return null;
    return _elegirDesdeFuente(fuente);
  }

  static Future<Uint8List?> _elegirDesdeGaleria() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return null;
    return picked.readAsBytes();
  }

  static Future<Uint8List?> _elegirDesdeFuente(ImageSource fuente) async {
    final picked = await _picker.pickImage(
      source: fuente, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (picked == null) return null;
    return picked.readAsBytes();
  }

  // ── Subir imagen — repuesto ───────────────────────────────
  static Future<String?> subirImagen(
      Uint8List bytes, String repuestoId) async {
    return _subir(bytes, _bucketRepuestos, 'repuesto_$repuestoId.jpg');
  }

  // ── Subir imagen — máquina ────────────────────────────────
  static Future<String?> subirImagenMaquina(
      Uint8List bytes, String maquinaId) async {
    return _subir(bytes, _bucketMaquinas, 'maquina_$maquinaId.jpg');
  }

  // ── Subir genérico ────────────────────────────────────────
  static Future<String?> _subir(
      Uint8List bytes, String bucket, String path) async {
    try {
      final adminClient = SupabaseClient(supabaseUrl, supabaseServiceKey);
      await adminClient.storage.from(bucket).uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(
            contentType: 'image/jpeg', upsert: true),
      );
      final url = _client.storage.from(bucket).getPublicUrl(path);
      return '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      return null;
    }
  }

  // ── Eliminar imagen — repuesto ────────────────────────────
  static Future<void> eliminarImagen(String repuestoId) async {
    try {
      await _client.storage
          .from(_bucketRepuestos)
          .remove(['repuesto_$repuestoId.jpg']);
    } catch (_) {}
  }

  // ── Eliminar imagen — máquina ─────────────────────────────
  static Future<void> eliminarImagenMaquina(String maquinaId) async {
    try {
      await _client.storage
          .from(_bucketMaquinas)
          .remove(['maquina_$maquinaId.jpg']);
    } catch (_) {}
  }
}