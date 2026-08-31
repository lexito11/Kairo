/// Medidas de layout compartidas para que el editor coincida con el feed.
abstract final class KairoLayout {
  /// Recuadro de la imagen dentro de la tarjeta del feed (no la tarjeta completa).
  static const feedImageAspectRatio = 4 / 5;

  static const feedImageExportWidth = 1080.0;
  static const feedImageExportHeight = 1350.0;

  /// Columna del versículo: crece hacia abajo y se frena al borde de la imagen.
  static const verseColumnWidth = 0.86;
  static const verseColumnTop = 0.06;
  static const verseColumnBottom = 0.10;
}
