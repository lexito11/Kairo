/// Reemplaza con tus credenciales de Supabase Dashboard → Project Settings → API
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://TU_PROYECTO.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'TU_ANON_KEY',
  );
}
