# Tecnoflow3 — Flutter + Supabase + RLS

Control de stock de repuestos para taller de mantenimiento de planta de alimentos.

## Stack
- **Flutter / Dart** — Android + Web
- **Supabase** — PostgreSQL + Auth + RLS
- **Riverpod** — manejo de estado
- **go_router** — navegación

## Roles
| Rol | Permisos principales |
|---|---|
| Administrador | CRUD completo, asigna técnicos, cierra tickets |
| Encargado | Crea tickets, ve todos, edita los propios |
| Técnico | Ve sus tickets asignados, cambia estado, ve stock |

## Estructura
```
lib/
├── core/           → constants, theme, router, widgets
├── models/         → modelos de datos
├── repositories/   → lógica Supabase
├── providers/      → Riverpod providers
└── screens/
    ├── login/
    ├── home/
    ├── usuarios/
    ├── sectores/
    ├── maquinas/
    ├── repuestos/
    ├── tickets/
    └── movimientos/
```

## Setup

### 1. Supabase
- Ejecutar `tecnoflow3_supabase.sql` en SQL Editor
- Crear usuario admin en Authentication → Users
- Ejecutar UPDATE para promover a administrador

### 2. Flutter
- Editar `lib/core/constants.dart` con URL y AnonKey
- Agregar permisos de internet en `AndroidManifest.xml`

```bash
flutter pub get
flutter run                    # Android
flutter run -d chrome          # Web
```

### 3. Habilitar Web (opcional)
```bash
flutter create --platforms=web .
flutter run -d chrome
```

## Credenciales iniciales
- Email: `admin@tecnoflow3.com`
- Password: `Admin1234!`

## Ciclo de vida del ticket
```
ABIERTO (encargado)
  → ASIGNADO (admin asigna técnico)
    → EN EJECUCION (técnico)
      ↔ EN ESPERA (técnico)
        → CERRADO (solo admin)
```
