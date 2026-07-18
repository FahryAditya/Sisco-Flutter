import 'package:flutter/material.dart';

class AppVersion {
  static const String label = 'V20.5.0 (Tiramisu)';
  static const String name = 'SISCO';
}

class ExpHelper {
  static const int expPerAbsen = 10;
  static const int expPenalty = -10;
  static const int expStreak3 = 15;
  static const int expStreak5 = 30;

  static int maxExpForLevel(int level) {
    return level * 100;
  }

  static double expPercentage(int exp, int level) {
    final max = maxExpForLevel(level);
    if (max == 0) return 0;
    return exp / max;
  }

  static LevelUpResult calculateLevelUp(int currentExp, int currentLevel, int addedExp) {
    int newExp = currentExp + addedExp;
    int newLevel = currentLevel;
    while (newExp >= maxExpForLevel(newLevel)) {
      newExp -= maxExpForLevel(newLevel);
      newLevel++;
    }
    return LevelUpResult(
      exp: newExp,
      level: newLevel,
      didLevelUp: newLevel > currentLevel,
      newLevelCount: newLevel - currentLevel,
    );
  }

  static String getLevelBadge(int level) {
    if (level >= 50) return 'legendary';
    if (level >= 30) return 'epic';
    if (level >= 20) return 'rare';
    if (level >= 10) return 'uncommon';
    return 'common';
  }

  static IconData getLevelBadgeIcon(int level) {
    final badge = getLevelBadge(level);
    switch (badge) {
      case 'legendary': return Icons.auto_awesome;
      case 'epic': return Icons.diamond;
      case 'rare': return Icons.star;
      case 'uncommon': return Icons.circle;
      default: return Icons.circle_outlined;
    }
  }

  static String getProgressText(int exp, int level) {
    final max = maxExpForLevel(level);
    final percent = (exp / max * 100).toInt();
    return '$exp/$max ($percent%)';
  }
}

class LevelUpResult {
  final int exp;
  final int level;
  final bool didLevelUp;
  final int newLevelCount;

  LevelUpResult({
    required this.exp,
    required this.level,
    required this.didLevelUp,
    this.newLevelCount = 0,
  });
}
