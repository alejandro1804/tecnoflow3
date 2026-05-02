// lib/providers/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../repositories/auth_repository.dart';
import '../repositories/repositories.dart';

// ── Repositorios ──────────────────────────────────────────────
final authRepoProvider        = Provider((_) => AuthRepository());
final usuariosRepoProvider    = Provider((_) => UsuariosRepository());
final rolesRepoProvider       = Provider((_) => RolesRepository());
final sectoresRepoProvider    = Provider((_) => SectoresRepository());
final maquinasRepoProvider    = Provider((_) => MaquinasRepository());
final repuestosRepoProvider   = Provider((_) => RepuestosRepository());
final ticketsRepoProvider     = Provider((_) => TicketsRepository());
final movimientosRepoProvider = Provider((_) => MovimientosRepository());

// ── Auth ──────────────────────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepoProvider).authStream;
});

final myProfileProvider = FutureProvider<Usuario?>((ref) async {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (s) async => s.session == null
        ? null
        : ref.read(authRepoProvider).getMyProfile(),
    loading: () async => null,
    error:   (_, __) async => null,
  );
});

// ── Datos ─────────────────────────────────────────────────────
final usuariosProvider  = FutureProvider<List<Usuario>>(
    (ref) => ref.watch(usuariosRepoProvider).getAll());

final rolesProvider     = FutureProvider<List<Rol>>(
    (ref) => ref.watch(rolesRepoProvider).getAll());

final sectoresProvider  = FutureProvider<List<Sector>>(
    (ref) => ref.watch(sectoresRepoProvider).getAll());

final maquinasProvider  = FutureProvider<List<Maquina>>(
    (ref) => ref.watch(maquinasRepoProvider).getAll());

final repuestosProvider = FutureProvider<List<Repuesto>>(
    (ref) => ref.watch(repuestosRepoProvider).getAll());

final ticketsProvider   = FutureProvider<List<Ticket>>(
    (ref) => ref.watch(ticketsRepoProvider).getAll());

final ingresosProvider  = FutureProvider<List<IngresoRepuesto>>(
    (ref) => ref.watch(movimientosRepoProvider).getIngresos());

final salidasProvider   = FutureProvider<List<SalidaRepuesto>>(
    (ref) => ref.watch(movimientosRepoProvider).getSalidas());
// Agregar en lib/providers/providers.dart

// ── RepuestosMaquinas ─────────────────────────────────────────
final repuestosMaquinasRepoProvider =
Provider((_) => RepuestosMaquinasRepository());

final repuestosMaquinasProvider =
FutureProvider.family<List<RepuestoMaquina>, String>(
        (ref, maquinaId) =>
        ref.watch(repuestosMaquinasRepoProvider).getByMaquina(maquinaId));