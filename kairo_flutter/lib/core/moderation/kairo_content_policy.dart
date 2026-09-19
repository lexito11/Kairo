import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Global KAIRO content policy. All modules must use this — do not copy lists.
class KairoContentPolicy {
  KairoContentPolicy._();

  static const userMessage =
      'Este contenido no cumple las normas de KAIRO.';

  static const allowedImageMimes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  };

  static const allowedVideoMimes = {
    'video/mp4',
    'video/quicktime',
    'video/webm',
  };

  static final _accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', '@': 'a', '0': 'o', '1': 'i', '3': 'e',
    '4': 'a', '5': 's', '\$': 's', '!': 'i',
  };

  static final _sexualCompact = [
    'porn', 'porno', 'nopor', 'xxx', 'onlyfans', 'fansly', 'nsfw', 'hentai',
    'nudes', 'nude', 'nudity', 'naked', 'desnudo', 'desnuda', 'desnudos',
    'bikini', 'lenceria', 'ropainterior', 'underwear', 'sexting',
    'sexualizado', 'sexualizada', 'pornhub', 'xvideos', 'xnxx',
    'chaturbate', 'stripchat', 'packxxx',
  ];

  static final _sexualPhrases = [
    RegExp(r'\bcontenido sexual\b'),
    RegExp(r'\bropa interior\b'),
    RegExp(r'\bpack (de )?fotos\b'),
    RegExp(r'\bservicios? sexual(es)?\b'),
    RegExp(r'\bpromoci[oó]n (de )?(onlyfans|fansly|porn)\b'),
  ];

  static final _threats = [
    RegExp(r'\bte voy a (matar|pegar|golpear|violar|disparar|encontrar)\b'),
    RegExp(r'\bte (mato|matoo|pego|violo)\b'),
    RegExp(r'\bte voy a hacer dano\b'),
    RegExp(r'\bamenazo a\b'),
  ];

  static final _severeDirected = [
    RegExp(r'\b(eres|sos|usted es) (una? )?(puta|puto|perra|malparid[oa]|hij[oa] de puta)\b'),
    RegExp(r'\b(maldit[oa]|asqueros[oa]) (puta|puto|perra)\b'),
    RegExp(r'\bhij[oa] de (puta|perra)\b'),
    RegExp(r'\bmal nacido\b'),
    RegExp(r'\bmalnacido\b'),
  ];

  static final _discriminationDirected = [
    RegExp(r'\b(negro|negra|indio|india|moreno|morena) de (mierda|porqueria|mierda)\b'),
    RegExp(r'\b(maldit[oa]|asqueros[oa]|odio a los|odio a las) (negros?|negras?|indios?|indias?)\b'),
    RegExp(r'\b(eres|sos) un mono\b'),
    RegExp(r'\besos (negros|indios) (no|son)\b'),
  ];

  static final _harassment = [
    RegExp(r'\ben todas tus (publicaciones|fotos|historias|comentarios)\b'),
    RegExp(r'\bte voy a (acosar|perseguir|molestar)\b'),
    RegExp(r'\bpara molestarte\b'),
    RegExp(r'\bcuenta (para|pa) acosar\b'),
  ];

  static final _safeColorContext = RegExp(
    r'\b(camisa|fondo|color|pared|auto|coche|zapato|bolso|pelo|tinta|pintura|cafe|carbon|mono en)\b',
  );

  static ({String spaced, String compact}) normalize(String raw) {
    final buf = StringBuffer();
    for (final rune in raw.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buf.write(_accents[ch] ?? ch);
    }
    var spaced = buf.toString().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    spaced = spaced.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (m) => '${m[1]}${m[1]}',
    );
    spaced = spaced.replaceAll(RegExp(r'\s+'), ' ').trim();
    final compact = spaced.replaceAll(' ', '');
    return (spaced: spaced, compact: compact);
  }

  static void assertText(String? raw) {
    final result = evaluateText(raw);
    if (!result.allowed) throw KairoContentBlockedException();
  }

  static KairoModerationResult evaluateText(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return const KairoModerationResult.allowed();

    final n = normalize(text);

    for (final term in _sexualCompact) {
      if (n.compact.contains(term)) {
        return const KairoModerationResult.blocked(KairoModerationCategory.sexual);
      }
    }
    for (final re in _sexualPhrases) {
      if (re.hasMatch(n.spaced)) {
        return const KairoModerationResult.blocked(KairoModerationCategory.sexual);
      }
    }
    for (final re in _threats) {
      if (re.hasMatch(n.spaced)) {
        return const KairoModerationResult.blocked(KairoModerationCategory.threat);
      }
    }
    for (final re in _severeDirected) {
      if (re.hasMatch(n.spaced)) {
        return const KairoModerationResult.blocked(KairoModerationCategory.severeInsult);
      }
    }
    if (!_safeColorContext.hasMatch(n.spaced)) {
      for (final re in _discriminationDirected) {
        if (re.hasMatch(n.spaced)) {
          return const KairoModerationResult.blocked(KairoModerationCategory.discrimination);
        }
      }
    }
    for (final re in _harassment) {
      if (re.hasMatch(n.spaced)) {
        return const KairoModerationResult.blocked(KairoModerationCategory.harassment);
      }
    }

    return const KairoModerationResult.allowed();
  }

  static void assertMedia({
    required Uint8List bytes,
    required String mimeType,
    String fileName = '',
  }) {
    if (bytes.isEmpty) throw KairoMediaRejectedException('El archivo no es válido.');
    final mime = mimeType.toLowerCase().split(';').first.trim();
    final isImage = mime.startsWith('image/') || _hasImageMagic(bytes);
    final isVideo = mime.startsWith('video/');
    if (isImage) {
      if (mime.isNotEmpty && !allowedImageMimes.contains(mime) && !_hasImageMagic(bytes)) {
        throw KairoMediaRejectedException('Solo se permiten imágenes JPG, PNG o WEBP.');
      }
      if (!_hasImageMagic(bytes)) {
        throw KairoMediaRejectedException('El archivo no es una imagen válida.');
      }
    } else if (isVideo) {
      if (mime.isNotEmpty && !allowedVideoMimes.contains(mime)) {
        throw KairoMediaRejectedException('Solo se permiten videos MP4, MOV o WEBM.');
      }
    } else {
      throw KairoMediaRejectedException('Tipo de archivo no permitido.');
    }

    final nameCheck = evaluateText(fileName.replaceAll(RegExp(r'[_\-\.]'), ' '));
    if (!nameCheck.allowed) throw KairoContentBlockedException();
  }

  static bool _hasImageMagic(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    return false;
  }

  /// Future ads must call this with every creative field.
  static void assertAd({
    String? title,
    String? description,
    String? destinationUrl,
    Uint8List? imageBytes,
    String imageMimeType = '',
    String fileName = '',
  }) {
    assertText(title);
    assertText(description);
    assertText(destinationUrl?.replaceAll(RegExp(r'[/:._\-?&=]'), ' '));
    if (imageBytes != null) {
      assertMedia(bytes: imageBytes, mimeType: imageMimeType, fileName: fileName);
    }
  }

  static void throwIfBlocked(Object error) {
    if (error is PostgrestException) {
      if (error.message.contains('account_blocked')) {
        throw const KairoAccountBlockedException();
      }
      if (error.message.contains('blocked_content') || error.code == 'P0001') {
        throw KairoContentBlockedException();
      }
    }
  }
}

enum KairoModerationCategory {
  sexual,
  threat,
  severeInsult,
  discrimination,
  harassment,
}

class KairoModerationResult {
  const KairoModerationResult._(this.allowed, this.category);
  const KairoModerationResult.allowed() : this._(true, null);
  const KairoModerationResult.blocked(KairoModerationCategory category)
      : this._(false, category);

  final bool allowed;
  final KairoModerationCategory? category;
}

class KairoContentBlockedException implements Exception {
  @override
  String toString() => KairoContentPolicy.userMessage;
}

class KairoAccountBlockedException implements Exception {
  const KairoAccountBlockedException();

  static const userMessage =
      'Tu cuenta fue bloqueada por alcanzar el límite de infracciones establecido por KAIRO.';

  @override
  String toString() => userMessage;
}

class KairoMediaRejectedException implements Exception {
  KairoMediaRejectedException(this.message);
  final String message;
  @override
  String toString() => message;
}
