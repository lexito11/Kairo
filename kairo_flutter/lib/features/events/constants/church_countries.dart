class ChurchCountry {
  const ChurchCountry({
    required this.code,
    required this.name,
    required this.isSouthAmerica,
  });

  final String code;
  final String name;
  final bool isSouthAmerica;
}

const southAmericaCountryCodes = {
  'AR', 'BO', 'BR', 'CL', 'CO', 'EC', 'GY', 'PY', 'PE', 'SR', 'UY', 'VE',
};

bool isSouthAmericaCountry(String? code) {
  if (code == null || code.isEmpty) return false;
  return southAmericaCountryCodes.contains(code.toUpperCase());
}

/// Países ordenados: Sudamérica primero, luego el resto del mundo.
const churchCountries = <ChurchCountry>[
  ChurchCountry(code: 'AR', name: 'Argentina', isSouthAmerica: true),
  ChurchCountry(code: 'BO', name: 'Bolivia', isSouthAmerica: true),
  ChurchCountry(code: 'BR', name: 'Brasil', isSouthAmerica: true),
  ChurchCountry(code: 'CL', name: 'Chile', isSouthAmerica: true),
  ChurchCountry(code: 'CO', name: 'Colombia', isSouthAmerica: true),
  ChurchCountry(code: 'EC', name: 'Ecuador', isSouthAmerica: true),
  ChurchCountry(code: 'GY', name: 'Guyana', isSouthAmerica: true),
  ChurchCountry(code: 'PY', name: 'Paraguay', isSouthAmerica: true),
  ChurchCountry(code: 'PE', name: 'Perú', isSouthAmerica: true),
  ChurchCountry(code: 'SR', name: 'Surinam', isSouthAmerica: true),
  ChurchCountry(code: 'UY', name: 'Uruguay', isSouthAmerica: true),
  ChurchCountry(code: 'VE', name: 'Venezuela', isSouthAmerica: true),
  ChurchCountry(code: 'MX', name: 'México', isSouthAmerica: false),
  ChurchCountry(code: 'US', name: 'Estados Unidos', isSouthAmerica: false),
  ChurchCountry(code: 'CA', name: 'Canadá', isSouthAmerica: false),
  ChurchCountry(code: 'ES', name: 'España', isSouthAmerica: false),
  ChurchCountry(code: 'PT', name: 'Portugal', isSouthAmerica: false),
  ChurchCountry(code: 'GB', name: 'Reino Unido', isSouthAmerica: false),
  ChurchCountry(code: 'DE', name: 'Alemania', isSouthAmerica: false),
  ChurchCountry(code: 'FR', name: 'Francia', isSouthAmerica: false),
  ChurchCountry(code: 'IT', name: 'Italia', isSouthAmerica: false),
  ChurchCountry(code: 'AU', name: 'Australia', isSouthAmerica: false),
  ChurchCountry(code: 'NZ', name: 'Nueva Zelanda', isSouthAmerica: false),
  ChurchCountry(code: 'JP', name: 'Japón', isSouthAmerica: false),
  ChurchCountry(code: 'KR', name: 'Corea del Sur', isSouthAmerica: false),
  ChurchCountry(code: 'CN', name: 'China', isSouthAmerica: false),
  ChurchCountry(code: 'IN', name: 'India', isSouthAmerica: false),
  ChurchCountry(code: 'ZA', name: 'Sudáfrica', isSouthAmerica: false),
  ChurchCountry(code: 'NG', name: 'Nigeria', isSouthAmerica: false),
  ChurchCountry(code: 'KE', name: 'Kenia', isSouthAmerica: false),
  ChurchCountry(code: 'PH', name: 'Filipinas', isSouthAmerica: false),
  ChurchCountry(code: 'ID', name: 'Indonesia', isSouthAmerica: false),
  ChurchCountry(code: 'OTHER', name: 'Otro país', isSouthAmerica: false),
];

ChurchCountry? churchCountryByCode(String? code) {
  if (code == null || code.isEmpty) return null;
  for (final country in churchCountries) {
    if (country.code == code) return country;
  }
  return null;
}

String fiscalIdLabelForCountry(String? code) {
  switch (code) {
    case 'CO':
      return 'NIT';
    case 'CL':
      return 'RUT';
    case 'MX':
      return 'RFC';
    case 'PE':
    case 'EC':
    case 'BO':
    case 'PY':
    case 'UY':
      return 'RUC';
    case 'AR':
      return 'CUIT';
    case 'BR':
      return 'CNPJ';
    case 'VE':
      return 'RIF';
    default:
      return 'Identificador Fiscal (NIT, RUT, RFC, RUC, etc.)';
  }
}
