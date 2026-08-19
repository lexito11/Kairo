/// Valores de [estado_verificacion] en base de datos (español).
abstract final class EstadoVerificacion {
  static const pendiente = 'pendiente';
  static const activo = 'activo';
  static const rechazado = 'rechazado';

  static String normalize(String? value) {
    if (value == null || value.isEmpty) return pendiente;
    switch (value) {
      case pendiente:
      case activo:
      case rechazado:
        return value;
      case 'pending':
        return pendiente;
      case 'active':
        return activo;
      case 'rejected':
        return rechazado;
      default:
        return pendiente;
    }
  }

  static bool isPendiente(String? value) => normalize(value) == pendiente;
  static bool isActivo(String? value) => normalize(value) == activo;
  static bool isRechazado(String? value) => normalize(value) == rechazado;
}
