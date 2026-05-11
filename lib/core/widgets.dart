// lib/core/widgets.dart
import 'package:flutter/material.dart';
import 'constants.dart';

// Badge de estado para tickets
class EstadoBadge extends StatelessWidget {
  final String estado;
  const EstadoBadge(this.estado, {super.key});

  Color get color {
    switch (estado) {
      case 'abierto':      return Colors.orange;
      case 'asignado':     return Colors.blue;
      case 'en_ejecucion': return Colors.teal;
      case 'en_espera':    return Colors.purple;
      case 'en_revision':  return Colors.indigo;   // ← NUEVO
      case 'cerrado':      return Colors.grey;
      default:             return Colors.grey;
    }
  }

  String get label {
    switch (estado) {
      case 'abierto':      return 'Abierto';
      case 'asignado':     return 'Asignado';
      case 'en_ejecucion': return 'En ejecución';
      case 'en_espera':    return 'En espera';
      case 'en_revision':  return 'En revisión';   // ← NUEVO
      case 'cerrado':      return 'Cerrado';
      default:             return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// Badge de rol
class RolBadge extends StatelessWidget {
  final String rol;
  const RolBadge(this.rol, {super.key});

  Color get color {
    switch (rol) {
      case AppRoles.admin:     return Colors.deepPurple;
      case AppRoles.encargado: return Colors.teal;
      case AppRoles.tecnico:   return Colors.blue;
      case AppRoles.paniolero: return Colors.orange;
      default:                 return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(rol,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// Stock badge para repuestos
class StockBadge extends StatelessWidget {
  final int stock;
  final int minimo;
  const StockBadge({super.key, required this.stock, required this.minimo});

  @override
  Widget build(BuildContext context) {
    final bajo  = stock <= minimo;
    final color = bajo ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Stock: $stock',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// Botón de confirmación de eliminación
Future<bool> confirmarEliminacion(BuildContext context, String mensaje) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Confirmar eliminación'),
      content: Text(mensaje),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.btnCancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(AppStrings.btnDelete),
        ),
      ],
    ),
  );
  return result ?? false;
}

// Loading button
class LoadingButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  final String label;
  const LoadingButton({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              height: 22, width: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Text(label),
    );
  }
}

// Error container
class ErrorContainer extends StatelessWidget {
  final String message;
  const ErrorContainer(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}