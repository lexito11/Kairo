/// Claves públicas de cliente (no uses la Secret Key de Unsplash).
/// Pásalas al correr la app:
/// `--dart-define=UNSPLASH_ACCESS_KEY=...` o `--dart-define=PEXELS_API_KEY=...`
abstract final class ImageApiConfig {
  static const unsplashAccessKey = String.fromEnvironment(
    'UNSPLASH_ACCESS_KEY',
    defaultValue: '',
  );

  static const pexelsApiKey = String.fromEnvironment(
    'PEXELS_API_KEY',
    defaultValue: '',
  );

  static bool get hasUnsplash => unsplashAccessKey.isNotEmpty;
  static bool get hasPexels => pexelsApiKey.isNotEmpty;
}
