// lib/models/models.dart
// ── Rol ──────────────────────────────────────────────────────
class Rol {
  final String id;
  final String nombre;
  final String? descripcion;
  const Rol({required this.id, required this.nombre, this.descripcion});
  factory Rol.fromMap(Map<String, dynamic> m) =>
      Rol(id: m['id'], nombre: m['nombre'], descripcion: m['descripcion']);
}

// ── Usuario ───────────────────────────────────────────────────
class Usuario {
  final String id;
  final String rolId;
  final String rolNombre;
  final String nombre;
  final String email;
  final String estado;
  final bool   primerLogin;

  const Usuario({
    required this.id,
    required this.rolId,
    required this.rolNombre,
    required this.nombre,
    required this.email,
    required this.estado,
    this.primerLogin = false,
  });

  bool get isAdmin     => rolNombre == 'administrador';
  bool get isTecnico   => rolNombre == 'tecnico';
  bool get isEncargado => rolNombre == 'encargado';
  bool get isPaniolero => rolNombre == 'paniolero';

  factory Usuario.fromMap(Map<String, dynamic> m) => Usuario(
        id:          m['id'],
        rolId:       m['rol_id'],
        rolNombre:   m['roles']?['nombre'] ?? '',
        nombre:      m['nombre'],
        email:       m['email'],
        estado:      m['estado'] ?? 'activo',
        primerLogin: m['primer_login'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'rol_id': rolId, 'nombre': nombre, 'email': email, 'estado': estado,
      };
}

// ── Sector ────────────────────────────────────────────────────
class Sector {
  final String id;
  final String nombre;
  final String? descripcion;
  const Sector({required this.id, required this.nombre, this.descripcion});
  factory Sector.fromMap(Map<String, dynamic> m) =>
      Sector(id: m['id'], nombre: m['nombre'], descripcion: m['descripcion']);
  Map<String, dynamic> toMap() => {'nombre': nombre, 'descripcion': descripcion};
}

// ── Maquina ───────────────────────────────────────────────────
class Maquina {
  final String  id;
  final String  sectorId;
  final String? sectorNombre;
  final String  nombre;
  final String  codigo;
  final String  estado;
  final String? descripcion;
  final String? imagenUrl;

  const Maquina({
    required this.id,
    required this.sectorId,
    this.sectorNombre,
    required this.nombre,
    required this.codigo,
    required this.estado,
    this.descripcion,
    this.imagenUrl,
  });

  factory Maquina.fromMap(Map<String, dynamic> m) => Maquina(
        id:           m['id'],
        sectorId:     m['sector_id'],
        sectorNombre: m['sectores']?['nombre'],
        nombre:       m['nombre'],
        codigo:       m['codigo'],
        estado:       m['estado'] ?? 'activo',
        descripcion:  m['descripcion'],
        imagenUrl:    m['imagen_url'],
      );

  Map<String, dynamic> toMap() => {
        'sector_id':   sectorId,
        'nombre':      nombre,
        'codigo':      codigo,
        'estado':      estado,
        'descripcion': descripcion,
        'imagen_url':  imagenUrl,
      };
}

// ── Repuesto ──────────────────────────────────────────────────
class Repuesto {
  final String  id;
  final String? codigo;
  final String  descripcion;
  final int     stockActual;
  final int     stockMinimo;
  final String? ubicacion;
  final String? imagenUrl;
  final bool    activo;
  final int?    ref;

  const Repuesto({
    required this.id,
    this.codigo,
    required this.descripcion,
    required this.stockActual,
    required this.stockMinimo,
    this.ubicacion,
    this.imagenUrl,
    this.activo = true,
    this.ref,
  });

  bool get stockBajo => stockActual < stockMinimo;

  factory Repuesto.fromMap(Map<String, dynamic> m) => Repuesto(
    id:          m['id'],
    codigo:      m['codigo'],
    descripcion: m['descripcion'],
    stockActual: m['stock_actual'] ?? 0,
    stockMinimo: m['stock_minimo'] ?? 0,
    ubicacion:   m['ubicacion'],
    imagenUrl:   m['imagen_url'],
    activo:      m['activo'] ?? true,
    ref:         m['ref'],
  );

  Map<String, dynamic> toInsert() => {
    'codigo':       codigo,
    'descripcion':  descripcion,
    'stock_actual': stockActual,
    'stock_minimo': stockMinimo,
    'ubicacion':    ubicacion,
    'imagen_url':   imagenUrl,
    'activo':       activo,
  };

  Map<String, dynamic> toUpdate() => {
    'codigo':       codigo,
    'descripcion':  descripcion,
    'stock_minimo': stockMinimo,
    'ubicacion':    ubicacion,
    'imagen_url':   imagenUrl,
    'activo':       activo,
  };
}

// ── Ticket ────────────────────────────────────────────────────
class Ticket {
  final String  id;
  final String? numero;
  final String? maquinaId;
  final String? maquinaNombre;
  final String  creadoPor;
  final String? creadoPorNombre;
  final String? tecnicoId;
  final String? tecnicoNombre;
  final String  estado;
  final String  descripcionDesperfecto;
  final String? observacionEncargado;
  final String? observacionTecnico;
  final DateTime createdAt;
  final String? fotoUrl;

