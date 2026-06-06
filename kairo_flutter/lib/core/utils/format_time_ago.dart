String formatTimeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'hace un momento';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  if (diff.inDays < 30) return 'hace ${diff.inDays ~/ 7} sem';
  if (diff.inDays < 365) return 'hace ${diff.inDays ~/ 30} mes';
  return 'hace ${diff.inDays ~/ 365} a';
}
