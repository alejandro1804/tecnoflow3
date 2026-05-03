// lib/repositories/repositories.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

final _db = Supabase.instance.client;

// ── Usuarios ──────────────────────────────────────────────────
class UsuariosRepository {
  Future<List<Usuario>> getAll() async {
    final data = await _db.from('usuarios').select('*, roles(nombre)').order('nombre');
    return (data as List).map((e) => Usuario.fromMap(e)).toList();
  }

  Future<Usuario?> getById(String id) async {
    final data = await _db.from('usuarios').select('*, roles(nombre)').eq('id', id).maybeSingle();
    return data == null ? null : Usuario.fromMap(data);
  }

  Future<void> update(String id, {String? nombre, String? rolId, String? estado}) async {
    final map = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (nombre != null) map['nombre'] = nombre;
    if (rolId  != null) map['rol_id'] = rolId;
    if (estado != null) map['estado'] = estado;
    await _db.from('usuarios').update(map).eq('id', id);
  }

  Future<void> delete(String id) async =>
      _db.from('usuarios').delete().eq('id', id);
}

// ── Roles ─────────────────────────────────────────────────────
class RolesRepository {
  Future<List<Rol>> getAll() async {
    final data = await _db.from('roles').select().order('nombre');
    return (data as List).map((e) => Rol.fromMap(e)).toList();
  }
}

// ── Sectores ──────────────────────────────────────────────────
class SectoresRepository {
  Future<List<Sector>> getAll() async {
    final data = await _db.from('sectores').select().order('nombre');
    return (data as List).map((e) => Sector.fromMap(e)).toList();
  }

  Future<void> create(Sector s) async =>
      _db.from('sectores').insert(s.toMap());

  Future<void> update(String id, Sector s) async =>
      _db.from('sectores').update(s.toMap()).eq('id', id);

  Future<void> delete(String id) async =>
      _db.from('sectores').delete().eq('id', id);
}

// ── Maquinas ──────────────────────────────────────────────────
class MaquinasRepository {
  Future<List<Maquina>> getAll() async {
    final data = await _db.from('maquinas').select('*, sectores(nombre)').order('nombre');
    return (data as List).map((e) => Maquina.fromMap(e)).toList();
  }

  Future<List<Maquina>> getBySector(String sectorId) async {
    final data = await _db.from('maquinas')
        .select('*, sectores(nombre)')
        .eq('sector_id', sectorId)
        .order('nombre');
    return (data as List).map((e) => Maquina.fromMap(e)).toList();
  }

  Future<void> create(Maquina m) async =>
      _db.from('maquinas').insert(m.toMap());

  Future<void> update(String id, Maquina m) async =>
      _db.from('maquinas').update(m.toMap()).eq('id', id);

  Future<void> delete(String id) async =>
      _db.from('maquinas').delete().eq('id', id);
}

// ── Repuestos ─────────────────────────────────────────────────
class RepuestosRepository {
  Future<List<Repuesto>> getAll() async {
    final data = await _db.from('repuestos').select().order('codigo');
    return (data as List).map((e) => Repuesto.fromMap(e)).toList();
  }

  Future<List<Repuesto>> getStockBajo() async {
    final data = await _db.from('repuestos')
        .select()
        .filter('stock_actual', 'lte', 'stock_minimo')
        .order('codigo');
    return (data as List).map((e) => Repuesto.fromMap(e)).toList();
  }

  Future<void> create(Repuesto r) async =>
      _db.from('repuestos').insert(r.toInsert());

  Future<void> update(String id, Repuesto r) async =>
      _db.from('repuestos').update(r.toUpdate()).eq('id', id);

  Future<void> delete(String id) async =>
      _db.from('repuestos').delete().eq('id', id);
}

// ── Tickets ───────────────────────────────────────────────────
class TicketsRepository {
  Future<List<Ticket>> getAll() async {
    final data = await _db.from('tickets').select('''
      *,
      maquinas(nombre),
      creador:creado_por(nombre),
      tecnico:tecnico_id(nombre)
    ''').order('created_at', ascending: false);
    return (data as List).map((e) => Ticket.fromMap(e)).toList();
  }

  Future<Ticket?> getById(String id) async {
    final data = await _db.from('tickets').select('''
      *,
      maquinas(nombre),
      creador:creado_por(nombre),
      tecnico:tecnico_id(nombre)
    ''').eq('id', id).maybeSingle();
    return data == null ? null : Ticket.fromMap(data);
  }

  Future<List<TicketHistorial>> getHistorial(String ticketId) async {
    final data = await _db.from('ticket_historial')
        .select('*, usuarios(nombre)')
        .eq('ticket_id', ticketId)
        .order('fecha', ascending: false);
    return (data as List).map((e) => TicketHistorial.fromMap(e)).toList();
  }

