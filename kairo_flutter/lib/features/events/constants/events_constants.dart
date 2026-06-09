import 'package:flutter/material.dart';

const denominationNames = <String, String>{
  'bautista': 'Bautista',
  'pentecostal': 'Pentecostal',
  'presbiteriano': 'Presbiteriano',
  'metodista': 'Metodista',
  'luterano': 'Luterano',
  'anglicano': 'Anglicano',
  'catolico': 'Católico',
  'otra': 'Otra',
};

const christianEventTypes = [
  'Cultos',
  'Estudios Bíblicos',
  'Conferencias',
  'Retiros',
  'Alabanza',
  'Bautismos',
];

const christianDenominationCategories = [
  'Pentecostal',
  'Bautista',
  'Evangélica',
  'No denominacional',
  'Carismática',
  'Asambleas de Dios',
  'Iglesia de Dios',
  'Cristiana Misionera',
];

const denominationOptions = [
  (id: 'bautista', name: 'Bautista', color: Color(0xFF0EA5E9)),
  (id: 'pentecostal', name: 'Pentecostal', color: Color(0xFFEF4444)),
  (id: 'presbiteriano', name: 'Presbiteriano', color: Color(0xFF22C55E)),
  (id: 'metodista', name: 'Metodista', color: Color(0xFF3B82F6)),
  (id: 'luterano', name: 'Luterano', color: Color(0xFFA855F7)),
  (id: 'anglicano', name: 'Anglicano', color: Color(0xFFEAB308)),
  (id: 'catolico', name: 'Católico', color: Color(0xFF6366F1)),
  (id: 'otra', name: 'Otra', color: Color(0xFF6B7280)),
];

const filterDenominationColors = [
  Color(0xFF06B6D4),
  Color(0xFFEF4444),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFFA855F7),
  Color(0xFF10B981),
  Color(0xFFEC4899),
  Color(0xFF6366F1),
];

const monthAbbreviations = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];

Color categoryColor(String category) {
  switch (category) {
    case 'Conferencia':
      return const Color(0xFFFBBF24);
    case 'Jóvenes':
      return const Color(0xFF34D399);
    case 'Matrimonios':
    case 'Casados':
      return const Color(0xFFF472B6);
    default:
      return const Color(0xFF38BDF8);
  }
}

Color categoryBgColor(String category) {
  return categoryColor(category).withValues(alpha: 0.2);
}