  const Ticket({
    required this.id,
    this.numero,
    this.maquinaId,
    this.maquinaNombre,
    required this.creadoPor,
    this.creadoPorNombre,
    this.tecnicoId,
    this.tecnicoNombre,
    required this.estado,
    required this.descripcionDesperfecto,
    this.observacionEncargado,
    this.observacionTecnico,
    required this.createdAt,
    this.fotoUrl,
  });

  factory Ticket.fromMap(Map<String, dynamic> m) => Ticket(
        id:                     m['id'],
        numero:                 m['numero'],
        maquinaId:              m['maquina_id'],
        maquinaNombre:          m['maquinas']?['nombre'],
        creadoPor:              m['creado_por'],
        creadoPorNombre:        m['creador']?['nombre'],
        tecnicoId:              m['tecnico_id'],
        tecnicoNombre:          m['tecnico']?['nombre'],
        estado:                 m['estado'] ?? 'abierto',
        descripcionDesperfecto: m['descripcion_desperfecto'] ?? '',
        observacionEncargado:   m['observacion_encargado'],
        observacionTecnico:     m['observacion_tecnico'],
        createdAt:              DateTime.parse(m['created_at']),
        fotoUrl:                m['foto_url'],
      );
}

// ── Historial de ticket ───────────────────────────────────────
class TicketHistorial {
  final String id;
  final String ticketId;
  final String usuarioId;
  final String? usuarioNombre;
  final String? estadoAnterior;
  final String estadoNuevo;
  final String? comentario;
  final DateTime fecha;

  const TicketHistorial({
    required this.id,
    required this.ticketId,
    required this.usuarioId,
    this.usuarioNombre,
    this.estadoAnterior,
    required this.estadoNuevo,
    this.comentario,
    required this.fecha,
  });

  factory TicketHistorial.fromMap(Map<String, dynamic> m) => TicketHistorial(
        id:              m['id'],
        ticketId:        m['ticket_id'],
        usuarioId:       m['usuario_id'],
        usuarioNombre:   m['usuarios']?['nombre'],
        estadoAnterior:  m['estado_anterior'],
        estadoNuevo:     m['estado_nuevo'],
        comentario:      m['comentario'],
        fecha:           DateTime.parse(m['fecha']),
      );
}

// ── Ingreso de repuesto ───────────────────────────────────────
class IngresoRepuesto {
  final String   id;
  final String   repuestoId;
  final String?  repuestoCodigo;
  final String?  repuestoDescripcion;
  final int?     repuestoRef;
  final String   registradoPor;
  final int      cantidad;
  final String   quienEntrega;
  final String?  descripcion;
  final DateTime fecha; // ← ahora DateTime (UTC→local al mostrar)

  const IngresoRepuesto({
    required this.id,
    required this.repuestoId,
    this.repuestoCodigo,
    this.repuestoDescripcion,
    this.repuestoRef,
    required this.registradoPor,
    required this.cantidad,
    required this.quienEntrega,
    this.descripcion,
    required this.fecha,
  });

  factory IngresoRepuesto.fromMap(Map<String, dynamic> m) => IngresoRepuesto(
        id:                  m['id'],
        repuestoId:          m['repuesto_id'],
        repuestoCodigo:      m['repuestos']?['codigo'],
        repuestoDescripcion: m['repuestos']?['descripcion'],
        repuestoRef:         m['repuestos']?['ref'],
        registradoPor:       m['registrado_por'],
        cantidad:            m['cantidad'] ?? 0,
        quienEntrega:        m['quien_entrega'] ?? '',
        descripcion:         m['descripcion'],
        fecha:               DateTime.parse(m['fecha']).toLocal(),
      );
}

// ── Salida de repuesto ────────────────────────────────────────
class SalidaRepuesto {
  final String   id;
  final String   repuestoId;
  final String?  repuestoCodigo;
  final String?  repuestoDescripcion;
  final int?     repuestoRef;
  final String?  ticketId;
  final String?  ticketNumero;
  final String   registradoPor;
  final int      cantidad;
  final DateTime fecha; // ← ahora DateTime (UTC→local al mostrar)
  final String?  observacion;
  final String?  quienRetira;

  const SalidaRepuesto({
    required this.id,
    required this.repuestoId,
    this.repuestoCodigo,
    this.repuestoDescripcion,
    this.repuestoRef,
    this.ticketId,
    this.ticketNumero,
    required this.registradoPor,
    required this.cantidad,
    required this.fecha,
    this.observacion,
    this.quienRetira,
  });

