// lib/repositories/repositories.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

final _db = Supabase.instance.client;

// ── Usuarios ──────────────────────────────────────────────────
class UsuariosRepository {
  Future<List<Usuario>> getAll() async {
    final data = await _db
        .from('usuarios')
        .select('*, roles(nombre)')
        .eq('estado', 'activo')
        .order('nombre');
    return (data as List).map((e) => Usuario.fromMap(e)).toList();
  }

  Future<Usuario?> getById(String id) async {
    final data = await _db
        .from('usuarios')
        .select('*, roles(nombre)')
        .eq('id', id)
        .maybeSingle();
    return data == null ? null : Usuario.fromMap(data);
  }

  Future<void> update(String id, {
    String? nombre,
    String? rolId,
    String? estado,
    String? email,
  }) async {
    final map = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (nombre != null) map['nombre']  = nombre;
    if (rolId  != null) map['rol_id']  = rolId;
    if (estado != null) map['estado']  = estado;
    if (email  != null) map['email']   = email;
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
    final data = await _db
        .from('maquinas')
        .select('*, sectores(nombre)')
        .order('nombre');
    return (data as List).map((e) => Maquina.fromMap(e)).toList();
  }

  Future<List<Maquina>> getBySector(String sectorId) async {
    final data = await _db
        .from('maquinas')
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
    final List<dynamic> todos = [];
    int desde = 0;
    const paso = 1000;

    while (true) {
      final data = await _db
          .from('repuestos')
          .select()
          .eq('activo', true)
          .order('descripcion', ascending: true)
          .range(desde, desde + paso - 1);

      todos.addAll(data as List);
      if ((data as List).length < paso) break;
      desde += paso;
    }

    return todos.map((e) => Repuesto.fromMap(e)).toList();
  }

  Future<List<Repuesto>> getAllIncluyendoInactivos() async {
    final List<dynamic> todos = [];
    int desde = 0;
    const paso = 1000;

    while (true) {
      final data = await _db
          .from('repuestos')
          .select()
          .order('descripcion', ascending: true)
          .range(desde, desde + paso - 1);

      todos.addAll(data as List);
      if ((data as List).length < paso) break;
      desde += paso;
    }

    return todos.map((e) => Repuesto.fromMap(e)).toList();
  }

  Future<void> create(Repuesto r) async =>
      _db.from('repuestos').insert(r.toInsert());

  Future<void> update(String id, Repuesto r) async =>
      _db.from('repuestos').update(r.toUpdate()).eq('id', id);

  Future<void> delete(String id) async =>
      _db.from('repuestos').delete().eq('id', id);

  Future<void> toggleActivo(String id, bool activo) async =>
      _db.from('repuestos').update({'activo': activo}).eq('id', id);
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
    final data = await _db
        .from('ticket_historial')
        .select('*, usuarios(nombre)')
        .eq('ticket_id', ticketId)
        .order('fecha', ascending: false);
    return (data as List).map((e) => TicketHistorial.fromMap(e)).toList();
  }

  Future<void> create({
    String? maquinaId,
    required String descripcion,
    String? observacion,
    String? numero,
    String? fotoUrl,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _db.from('tickets').insert({
      'maquina_id':              maquinaId,
      'creado_por':              uid,
      'descripcion_desperfecto': descripcion,
      'observacion_encargado':   observacion,
      'estado':                  'abierto',
      'numero':                  numero,
      'foto_url':                fotoUrl,
    });
  }

  Future<void> asignarTecnico(String ticketId, String tecnicoId) async {
    await _db.from('tickets').update({
      'tecnico_id': tecnicoId,
      'estado':     'asignado',
    }).eq('id', ticketId);
  }

  Future<void> updateEstado(String ticketId, String estado,
      {String? comentario}) async {
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

  Future<void> updateNumero(String ticketId, String? numero) async {
    await _db.from('tickets').update({'numero': numero}).eq('id', ticketId);
  }

  Future<void> updateFotoUrl(String ticketId, String? fotoUrl) async {
    await _db.from('tickets').update({'foto_url': fotoUrl}).eq('id', ticketId);
  }

  Future<void> cerrar(String ticketId) async {
    await _db.from('tickets').update({'estado': 'cerrado'}).eq('id', ticketId);
  }

  Future<void> delete(String id) async =>
      _db.from('tickets').delete().eq('id', id);
}

// ── Fotos de tickets ──────────────────────────────────────────
class TicketFotosRepository {
  static const _bucket = 'ticket-fotos';

  Future<String> subirFoto(File archivo, String ticketId) async {
    final uid  = _db.auth.currentUser!.id;
    final ext  = archivo.path.split('.').last;
    final path = '$uid/$ticketId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from(_bucket).upload(
      path,
      archivo,
      fileOptions: const FileOptions(upsert: false),
    );

    return _db.storage.from(_bucket).getPublicUrl(path);
  }

  Future<List<TicketFoto>> getFotos(String ticketId) async {
    final data = await _db
        .from('ticket_fotos')
        .select('*, usuarios:subido_por(nombre)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => TicketFoto.fromMap(e)).toList();
  }

  Future<void> agregarFoto({
    required String ticketId,
    required String fotoUrl,
    String? descripcion,
  }) async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('ticket_fotos').insert({
      'ticket_id':   ticketId,
      'subido_por':  uid,
      'foto_url':    fotoUrl,
      'descripcion': descripcion,
    });
  }

  Future<void> eliminarFoto(TicketFoto foto) async {
    final uri  = Uri.parse(foto.fotoUrl);
    final path = uri.pathSegments
        .skipWhile((s) => s != _bucket)
        .skip(1)
        .join('/');

    await _db.storage.from(_bucket).remove([path]);
    await _db.from('ticket_fotos').delete().eq('id', foto.id);
  }
}

