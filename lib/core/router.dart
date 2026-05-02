// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../screens/login/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/usuarios/usuarios_screen.dart';
import '../screens/usuarios/usuario_form_screen.dart';
import '../screens/sectores/sectores_screen.dart';
import '../screens/sectores/sector_form_screen.dart';
import '../screens/maquinas/maquinas_screen.dart';
import '../screens/maquinas/maquina_form_screen.dart';
import '../screens/repuestos/repuestos_screen.dart';
import '../screens/repuestos/repuesto_form_screen.dart';
import '../screens/tickets/tickets_screen.dart';
import '../screens/tickets/ticket_form_screen.dart';
import '../screens/tickets/ticket_detalle_screen.dart';
import '../screens/movimientos/ingresos_screen.dart';
import '../screens/movimientos/ingreso_form_screen.dart';
import '../screens/movimientos/salidas_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.valueOrNull?.session != null;
      final onLogin  = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn  &&  onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home',  builder: (_, __) => const HomeScreen()),

      // Usuarios
      GoRoute(path: '/usuarios',       builder: (_, __) => const UsuariosScreen()),
      GoRoute(path: '/usuarios/nuevo', builder: (_, __) => const UsuarioFormScreen()),
      GoRoute(path: '/usuarios/:id',   builder: (_, s)  => UsuarioFormScreen(userId: s.pathParameters['id'])),

      // Sectores
      GoRoute(path: '/sectores',       builder: (_, __) => const SectoresScreen()),
      GoRoute(path: '/sectores/nuevo', builder: (_, __) => const SectorFormScreen()),
      GoRoute(path: '/sectores/:id',   builder: (_, s)  => SectorFormScreen(sectorId: s.pathParameters['id'])),

      // Maquinas
      GoRoute(path: '/maquinas',       builder: (_, __) => const MaquinasScreen()),
      GoRoute(path: '/maquinas/nuevo', builder: (_, __) => const MaquinaFormScreen()),
      GoRoute(path: '/maquinas/:id',   builder: (_, s)  => MaquinaFormScreen(maquinaId: s.pathParameters['id'])),

      // Repuestos
      GoRoute(path: '/repuestos',       builder: (_, __) => const RepuestosScreen()),
      GoRoute(path: '/repuestos/nuevo', builder: (_, __) => const RepuestoFormScreen()),
      GoRoute(path: '/repuestos/:id',   builder: (_, s)  => RepuestoFormScreen(repuestoId: s.pathParameters['id'])),

      // Tickets
      GoRoute(path: '/tickets',        builder: (_, __) => const TicketsScreen()),
      GoRoute(path: '/tickets/nuevo',  builder: (_, __) => const TicketFormScreen()),
      GoRoute(path: '/tickets/:id',    builder: (_, s)  => TicketDetalleScreen(ticketId: s.pathParameters['id']!)),

      // Movimientos
      GoRoute(path: '/ingresos',       builder: (_, __) => const IngresosScreen()),
      GoRoute(path: '/ingresos/nuevo', builder: (_, __) => const IngresoFormScreen()),
      GoRoute(path: '/salidas',        builder: (_, __) => const SalidasScreen()),
    ],
  );
});
