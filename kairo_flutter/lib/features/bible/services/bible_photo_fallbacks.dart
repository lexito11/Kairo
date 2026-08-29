import '../models/bible_photo.dart';

/// Fondos de respaldo (Unsplash CDN) si la API no está configurada o falla.
abstract final class BiblePhotoFallbacks {
  static List<BiblePhoto> forCategory(BiblePhotoCategory category) {
    return switch (category) {
      BiblePhotoCategory.nature => _nature,
      BiblePhotoCategory.sky => _sky,
      BiblePhotoCategory.mountains => _mountains,
      BiblePhotoCategory.abstractArt => _abstract,
      BiblePhotoCategory.landscapes => _landscapes,
    };
  }

  static const _nature = [
    BiblePhoto(
      id: 'nature-1',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'nature-2',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'nature-3',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1502082553048-f009c37129b9?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1502082553048-f009c37129b9?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'nature-4',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'nature-5',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1511497584788-876760111969?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1511497584788-876760111969?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'nature-6',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1426604966848-d7adac402bff?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1426604966848-d7adac402bff?auto=format&fit=crop&w=1400&q=80',
    ),
  ];

  static const _sky = [
    BiblePhoto(
      id: 'sky-1',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'sky-2',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1499346030926-9a72daac6c63?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1499346030926-9a72daac6c63?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'sky-3',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'sky-4',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1534088568595-a066f410bcda?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1534088568595-a066f410bcda?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'sky-5',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'sky-6',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1400&q=80',
    ),
  ];

  static const _mountains = [
    BiblePhoto(
      id: 'mnt-1',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'mnt-2',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'mnt-3',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'mnt-4',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'mnt-5',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'mnt-6',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1454496522488-7a6e326e92d6?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1454496522488-7a6e326e92d6?auto=format&fit=crop&w=1400&q=80',
    ),
  ];

  static const _abstract = [
    BiblePhoto(
      id: 'abs-1',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'abs-2',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'abs-3',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1557672172-298e090bd0f1?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1557672172-298e090bd0f1?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'abs-4',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1558591710-4b4a1ae0f04d?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1558591710-4b4a1ae0f04d?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'abs-5',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1506259091721-347e791bab0f?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1506259091721-347e791bab0f?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'abs-6',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1541701494587-cb58502866d4?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1541701494587-cb58502866d4?auto=format&fit=crop&w=1400&q=80',
    ),
  ];

  static const _landscapes = [
    BiblePhoto(
      id: 'land-1',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'land-2',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1439066615861-d1af74d74000?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1439066615861-d1af74d74000?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'land-3',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1509316785289-025f5b846b35?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1509316785289-025f5b846b35?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'land-4',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'land-5',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1400&q=80',
    ),
    BiblePhoto(
      id: 'land-6',
      photographer: 'Unsplash',
      thumbUrl: 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=400&q=60',
      fullUrl: 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1400&q=80',
    ),
  ];
}