// ── Movimientos ───────────────────────────────────────────────
class MovimientosRepository {
  Future<List<IngresoRepuesto>> getIngresos() async {
    final data = await _db
        .from('ingreso_repuestos')
        .select('*, repuestos(codigo, descripcion, ref)')
        .order('created_at', ascending: false);
    return (data as List).map((e) => IngresoRepuesto.fromMap(e)).toList();
  }

  Future<void> createIngreso({
    required String repuestoId,
    required int    cantidad,
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

  Future<void> updateIngreso(String id, {
    required String repuestoId,
    required int    cantidad,
    required String quienEntrega,
    String? descripcion,
  }) async {
    await _db.from('ingreso_repuestos').update({
      'repuesto_id':   repuestoId,
      'cantidad':      cantidad,
      'quien_entrega': quienEntrega,
      'descripcion':   descripcion,
    }).eq('id', id);
  }

  Future<void> deleteIngreso(String id) async =>
      _db.from('ingreso_repuestos').delete().eq('id', id);

  // ── Salidas ───────────────────────────────────────────────
  Future<List<SalidaRepuesto>> getSalidas() async {
    final data = await _db
        .from('salida_repuestos')
        .select('*, repuestos(codigo, descripcion, ref), tickets(numero)')
        .order('created_at', ascending: false);
    return (data as List).map((e) => SalidaRepuesto.fromMap(e)).toList();
  }

  // ── Salidas por ticket ────────────────────────────────────
  Future<List<SalidaRepuesto>> getSalidasPorTicket(String ticketId) async {
    final data = await _db
        .from('salida_repuestos')
        .select('*, repuestos(descripcion, codigo)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => SalidaRepuesto.fromMap(e)).toList();
  }

  Future<void> createSalida({
    required String repuestoId,
    required int    cantidad,
    String? ticketId,
    String? observacion,
    String? quienRetira,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _db.from('salida_repuestos').insert({
      'repuesto_id':    repuestoId,
      'ticket_id':      ticketId,
      'registrado_por': uid,
      'cantidad':       cantidad,
      'observacion':    observacion,
      'quien_retira':   quienRetira,
      'fecha':          DateTime.now().toIso8601String().substring(0, 10),
    });
  }

  Future<void> updateSalida(String id, {
    required String repuestoId,
    required int    cantidad,
    String? ticketId,
    String? observacion,
    String? quienRetira,
  }) async {
    await _db.from('salida_repuestos').update({
      'repuesto_id':  repuestoId,
      'ticket_id':    ticketId,
      'cantidad':     cantidad,
      'observacion':  observacion,
      'quien_retira': quienRetira,
    }).eq('id', id);
  }

  Future<void> deleteSalida(String id) async =>
      _db.from('salida_repuestos').delete().eq('id', id);
}

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

  Future<List<RepuestoMaquina>> getByRepuesto(String repuestoId) async {
    final data = await _db
        .from('repuestos_maquinas')
        .select('*, maquinas(nombre, codigo, estado)')
        .eq('repuesto_id', repuestoId)
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

// ── Notificaciones ────────────────────────────────────────────
class NotificacionesRepository {
  Future<List<Notificacion>> getMisNotificaciones() async {
    final uid  = _db.auth.currentUser!.id;
    final data = await _db
        .from('notificaciones')
        .select('*, de_usuario:de_usuario_id(nombre)')
        .eq('para_usuario_id', uid)
        .eq('leida', false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Notificacion.fromMap(e)).toList();
  }

  Future<void> crear({
    required String tipo,
    required String mensaje,
    required String paraUsuarioId,
    String? ticketId,
    String? deUsuarioId,
  }) async {
    await _db.from('notificaciones').insert({
      'tipo':            tipo,
      'mensaje':         mensaje,
      'para_usuario_id': paraUsuarioId,
      'ticket_id':       ticketId,
      'de_usuario_id':   deUsuarioId,
      'leida':           false,
    });
  }

  Future<void> marcarLeida(String notifId) async {
    await _db.from('notificaciones').update({
      'leida':    true,
      'leida_en': DateTime.now().toIso8601String(),
    }).eq('id', notifId);
  }

  Future<List<Notificacion>> getConfirmaciones(String ticketId) async {
    final data = await _db
        .from('notificaciones')
        .select('*, de_usuario:de_usuario_id(nombre)')
        .eq('ticket_id', ticketId)
        .eq('tipo', TiposNotificacion.confirmacionEncargado)
        .order('created_at', ascending: true);
    return (data as List).map((e) => Notificacion.fromMap(e)).toList();
  }
}