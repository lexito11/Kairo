# KAIRO — Red Social Cristiana

Aplicación multiplataforma construida con **Flutter** y **Supabase**.

## Plataformas

Android · iOS · Web · Windows · macOS · Linux

## Inicio rápido

```bash
cd kairo_flutter
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

## Supabase

1. Crea un proyecto en [supabase.com](https://supabase.com)
2. Ejecuta en SQL Editor **un solo archivo** (recomendado):

   **`supabase/kairo_complete_schema.sql`**

   O, si prefieres por partes (en orden):

   - `supabase/migrations/001_kairo_auth_and_schema.sql`
   - `supabase/migrations/002_rls_storage_grants.sql`
   - `supabase/migrations/003_events_intercessions_mood.sql`
3. Activa **Email/Password** en Authentication → Providers
4. Configura las credenciales en `kairo_flutter/lib/core/config/supabase_config.dart` o vía `--dart-define`

## Estructura

```
kairo_flutter/lib/
├── core/          # tema, modelos, widgets compartidos
├── features/      # auth, feed, profile, videos, chat, etc.
└── app.dart       # router y providers
```

## Comandos útiles

```bash
flutter analyze
flutter test
flutter run -d windows
flutter build apk
```