  factory SalidaRepuesto.fromMap(Map<String, dynamic> m) => SalidaRepuesto(
    id:                  m['id'],
    repuestoId:          m['repuesto_id'],
    repuestoCodigo:      m['repuestos']?['codigo'],
    repuestoDescripcion: m['repuestos']?['descripcion'],
    repuestoRef:         m['repuestos']?['ref'],
    ticketId:            m['ticket_id'],
    ticketNumero:        m['tickets']?['numero'],
    registradoPor:       m['registrado_por'],
    cantidad:            m['cantidad'] ?? 0,
    fecha:               DateTime.parse(m['fecha']).toLocal(),
    observacion:         m['observacion'],
    quienRetira:         m['quien_retira'],
  );
}

// ── RepuestoMaquina ───────────────────────────────────────────
class RepuestoMaquina {
  final String  id;
  final String  repuestoId;
  final String  maquinaId;
  final String? repuestoCodigo;
  final String? repuestoDescripcion;
  final String? maquinaNombre;
  final String? maquinaCodigo;
  final String? maquinaEstado;
  final int     cantidad;
  final String? ubicacionEnMaquina;
  final String? observacion;

  const RepuestoMaquina({
    required this.id,
    required this.repuestoId,
    required this.maquinaId,
    this.repuestoCodigo,
    this.repuestoDescripcion,
    this.maquinaNombre,
    this.maquinaCodigo,
    this.maquinaEstado,
    required this.cantidad,
    this.ubicacionEnMaquina,
    this.observacion,
  });

  factory RepuestoMaquina.fromMap(Map<String, dynamic> m) => RepuestoMaquina(
    id:                  m['id'],
    repuestoId:          m['repuesto_id'],
    maquinaId:           m['maquina_id'],
    repuestoCodigo:      m['repuestos']?['codigo'],
    repuestoDescripcion: m['repuestos']?['descripcion'],
    maquinaNombre:       m['maquinas']?['nombre'],
    maquinaCodigo:       m['maquinas']?['codigo'],
    maquinaEstado:       m['maquinas']?['estado'],
    cantidad:            m['cantidad'] ?? 1,
    ubicacionEnMaquina:  m['ubicacion_en_maquina'],
    observacion:         m['observacion'],
  );

  Map<String, dynamic> toInsert(String maquinaId) => {
    'repuesto_id':          repuestoId,
    'maquina_id':           maquinaId,
    'cantidad':             cantidad,
    'ubicacion_en_maquina': ubicacionEnMaquina,
    'observacion':          observacion,
  };

  Map<String, dynamic> toUpdate() => {
    'cantidad':             cantidad,
    'ubicacion_en_maquina': ubicacionEnMaquina,
    'observacion':          observacion,
  };
}

// ── Foto de ticket ────────────────────────────────────────────
class TicketFoto {
  final String   id;
  final String   ticketId;
  final String   subidoPor;
  final String?  subidoPorNombre;
  final String   fotoUrl;
  final String?  descripcion;
  final DateTime createdAt;

  const TicketFoto({
    required this.id,
    required this.ticketId,
    required this.subidoPor,
    this.subidoPorNombre,
    required this.fotoUrl,
    this.descripcion,
    required this.createdAt,
  });

  factory TicketFoto.fromMap(Map<String, dynamic> m) => TicketFoto(
    id:              m['id'],
    ticketId:        m['ticket_id'],
    subidoPor:       m['subido_por'],
    subidoPorNombre: m['usuarios']?['nombre'],
    fotoUrl:         m['foto_url'],
    descripcion:     m['descripcion'],
    createdAt:       DateTime.parse(m['created_at']),
  );
}

// ── Notificación ──────────────────────────────────────────────
class Notificacion {
  final String   id;
  final String   tipo;
  final String   mensaje;
  final String?  ticketId;
  final String   paraUsuarioId;
  final String?  deUsuarioId;
  final String?  deUsuarioNombre;
  final bool     leida;
  final DateTime? leidaEn;
  final DateTime createdAt;

  const Notificacion({
    required this.id,
    required this.tipo,
    required this.mensaje,
    this.ticketId,
    required this.paraUsuarioId,
    this.deUsuarioId,
    this.deUsuarioNombre,
    required this.leida,
    this.leidaEn,
    required this.createdAt,
  });

  factory Notificacion.fromMap(Map<String, dynamic> m) => Notificacion(
    id:              m['id'],
    tipo:            m['tipo'],
    mensaje:         m['mensaje'],
    ticketId:        m['ticket_id'],
    paraUsuarioId:   m['para_usuario_id'],
    deUsuarioId:     m['de_usuario_id'],
    deUsuarioNombre: m['de_usuario']?['nombre'],
    leida:           m['leida'] ?? false,
    leidaEn:         m['leida_en'] != null
                         ? DateTime.parse(m['leida_en']) : null,
    createdAt:       DateTime.parse(m['created_at']),
  );
}

class TiposNotificacion {
  static const ticketCerrado         = 'ticket_cerrado';
  static const confirmacionEncargado = 'confirmacion_encargado';
}