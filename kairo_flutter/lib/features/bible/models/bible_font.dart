import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BibleFont {
  const BibleFont({required this.id, required this.label});

  final String id;
  final String label;
}

abstract final class BibleFonts {
  static const defaultId = 'sans';

  static const all = [
    BibleFont(id: 'sans', label: 'SYSTEM'),
    BibleFont(id: 'serif', label: 'Serif'),
    BibleFont(id: 'classic', label: 'Clásica'),
    BibleFont(id: 'script', label: 'Script'),
    BibleFont(id: 'bold', label: 'Negrita'),
    BibleFont(id: 'modern', label: 'Moderna'),
    BibleFont(id: 'hand', label: 'Manuscrita'),
    BibleFont(id: 'condensed', label: 'Impacto'),
    BibleFont(id: 'elegant', label: 'Elegante'),
    BibleFont(id: 'lora', label: 'Lora'),
    BibleFont(id: 'cinzel', label: 'Cinzel'),
    BibleFont(id: 'merriweather', label: 'Merri'),
    BibleFont(id: 'pacifico', label: 'Pacifico'),
    BibleFont(id: 'anton', label: 'Anton'),
    BibleFont(id: 'raleway', label: 'Raleway'),
    BibleFont(id: 'crimson', label: 'Crimson'),
    BibleFont(id: 'josefin', label: 'Josefin'),
    BibleFont(id: 'abril', label: 'Abril'),
    BibleFont(id: 'caveat', label: 'Caveat'),
  ];

  static BibleFont byId(String id) {
    return all.firstWhere((f) => f.id == id, orElse: () => all.first);
  }

  static TextStyle textStyle({
    required String fontId,
    required Color color,
    required double fontSize,
    FontStyle? fontStyle,
    FontWeight weight = FontWeight.w600,
  }) {
    return switch (fontId) {
      'serif' => GoogleFonts.playfairDisplay(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'classic' => GoogleFonts.ebGaramond(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'script' => GoogleFonts.greatVibes(color: color, fontSize: fontSize, fontWeight: FontWeight.w400, fontStyle: fontStyle),
      'bold' => GoogleFonts.oswald(color: color, fontSize: fontSize, fontWeight: FontWeight.w700, fontStyle: fontStyle),
      'modern' => GoogleFonts.montserrat(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'hand' => GoogleFonts.satisfy(color: color, fontSize: fontSize, fontWeight: FontWeight.w400, fontStyle: fontStyle),
      'condensed' => GoogleFonts.bebasNeue(color: color, fontSize: fontSize, fontWeight: FontWeight.w400, fontStyle: fontStyle),
      'elegant' => GoogleFonts.cormorantGaramond(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'lora' => GoogleFonts.lora(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'cinzel' => GoogleFonts.cinzel(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'merriweather' => GoogleFonts.merriweather(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'pacifico' => GoogleFonts.pacifico(color: color, fontSize: fontSize, fontWeight: FontWeight.w400, fontStyle: fontStyle),
      'anton' => GoogleFonts.anton(color: color, fontSize: fontSize, fontWeight: FontWeight.w400, fontStyle: fontStyle),
      'raleway' => GoogleFonts.raleway(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'crimson' => GoogleFonts.crimsonText(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'josefin' => GoogleFonts.josefinSans(color: color, fontSize: fontSize, fontWeight: weight, fontStyle: fontStyle),
      'abril' => GoogleFonts.abrilFatface(color: color, fontSize: fontSize, fontWeight: FontWeight.w400, fontStyle: fontStyle),
      'caveat' => GoogleFonts.caveat(color: color, fontSize: fontSize, fontWeight: FontWeight.w500, fontStyle: fontStyle),
      _ => GoogleFonts.roboto(color: color, fontSize: fontSize, fontWeight: FontWeight.w700, fontStyle: fontStyle),
    };
  }
}
