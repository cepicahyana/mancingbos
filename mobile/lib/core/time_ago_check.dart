// ponytail: tiny self-check for relative time formatting
import 'time_ago.dart';

void main() {
  final now = DateTime(2026, 9, 19, 12, 0, 0);

  assert(formatPostTime(now.subtract(const Duration(hours: 1, seconds: 20)).toIso8601String(), now: now) ==
      '1 jam 20 detik yang lalu');
  assert(formatPostTime(now.subtract(const Duration(minutes: 5, seconds: 12)).toIso8601String(), now: now) ==
      '5 menit 12 detik yang lalu');
  assert(formatPostTime(now.subtract(const Duration(hours: 25)).toIso8601String(), now: now) ==
      '18/09/2026 11:00');
  assert(formatPostTime(now.subtract(const Duration(seconds: 3)).toIso8601String(), now: now) ==
      '3 detik yang lalu');

  assert(formatCommentTime(now.subtract(const Duration(hours: 4)).toIso8601String(), now: now) == '4 jam');
  assert(formatCommentTime(now.subtract(const Duration(days: 2)).toIso8601String(), now: now) == '2h');

  // ignore: avoid_print
  print('time_ago ok');
}
