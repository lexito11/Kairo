/// Reemplaza con tus credenciales de Supabase Dashboard → Project Settings → API
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eothxnrkckqczjpabbeo.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_GntLeWZFXyrt3Zmk8ksu8w_A_8Kwcld',
  );
}
