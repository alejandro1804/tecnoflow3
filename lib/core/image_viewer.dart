// lib/core/image_viewer.dart
// Widget reutilizable: thumbnail en listado + visor fullscreen al tocar

import 'package:flutter/material.dart';

class RepuestoImagenThumb extends StatelessWidget {
  final String? imagenUrl;
  final double  size;

  const RepuestoImagenThumb({
    super.key,
    required this.imagenUrl,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (imagenUrl == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _mostrarVisor(context, imagenUrl!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imagenUrl!,
          width:  size,
          height: size,
          fit:    BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: size, height: size,
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))),
          errorBuilder: (_, __, ___) => SizedBox(
            width: size, height: size,
            child: const Icon(Icons.broken_image_outlined,
                color: Colors.grey)),
        ),
      ),
    );
  }

  void _mostrarVisor(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Imagen grande
              GestureDetector(
                onTap: () {}, // evitar que el tap en la imagen cierre
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) =>
                        progress == null
                            ? child
                            : const SizedBox(
                                width: 200, height: 200,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white))),
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined,
                            color: Colors.white, size: 64),
                  ),
                ),
              ),
              // Botón cerrar
              Positioned(
                top: 0, right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 20)),
                )),
              // Hint cerrar
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Tocá fuera para cerrar',
                      style: TextStyle(
                          color: Colors.white, fontSize: 12)))),
            ],
          ),
        ),
      ),
    );
  }
}