  Future<void> create({
    required String maquinaId,
    required String descripcion,
    String? observacion,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _db.from('tickets').insert({
      'maquina_id':              maquinaId,
      'creado_por':              uid,
      'descripcion_desperfecto': descripcion,
      'observacion_encargado':   observacion,
      'estado':                  'abierto',
    });
  }

  Future<void> asignarTecnico(String ticketId, String tecnicoId) async {
    await _db.from('tickets').update({
      'tecnico_id': tecnicoId,
      'estado':     'asignado',
    }).eq('id', ticketId);
  }

  Future<void> updateEstado(String ticketId, String estado, {String? comentario}) async {
    await _db.from('tickets').update({
      'estado':              estado,
      'observacion_tecnico': comentario,
    }).eq('id', ticketId);
  }

  Future<void> updateEncargado(String ticketId, {
    String? descripcion,
    String? observacion,
  }) async {
    final map = <String, dynamic>{};
    if (descripcion != null) map['descripcion_desperfecto'] = descripcion;
    if (observacion != null) map['observacion_encargado']   = observacion;
    await _db.from('tickets').update(map).eq('id', ticketId);
  }

  Future<void> cerrar(String ticketId) async {
    await _db.from('tickets').update({'estado': 'cerrado'}).eq('id', ticketId);
  }

  Future<void> delete(String id) async =>
      _db.from('tickets').delete().eq('id', id);
}

// ── Movimientos ───────────────────────────────────────────────
// REEMPLAZAR la clase MovimientosRepository en lib/repositories/repositories.dart

class MovimientosRepository {
  // ── INGRESOS ────────────────────────────────────────────────
  Future<List<IngresoRepuesto>> getIngresos() async {
    final data = await _db.from('ingreso_repuestos')
        .select('*, repuestos(codigo, descripcion)')
        .order('created_at', ascending: false);
    return (data as List).map((e) => IngresoRepuesto.fromMap(e)).toList();
  }

  Future<void> createIngreso({
    required String repuestoId,
    required int cantidad,
    required String quienEntrega,
    String? descripcion,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _db.from('ingreso_repuestos').insert({
      'repuesto_id':    repuestoId,
      'registrado_por': uid,
      'cantidad':       cantidad,
      'quien_entrega':  quienEntrega,
      'descripcion':    descripcion,
      'fecha':          DateTime.now().toIso8601String().substring(0, 10),
    });
  }

  // ── SALIDAS ─────────────────────────────────────────────────
  Future<List<SalidaRepuesto>> getSalidas() async {
    final data = await _db.from('salida_repuestos')
        .select('*, repuestos(codigo, descripcion)')
        .order('created_at', ascending: false);
    return (data as List).map((e) => SalidaRepuesto.fromMap(e)).toList();
  }

  Future<void> createSalida({
    required String repuestoId,
    required int cantidad,
    String? ticketId,
    String? observacion,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _db.from('salida_repuestos').insert({
      'repuesto_id':    repuestoId,
      'ticket_id':      ticketId,
      'registrado_por': uid,
      'cantidad':       cantidad,
      'observacion':    observacion,
      'fecha':          DateTime.now().toIso8601String().substring(0, 10),
    });
  }

  Future<void> updateSalida(String id, {
    required String repuestoId,
    required int cantidad,
    String? ticketId,
    String? observacion,
  }) async {
    await _db.from('salida_repuestos').update({
      'repuesto_id': repuestoId,
      'ticket_id':   ticketId,
      'cantidad':    cantidad,
      'observacion': observacion,
    }).eq('id', id);
  }

  Future<void> deleteSalida(String id) async =>
      _db.from('salida_repuestos').delete().eq('id', id);
}

// Agregar en lib/repositories/repositories.dart
// Pegar ANTES del comentario "// FIN"

// ── RepuestosMaquinas ─────────────────────────────────────────
class RepuestosMaquinasRepository {
  Future<List<RepuestoMaquina>> getByMaquina(String maquinaId) async {
    final data = await _db
        .from('repuestos_maquinas')
        .select('*, repuestos(codigo, descripcion, stock_actual, stock_minimo)')
        .eq('maquina_id', maquinaId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => RepuestoMaquina.fromMap(e)).toList();
  }

  Future<void> create(RepuestoMaquina rm, String maquinaId) async =>
      _db.from('repuestos_maquinas').insert(rm.toInsert(maquinaId));

  Future<void> update(String id, RepuestoMaquina rm) async =>
      _db.from('repuestos_maquinas').update(rm.toUpdate()).eq('id', id);

  Future<void> delete(String id) async =>
      _db.from('repuestos_maquinas').delete().eq('id', id);
}

