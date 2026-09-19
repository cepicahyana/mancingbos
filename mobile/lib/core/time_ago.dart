String formatPostTime(String raw, {DateTime? now}) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) {
    if (raw.length > 16) return raw.substring(0, 16).replaceFirst('T', ' ');
    return raw;
  }
  final n = now ?? DateTime.now();
  final local = dt.isUtc ? dt.toLocal() : dt;
  var diff = n.difference(local);
  if (diff.isNegative) diff = Duration.zero;

  if (diff.inDays >= 1) {
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} $h:$min';
  }

  final hours = diff.inHours;
  final minutes = diff.inMinutes.remainder(60);
  final seconds = diff.inSeconds.remainder(60);
  final parts = <String>[];
  if (hours > 0) parts.add('$hours jam');
  if (minutes > 0) parts.add('$minutes menit');
  if (seconds > 0 || parts.isEmpty) parts.add('$seconds detik');
  return '${parts.join(' ')} yang lalu';
}

/// Compact relative time for comment rows (Instagram-style).
String formatCommentTime(String raw, {DateTime? now}) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return '';
  final n = now ?? DateTime.now();
  final local = dt.isUtc ? dt.toLocal() : dt;
  var diff = n.difference(local);
  if (diff.isNegative) diff = Duration.zero;
  if (diff.inDays >= 7) {
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
  if (diff.inDays >= 1) return '${diff.inDays}h';
  if (diff.inHours >= 1) return '${diff.inHours} jam';
  if (diff.inMinutes >= 1) return '${diff.inMinutes} mnt';
  return '${diff.inSeconds} dtk';
}
