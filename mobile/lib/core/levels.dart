// Level helpers for IndoFish (50 points per level, tiers of 3 levels).
const pointsPerLevel = 50;
const maxLevel = 30;

const tierNames = [
  'Pemula',
  'Pemburu',
  'Pawang',
  'Penakluk',
  'Jawara',
  'Pakar',
  'Juara',
  'Ksatria',
  'Legenda',
  'Raja',
];

int levelFromPoints(int points) {
  if (points < 0) points = 0;
  final lv = points ~/ pointsPerLevel + 1;
  if (lv > maxLevel) return maxLevel;
  if (lv < 1) return 1;
  return lv;
}

({int tier, String name}) tierFromLevel(int level) {
  var lv = level;
  if (lv < 1) lv = 1;
  if (lv > maxLevel) lv = maxLevel;
  final tier = (lv - 1) ~/ 3 + 1;
  final t = tier > 10 ? 10 : tier;
  return (tier: t, name: tierNames[t - 1]);
}

int pointsToNext(int points) {
  final level = levelFromPoints(points);
  if (level >= maxLevel) return 0;
  return pointsPerLevel - (points % pointsPerLevel);
}
