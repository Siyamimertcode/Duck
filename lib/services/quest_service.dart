import 'dart:convert';
import 'package:flutter/services.dart';
import 'user_preferences.dart';

class QuestTask {
  final String id;
  final String title;
  final String description;
  final int target;
  final int xp;
  final bool isDaily;

  QuestTask({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.xp,
    required this.isDaily,
  });

  factory QuestTask.fromJson(
    Map<String, dynamic> json, {
    required bool isDaily,
  }) {
    return QuestTask(
      id: (isDaily ? 'daily_' : 'weekly_') + json['id'].toString(),
      title: json['baslik'] ?? '',
      description: json['aciklama'] ?? '',
      target: json['hedef'] ?? 1,
      xp: json['xp'] ?? 0,
      isDaily: isDaily,
    );
  }
}

class QuestService {
  static List<QuestTask> _dailyTasks = [];
  static List<QuestTask> _weeklyTasks = [];
  static bool _loaded = false;

  static Future<void> loadTasks() async {
    if (_loaded) return;

    try {
      final jsonString = await rootBundle.loadString('json/tasks.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      final gunluk = data['gunlukGorevler'] as List<dynamic>? ?? [];
      final haftalik = data['haftalikGorevler'] as List<dynamic>? ?? [];

      _dailyTasks = gunluk
          .map(
            (e) => QuestTask.fromJson(e as Map<String, dynamic>, isDaily: true),
          )
          .toList();

      _weeklyTasks = haftalik
          .map(
            (e) =>
                QuestTask.fromJson(e as Map<String, dynamic>, isDaily: false),
          )
          .toList();

      _loaded = true;
    } catch (e) {
      print('Error loading tasks.json: $e');
      _dailyTasks = [];
      _weeklyTasks = [];
    }
  }

  // Get sequential daily quests (3 per day, rotating through all tasks)
  static Future<List<QuestTask>> getDailyQuests() async {
    await loadTasks();
    if (_dailyTasks.isEmpty) return [];

    // Check if we have assigned quests for today
    final assignedIds = await UserPreferences.getAssignedDailyQuests();
    if (assignedIds.isNotEmpty) {
      // Return the same quests that were assigned
      final assigned = _dailyTasks
          .where(
            (task) => assignedIds.contains(task.id.replaceFirst('daily_', '')),
          )
          .toList();
      if (assigned.length == 3) {
        return assigned;
      }
    }

    // No assigned quests or incomplete list - generate new ones sequentially
    final counter = await UserPreferences.getDailyQuestCounter();
    final totalTasks = _dailyTasks.length;

    // Select 3 consecutive tasks starting from counter position
    final List<QuestTask> selected = [];
    for (int i = 0; i < 3; i++) {
      final index = (counter + i) % totalTasks;
      selected.add(_dailyTasks[index]);
    }

    // Save the assigned quest IDs
    final ids = selected
        .map((task) => task.id.replaceFirst('daily_', ''))
        .toList();
    await UserPreferences.saveAssignedDailyQuests(ids);

    // Increment counter for next day
    await UserPreferences.incrementDailyQuestCounter(totalTasks);

    return selected;
  }

  // Get sequential weekly quests (3 per week, rotating through all tasks)
  static Future<List<QuestTask>> getWeeklyQuests() async {
    await loadTasks();
    if (_weeklyTasks.isEmpty) return [];

    // Check if we have assigned quests for this week
    final assignedIds = await UserPreferences.getAssignedWeeklyQuests();
    if (assignedIds.isNotEmpty) {
      // Return the same quests that were assigned
      final assigned = _weeklyTasks
          .where(
            (task) => assignedIds.contains(task.id.replaceFirst('weekly_', '')),
          )
          .toList();
      if (assigned.length == 3) {
        return assigned;
      }
    }

    // No assigned quests or incomplete list - generate new ones sequentially
    final counter = await UserPreferences.getWeeklyQuestCounter();
    final totalTasks = _weeklyTasks.length;

    // Select 3 consecutive tasks starting from counter position
    final List<QuestTask> selected = [];
    for (int i = 0; i < 3; i++) {
      final index = (counter + i) % totalTasks;
      selected.add(_weeklyTasks[index]);
    }

    // Save the assigned quest IDs
    final ids = selected
        .map((task) => task.id.replaceFirst('weekly_', ''))
        .toList();
    await UserPreferences.saveAssignedWeeklyQuests(ids);

    // Increment counter for next week
    await UserPreferences.incrementWeeklyQuestCounter(totalTasks);

    return selected;
  }

  // Evaluate quest progress based on task type
  static Future<int> evaluateQuestProgress(QuestTask quest) async {
    final title = quest.title;
    final desc = quest.description;

    // Daily quests - Giriş
    if (title.contains('Giriş Yap') || desc.contains('giriş yap')) {
      return await UserPreferences.getOpensToday();
    }

    // Ders Tamamla tracking
    if (title.contains('Ders Tamamla') ||
        title.contains('Ders') && desc.contains('ders tamamla')) {
      if (quest.isDaily) {
        return await UserPreferences.getExercisesToday();
      } else {
        return await UserPreferences.getExercisesWeek();
      }
    }

    // Mini Oyun tracking (also covers "Oyun Haftası", "Kelime Oyunu", etc.)
    if (title.contains('Mini Oyun') ||
        title.contains('Oyun Haftası') ||
        title.contains('Kelime Oyunu') ||
        desc.contains('mini oyun') ||
        desc.contains('oyun oyna') ||
        desc.contains('oyun tamamla')) {
      if (quest.isDaily) {
        return await UserPreferences.getGamesToday();
      } else {
        return await UserPreferences.getGamesWeek();
      }
    }

    // Alıştırma tracking
    if (title.contains('Alıştırma') || desc.contains('alıştırma')) {
      return await UserPreferences.getExercisesToday();
    }

    // Kelime tracking
    if (title.contains('Kelime Eşleştirme') ||
        desc.contains('kelime eşleştirme')) {
      return await UserPreferences.getGamesToday();
    }

    if (title.contains('Kelime Tekrarı') || desc.contains('kelimeyi tekrar')) {
      return await UserPreferences.getWordReviewsToday();
    }

    // Test tracking
    if (title.contains('Hızlı Test') ||
        title.contains('Test') ||
        desc.contains('test')) {
      return await UserPreferences.getTestsToday();
    }

    // Doğru Seri tracking
    if (title.contains('Doğru Seri') || desc.contains('doğru cevap')) {
      return await UserPreferences.getMaxCorrectStreakToday();
    }

    // Yanlışsız/Hatasız tracking
    if (title.contains('Yanlışsız') ||
        title.contains('Hatasız') ||
        desc.contains('hatasız')) {
      if (quest.isDaily) {
        return await UserPreferences.getErrorFreeTasksToday();
      } else {
        return await UserPreferences.getErrorFreeTasksWeek();
      }
    }

    // Balon Oyunu
    if (title.contains('Balon') || desc.contains('Balon')) {
      return await UserPreferences.getGamesToday();
    }

    // Zaman tracking (dakika) - daily vs weekly
    if (title.contains('Zaman Geçir') || title.contains('Dakika') || desc.contains('dakika geçir') || desc.contains('dakika zaman')) {
      if (quest.isDaily) {
        return await UserPreferences.getMinutesToday();
      } else {
        return await UserPreferences.getMinutesWeek();
      }
    }

    // Günlük Seri (streak)
    if (title.contains('Günlük Seri') || desc.contains('seriyi bozma')) {
      final streak = await UserPreferences.getStreak();
      return streak > 0 ? 1 : 0;
    }

    // XP tracking - daily vs weekly
    if (title.contains('XP Topla') || title.contains('XP Kazan') || title.contains('XP Avcısı') || desc.contains('XP kazan')) {
      if (quest.isDaily) {
        return await UserPreferences.getXPToday();
      } else {
        return await UserPreferences.getXPWeek();
      }
    }

    // Seviye katkısı
    if (title.contains('Seviye Katkısı') ||
        desc.contains('seviye ilerlemesine')) {
      return await UserPreferences.getExercisesToday() > 0 ? 1 : 0;
    }

    // Geri Dönüş
    if (title.contains('Geri Dönüş') || desc.contains('tekrar aç')) {
      return await UserPreferences.getOpensToday();
    }

    // Günlük Tamamlama
    if (title.contains('Günlük Tamamlama') || desc.contains('görev tamamla')) {
      return await UserPreferences.getTasksCompletedToday();
    }

    // Weekly quests - Gün Üst Üste Seri
    if (title.contains('Gün Üst Üste') || title.contains('Günlük Seri') || desc.contains('gün üst üste') || desc.contains('seriyi bozma') || desc.contains('gün boyunca seriyi')) {
      return await UserPreferences.getStreak();
    }

    // Haftalık Mini Oyun (covers "Haftalık Mini Oyun", "40 Mini Oyun Oyna", etc.)
    if (title.contains('Haftalık Mini Oyun') || desc.contains('kere mini oyun') || desc.contains('mini oyun tamamla')) {
      return await UserPreferences.getGamesWeek();
    }

    // Ders Maratonu / Ders haftalık
    if (title.contains('Maratonu') || title.contains('Ders Tamamla') && !quest.isDaily || desc.contains('ders tamamla') && !quest.isDaily) {
      return await UserPreferences.getExercisesWeek();
    }

    // Kelime Ustası
    if (title.contains('Kelime Ustası') || desc.contains('kelime öğren')) {
      return await UserPreferences.getWordsWeek();
    }

    // Hatasız Gün
    if (title.contains('Hatasız Gün')) {
      return await UserPreferences.getErrorFreeTasksWeek();
    }

    // Dinleme Haftası
    if (title.contains('Dinleme') || desc.contains('dinleme')) {
      return await UserPreferences.getListeningWeek();
    }

    // Konuşma Haftası
    if (title.contains('Konuşma') || desc.contains('konuşma')) {
      return await UserPreferences.getSpeakingWeek();
    }

    // Yazma Haftası
    if (title.contains('Yazma') || desc.contains('yazma')) {
      return await UserPreferences.getWritingWeek();
    }

    // Seviye Atlama
    if (title.contains('Seviye Atlama') || desc.contains('seviye atla')) {
      return await UserPreferences.getLevelsWeek();
    }

    // Haftayı Bitir
    if (title.contains('Haftayı Bitir') || desc.contains('görev tamamla') && !quest.isDaily) {
      return await UserPreferences.getTasksCompletedWeek();
    }

    // Fallback: 150 Dakika, 300 Dakika weekly time quests
    if (desc.contains('dakika') && !quest.isDaily) {
      return await UserPreferences.getMinutesWeek();
    }

    return 0;
  }

  // Auto-complete quests if target is reached
  static Future<void> checkAndCompleteQuests(List<QuestTask> quests) async {
    for (final quest in quests) {
      final progress = await evaluateQuestProgress(quest);
      if (progress >= quest.target) {
        await UserPreferences.markQuestCompleted(quest.id);
      }
    }
  }
}
