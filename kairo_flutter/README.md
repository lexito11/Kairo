# KAIRO Flutter (iOS · Android · Web)

Cliente multiplataforma conectado a **Supabase Auth** (Email/Password).

## Estructura de carpetas

```
lib/
├── main.dart
├── app.dart                          # GoRouter + tema
├── core/
│   ├── config/supabase_config.dart   # URL y anon key
│   └── theme/kairo_colors.dart       # Colores = tailwind web
└── features/
    ├── auth/
    │   ├── services/auth_service.dart
    │   ├── views/signin_view.dart
    │   ├── views/signup_view.dart
    │   └── widgets/                  # Logo, inputs, alertas, botón
    └── feed/
        └── views/feed_placeholder_view.dart
```

## Configuración

1. Ejecuta el SQL en Supabase: `../supabase/migrations/001_kairo_auth_and_schema.sql`
2. En Supabase → Authentication → Providers → activa **Email**
3. Edita `lib/core/config/supabase_config.dart` o usa:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## Comandos

```bash
cd kairo_flutter
flutter pub get
flutter run -d chrome      # Web
flutter run                # Android (emulador/dispositivo)
```

## Flujo auth (igual que la web)

| Acción | Flutter | Web (actual) |
|--------|---------|--------------|
| Login | `signInWithPassword` | NextAuth credentials |
| Registro | `signUp` + metadata | POST `/api/auth/signup` |
| Éxito registro | `/auth/signin?registered=true` | Mismo query param |
| Tras login | `/feed` | `/feed` |
