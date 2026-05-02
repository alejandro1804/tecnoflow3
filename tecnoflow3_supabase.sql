-- ============================================================
--  TECNOFLOW3 — Script SQL completo para Supabase
--  Tablas, restricciones, funciones, triggers y RLS
--  Orden: independientes → dependientes
-- ============================================================

-- ─────────────────────────────────────────
-- 1. ROLES
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL UNIQUE CHECK (nombre IN ('administrador','tecnico','encargado')),
  descripcion TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.roles (nombre, descripcion) VALUES
  ('administrador', 'Acceso completo al sistema'),
  ('tecnico',       'Gestiona tickets asignados y consulta stock'),
  ('encargado',     'Crea tickets y hace seguimiento de sectores a su cargo')
ON CONFLICT (nombre) DO NOTHING;

-- ─────────────────────────────────────────
-- 2. USUARIOS (extiende auth.users)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.usuarios (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  rol_id     UUID NOT NULL REFERENCES public.roles(id),
  nombre     TEXT NOT NULL,
  email      TEXT NOT NULL UNIQUE,
  estado     TEXT NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo','inactivo')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────
-- 3. SECTORES
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sectores (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL UNIQUE,
  descripcion TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────
-- 4. ENCARGADO_SECTOR (muchos a muchos)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.encargado_sector (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id  UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  sector_id   UUID NOT NULL REFERENCES public.sectores(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (usuario_id, sector_id)
);

-- ─────────────────────────────────────────
-- 5. MAQUINAS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maquinas (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sector_id   UUID NOT NULL REFERENCES public.sectores(id),
  nombre      TEXT NOT NULL,
  codigo      TEXT NOT NULL UNIQUE,
  estado      TEXT NOT NULL DEFAULT 'activo'
              CHECK (estado IN ('activo','inactivo','en_reparacion')),
  descripcion TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────
-- 6. REPUESTOS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.repuestos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo       TEXT NOT NULL UNIQUE,
  descripcion  TEXT NOT NULL,
  stock_actual INT  NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
  stock_minimo INT  NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0),
  ubicacion    TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────
-- 7. REPUESTOS_MAQUINAS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.repuestos_maquinas (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  repuesto_id          UUID NOT NULL REFERENCES public.repuestos(id) ON DELETE CASCADE,
  maquina_id           UUID NOT NULL REFERENCES public.maquinas(id)  ON DELETE CASCADE,
  cantidad             INT  NOT NULL DEFAULT 1 CHECK (cantidad > 0),
  ubicacion_en_maquina TEXT,
  observacion          TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────
-- 8. TICKETS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tickets (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  maquina_id              UUID NOT NULL REFERENCES public.maquinas(id),
  creado_por              UUID NOT NULL REFERENCES public.usuarios(id),
  tecnico_id              UUID REFERENCES public.usuarios(id),
  estado                  TEXT NOT NULL DEFAULT 'abierto'
                          CHECK (estado IN ('abierto','asignado','en_ejecucion','en_espera','cerrado')),
  descripcion_desperfecto TEXT NOT NULL,
  observacion_encargado   TEXT,
  observacion_tecnico     TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────
-- 9. TICKET_HISTORIAL
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ticket_historial (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id       UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  usuario_id      UUID NOT NULL REFERENCES public.usuarios(id),
  estado_anterior TEXT,
  estado_nuevo    TEXT NOT NULL,
  comentario      TEXT,
  fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────
-- 10. INGRESO_REPUESTOS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ingreso_repuestos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  repuesto_id     UUID NOT NULL REFERENCES public.repuestos(id),
  registrado_por  UUID NOT NULL REFERENCES public.usuarios(id),
  cantidad        INT  NOT NULL CHECK (cantidad > 0),
  quien_entrega   TEXT NOT NULL,
  descripcion     TEXT,
  fecha           DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─────────────────────────────────────────
-- 11. SALIDA_REPUESTOS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.salida_repuestos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  repuesto_id     UUID NOT NULL REFERENCES public.repuestos(id),
  ticket_id       UUID NOT NULL REFERENCES public.tickets(id),
  registrado_por  UUID NOT NULL REFERENCES public.usuarios(id),
  cantidad        INT  NOT NULL CHECK (cantidad > 0),
  fecha           DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- FUNCIONES AUXILIARES
-- ============================================================

-- Obtener el rol del usuario actual
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT AS $$
  SELECT r.nombre
  FROM public.usuarios u
  JOIN public.roles r ON r.id = u.rol_id
  WHERE u.id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Verificar si el usuario actual es encargado de un sector dado
CREATE OR REPLACE FUNCTION public.es_encargado_de_sector(p_sector_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.encargado_sector
    WHERE usuario_id = auth.uid()
      AND sector_id  = p_sector_id
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Auto-crear usuario al registrarse en Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_rol_id UUID;
  v_rol    TEXT;
BEGIN
  v_rol := COALESCE(NEW.raw_user_meta_data->>'rol', 'tecnico');
  SELECT id INTO v_rol_id FROM public.roles WHERE nombre = v_rol;
  INSERT INTO public.usuarios (id, rol_id, nombre, email)
  VALUES (
    NEW.id,
    v_rol_id,
    COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email,'@',1)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_usuarios_updated_at
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_repuestos_updated_at
  BEFORE UPDATE ON public.repuestos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_tickets_updated_at
  BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Actualizar stock al ingresar repuestos
CREATE OR REPLACE FUNCTION public.actualizar_stock_ingreso()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.repuestos
    SET stock_actual = stock_actual + NEW.cantidad
  WHERE id = NEW.repuesto_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_stock_ingreso
  AFTER INSERT ON public.ingreso_repuestos
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_stock_ingreso();

-- Actualizar stock al registrar salida (con control de stock negativo)
CREATE OR REPLACE FUNCTION public.actualizar_stock_salida()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT stock_actual FROM public.repuestos WHERE id = NEW.repuesto_id) < NEW.cantidad THEN
    RAISE EXCEPTION 'Stock insuficiente para el repuesto %', NEW.repuesto_id;
  END IF;
  UPDATE public.repuestos
    SET stock_actual = stock_actual - NEW.cantidad
  WHERE id = NEW.repuesto_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_stock_salida
  AFTER INSERT ON public.salida_repuestos
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_stock_salida();

-- Registrar historial automático al cambiar estado de ticket
CREATE OR REPLACE FUNCTION public.registrar_historial_ticket()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado THEN
    INSERT INTO public.ticket_historial
      (ticket_id, usuario_id, estado_anterior, estado_nuevo, comentario)
    VALUES
      (NEW.id, auth.uid(), OLD.estado, NEW.estado, NEW.observacion_tecnico);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_ticket_historial
  AFTER UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.registrar_historial_ticket();

-- ============================================================
-- HABILITAR RLS
-- ============================================================
ALTER TABLE public.roles              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sectores           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.encargado_sector   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maquinas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.repuestos          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.repuestos_maquinas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_historial   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingreso_repuestos  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salida_repuestos   ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- POLÍTICAS RLS
-- ============================================================

-- ── ROLES ────────────────────────────────────────────────────
CREATE POLICY "roles_select_todos"
  ON public.roles FOR SELECT TO authenticated USING (true);

CREATE POLICY "roles_admin_full"
  ON public.roles FOR ALL TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- ── USUARIOS ──────────────────────────────────────────────────
CREATE POLICY "usuarios_select_todos"
  ON public.usuarios FOR SELECT TO authenticated USING (true);

CREATE POLICY "usuarios_insert_admin"
  ON public.usuarios FOR INSERT TO authenticated
  WITH CHECK (public.get_my_role() = 'administrador');

CREATE POLICY "usuarios_update_admin"
  ON public.usuarios FOR UPDATE TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

CREATE POLICY "usuarios_update_propio"
  ON public.usuarios FOR UPDATE TO authenticated
  USING (id = auth.uid() AND public.get_my_role() <> 'administrador')
  WITH CHECK (
    id = auth.uid()
    AND rol_id = (SELECT rol_id FROM public.usuarios WHERE id = auth.uid())
  );

CREATE POLICY "usuarios_delete_admin"
  ON public.usuarios FOR DELETE TO authenticated
  USING (public.get_my_role() = 'administrador');

-- ── SECTORES ──────────────────────────────────────────────────
CREATE POLICY "sectores_select_todos"
  ON public.sectores FOR SELECT TO authenticated USING (true);

CREATE POLICY "sectores_admin_full"
  ON public.sectores FOR ALL TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- ── ENCARGADO_SECTOR ──────────────────────────────────────────
CREATE POLICY "encargado_sector_select_todos"
  ON public.encargado_sector FOR SELECT TO authenticated USING (true);

CREATE POLICY "encargado_sector_admin_full"
  ON public.encargado_sector FOR ALL TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- ── MAQUINAS ──────────────────────────────────────────────────
CREATE POLICY "maquinas_select_todos"
  ON public.maquinas FOR SELECT TO authenticated USING (true);

CREATE POLICY "maquinas_admin_full"
  ON public.maquinas FOR ALL TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- ── REPUESTOS ─────────────────────────────────────────────────
CREATE POLICY "repuestos_select_todos"
  ON public.repuestos FOR SELECT TO authenticated USING (true);

CREATE POLICY "repuestos_admin_full"
  ON public.repuestos FOR ALL TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- ── REPUESTOS_MAQUINAS ────────────────────────────────────────
CREATE POLICY "repuestos_maquinas_select_todos"
  ON public.repuestos_maquinas FOR SELECT TO authenticated USING (true);

CREATE POLICY "repuestos_maquinas_admin_full"
  ON public.repuestos_maquinas FOR ALL TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- ── TICKETS ───────────────────────────────────────────────────

-- SELECT: admin y encargado ven todos; técnico solo los suyos
CREATE POLICY "tickets_select_admin_encargado"
  ON public.tickets FOR SELECT TO authenticated
  USING (public.get_my_role() IN ('administrador','encargado'));

CREATE POLICY "tickets_select_tecnico"
  ON public.tickets FOR SELECT TO authenticated
  USING (
    public.get_my_role() = 'tecnico'
    AND tecnico_id = auth.uid()
  );

-- INSERT: admin y encargado pueden crear tickets
CREATE POLICY "tickets_insert_admin_encargado"
  ON public.tickets FOR INSERT TO authenticated
  WITH CHECK (public.get_my_role() IN ('administrador','encargado'));

-- UPDATE admin: puede actualizar todo incluyendo cerrar
CREATE POLICY "tickets_update_admin"
  ON public.tickets FOR UPDATE TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- UPDATE encargado: solo sus tickets, solo campos de desperfecto, no puede cerrar
CREATE POLICY "tickets_update_encargado"
  ON public.tickets FOR UPDATE TO authenticated
  USING (
    public.get_my_role() = 'encargado'
    AND creado_por = auth.uid()
    AND estado NOT IN ('cerrado')
  )
  WITH CHECK (
    public.get_my_role() = 'encargado'
    AND creado_por = auth.uid()
    AND estado NOT IN ('cerrado','asignado','en_ejecucion','en_espera')
  );

-- UPDATE técnico: solo sus tickets asignados, solo estado y observacion, no puede cerrar
CREATE POLICY "tickets_update_tecnico"
  ON public.tickets FOR UPDATE TO authenticated
  USING (
    public.get_my_role() = 'tecnico'
    AND tecnico_id = auth.uid()
    AND estado NOT IN ('cerrado','abierto')
  )
  WITH CHECK (
    public.get_my_role() = 'tecnico'
    AND tecnico_id = auth.uid()
    AND estado IN ('en_ejecucion','en_espera')
  );

-- DELETE: solo admin
CREATE POLICY "tickets_delete_admin"
  ON public.tickets FOR DELETE TO authenticated
  USING (public.get_my_role() = 'administrador');

-- ── TICKET_HISTORIAL ──────────────────────────────────────────
CREATE POLICY "historial_select_admin_encargado"
  ON public.ticket_historial FOR SELECT TO authenticated
  USING (public.get_my_role() IN ('administrador','encargado'));

CREATE POLICY "historial_select_tecnico"
  ON public.ticket_historial FOR SELECT TO authenticated
  USING (
    public.get_my_role() = 'tecnico'
    AND ticket_id IN (
      SELECT id FROM public.tickets WHERE tecnico_id = auth.uid()
    )
  );

CREATE POLICY "historial_insert_autenticado"
  ON public.ticket_historial FOR INSERT TO authenticated
  WITH CHECK (usuario_id = auth.uid());

CREATE POLICY "historial_admin_update_delete"
  ON public.ticket_historial FOR DELETE TO authenticated
  USING (public.get_my_role() = 'administrador');

-- ── INGRESO_REPUESTOS ─────────────────────────────────────────
CREATE POLICY "ingresos_select_admin_encargado"
  ON public.ingreso_repuestos FOR SELECT TO authenticated
  USING (public.get_my_role() IN ('administrador','encargado'));

CREATE POLICY "ingresos_admin_full"
  ON public.ingreso_repuestos FOR ALL TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- ── SALIDA_REPUESTOS ──────────────────────────────────────────
CREATE POLICY "salidas_select_admin_encargado"
  ON public.salida_repuestos FOR SELECT TO authenticated
  USING (public.get_my_role() IN ('administrador','encargado'));

CREATE POLICY "salidas_select_tecnico"
  ON public.salida_repuestos FOR SELECT TO authenticated
  USING (
    public.get_my_role() = 'tecnico'
    AND ticket_id IN (
      SELECT id FROM public.tickets WHERE tecnico_id = auth.uid()
    )
  );

CREATE POLICY "salidas_admin_full"
  ON public.salida_repuestos FOR ALL TO authenticated
  USING (public.get_my_role() = 'administrador')
  WITH CHECK (public.get_my_role() = 'administrador');

-- ============================================================
-- ÍNDICES para consultas frecuentes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_usuarios_rol_id         ON public.usuarios(rol_id);
CREATE INDEX IF NOT EXISTS idx_maquinas_sector_id      ON public.maquinas(sector_id);
CREATE INDEX IF NOT EXISTS idx_tickets_estado          ON public.tickets(estado);
CREATE INDEX IF NOT EXISTS idx_tickets_tecnico_id      ON public.tickets(tecnico_id);
CREATE INDEX IF NOT EXISTS idx_tickets_creado_por      ON public.tickets(creado_por);
CREATE INDEX IF NOT EXISTS idx_ticket_historial_ticket ON public.ticket_historial(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ingreso_repuesto_id     ON public.ingreso_repuestos(repuesto_id);
CREATE INDEX IF NOT EXISTS idx_salida_repuesto_id      ON public.salida_repuestos(repuesto_id);
CREATE INDEX IF NOT EXISTS idx_salida_ticket_id        ON public.salida_repuestos(ticket_id);
CREATE INDEX IF NOT EXISTS idx_encargado_usuario       ON public.encargado_sector(usuario_id);
CREATE INDEX IF NOT EXISTS idx_encargado_sector        ON public.encargado_sector(sector_id);

-- ============================================================
-- DATOS INICIALES DE PRUEBA
-- ============================================================

-- Sectores
INSERT INTO public.sectores (nombre, descripcion) VALUES
  ('Panaderia',  'Sector de producción de panificados'),
  ('Fresco',     'Sector de productos frescos y refrigerados'),
  ('Congelados', 'Sector de productos congelados')
ON CONFLICT (nombre) DO NOTHING;

-- Repuestos de ejemplo
INSERT INTO public.repuestos (codigo, descripcion, stock_actual, stock_minimo, ubicacion) VALUES
  ('REP-001', 'Rodamiento 6205 2RS',       15, 5,  'Estante A1'),
  ('REP-002', 'Correa dentada 3M-300',      8, 3,  'Estante A2'),
  ('REP-003', 'Filtro de aceite OF-123',   20, 8,  'Estante B1'),
  ('REP-004', 'Sello mecanico 25mm',        4, 2,  'Estante B2'),
  ('REP-005', 'Fusible NH 100A',           30, 10, 'Gabinete C1'),
  ('REP-006', 'Valvula solenoide 24V',      2, 3,  'Estante C2'),
  ('REP-007', 'Cadena transmision 1/2',     6, 2,  'Estante A3')
ON CONFLICT (codigo) DO NOTHING;

-- ============================================================
-- USUARIO ADMINISTRADOR INICIAL
-- Crear en Supabase Auth → Authentication → Users:
--   Email:    admin@tecnoflow3.com
--   Password: Admin1234!
-- Luego ejecutar:
-- UPDATE public.usuarios
--   SET rol_id = (SELECT id FROM public.roles WHERE nombre = 'administrador')
--   WHERE email = 'admin@tecnoflow3.com';
-- ============================================================

-- FIN DEL SCRIPT
