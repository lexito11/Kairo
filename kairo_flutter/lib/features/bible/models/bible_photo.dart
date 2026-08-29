enum BiblePhotoCategory {
  nature('Naturaleza', 'nature forest greenery'),
  sky('Cielo', 'sky clouds sunset heaven'),
  mountains('Montañas', 'mountains alpine peak snow'),
  abstractArt('Abstracto', 'abstract texture bokeh light'),
  landscapes('Paisajes', 'landscape scenery valley panorama');

  const BiblePhotoCategory(this.label, this.query);

  final String label;
  final String query;
}

class BiblePhoto {
  const BiblePhoto({
    required this.id,
    required this.thumbUrl,
    required this.fullUrl,
    required this.photographer,
    this.downloadLocation,
    this.source = 'unsplash',
  });

  final String id;
  final String thumbUrl;
  final String fullUrl;
  final String photographer;
  final String? downloadLocation;
  final String source;
}
