class UsernamePolicy {
  static const minLength = 3;
  static const maxLength = 20;
  static const cooldownMonths = 6;

  static String sanitize(String raw) {
    var value = raw.trim();
    if (value.startsWith('@')) value = value.substring(1);
    value = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (value.length > maxLength) value = value.substring(0, maxLength);
    return value;
  }

  static String seedFromEmail(String email) {
    final local = email.contains('@') ? email.split('@').first : email;
    var clean = sanitize(local);
    if (clean.length < minLength) clean = 'user$clean';
    if (clean.length < minLength) clean = 'user';
    if (clean.length > 16) clean = clean.substring(0, 16);
    return clean;
  }

  static String? validate(String username) {
    if (username.length < minLength || username.length > maxLength) {
      return 'El usuario debe tener entre $minLength y $maxLength caracteres (letras, números o _)';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return 'Solo letras, números y _';
    }
    return null;
  }

  static DateTime nextChangeAvailable(DateTime lastChangedAt) {
    final local = lastChangedAt.toLocal();
    return DateTime(local.year, local.month + cooldownMonths, local.day);
  }

  static bool canChange(DateTime? lastChangedAt) {
    if (lastChangedAt == null) return true;
    return !DateTime.now().isBefore(nextChangeAvailable(lastChangedAt));
  }

  static String formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  static String cooldownMessage(DateTime lastChangedAt) {
    return 'El usuario se cambia una sola vez cada 6 meses. '
        'Podrás cambiarlo el ${formatDate(nextChangeAvailable(lastChangedAt))}.';
  }
}
