import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Compact level/tier chip + progress toward next level.
class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.level,
    required this.tierName,
    required this.points,
    this.pointsToNext = 50,
    this.compact = false,
  });

  final int level;
  final String tierName;
  final int points;
  final int pointsToNext;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Lv.$level · $tierName',
          style: const TextStyle(
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
    }

    final progress = pointsToNext <= 0 ? 1.0 : (50 - pointsToNext).clamp(0, 50) / 50.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1FA86A), AppTheme.header]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lv.$level',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tierName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.ink),
              ),
            ),
            Text(
              '$points pts',
              style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFEEF3F0),
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          pointsToNext <= 0 ? 'Level maksimal' : '$pointsToNext poin lagi ke level berikutnya',
          style: const TextStyle(color: AppTheme.secondary, fontSize: 11),
        ),
      ],
    );
  }
}
