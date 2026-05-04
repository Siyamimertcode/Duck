import 'dart:convert';
import 'package:flutter/services.dart';
import 'user_preferences.dart';

class Achievement {
  final int id;
  final String title;
  final String description;
  final String condition;
  final int target;
  final int xp;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.condition,
    required this.target,
    required this.xp,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? 0,
      title: json['baslik'] ?? '',
      description: json['aciklama'] ?? '',
      condition: json['kosul'] ?? '',
      target: json['hedef'] ?? 1,
      xp: json['xp'] ?? 0,
    );
  }

  String get idString => 'achievement_$id';
}

class AchievementService {
  static List<Achievement> _achievements = [];
  static bool _loaded = false;

  static Future<void> loadAchievements() async {
    if (_loaded) return;

    try {
      final jsonString = await rootBundle.loadString('json/basari.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      final basarilar = data['basarilar'] as List<dynamic>? ?? [];

      _achievements = basarilar
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();

      _loaded = true;
    } catch (e) {
      print('Error loading basari.json: $e');
      _achievements = [];
    }
  }

  // Get all achievements
  static Future<List<Achievement>> getAllAchievements() async {
    await loadAchievements();
    return _achievements;
  }

  // Get emoji for achievement
  static String getEmojiForCondition(String condition) {
    switch (condition) {
      case 'ilk_giris':
        return '🎉';
      case 'mini_oyun':
        return '🎮';
      case 'ders':
        return '📚';
      case 'hatasiz_mini_oyun':
        return '🏆';
      case 'sure':
        return '⏰';
      case 'gunluk_seri':
        return '🔥';
      case 'xp':
        return '⭐';
      case 'gorev':
        return '✅';
      default:
        return '🏅';
    }
  }

  // Evaluate achievement progress based on condition
  static Future<int> evaluateAchievementProgress(
    Achievement achievement,
  ) async {
    final condition = achievement.condition;

    switch (condition) {
      case 'ilk_giris':
        // Check if user has ever opened the app
        return await UserPreferences.getTotalAppOpens() > 0 ? 1 : 0;

      case 'mini_oyun':
        // Total mini games played
        return await UserPreferences.getTotalGamesPlayed();

      case 'ders':
        // Total lessons completed
        return await UserPreferences.getTotalLessonsCompleted();

      case 'hatasiz_mini_oyun':
        // Total error-free games
        return await UserPreferences.getTotalErrorFreeGames();

      case 'sure':
        // Total minutes spent (converted from minutes)
        return await UserPreferences.getTotalMinutesSpent();

      case 'gunluk_seri':
        // Current streak
        return await UserPreferences.getStreak();

      case 'xp':
        // Total XP earned (not current XP, but lifetime XP)
        return await UserPreferences.getTotalXPEarned();

      case 'gorev':
        // Total quests completed
        return await UserPreferences.getTotalQuestsCompleted();

      default:
        return 0;
    }
  }

  // Check and auto-complete achievements
  static Future<void> checkAndCompleteAchievements() async {
    await loadAchievements();

    for (final achievement in _achievements) {
      final isCompleted = await UserPreferences.isAchievementCompleted(
        achievement.idString,
      );
      if (isCompleted) continue; // Already completed

      final progress = await evaluateAchievementProgress(achievement);
      if (progress >= achievement.target) {
        // Auto-complete and award XP
        await UserPreferences.markAchievementCompleted(achievement.idString);
        await UserPreferences.addXP(achievement.xp);
      }
    }
  }
}
