import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_preferences.dart';

/// Centralized lesson progress service.
///
/// Manages per‑level lesson progress, level unlocking, and current‑level
/// promotion. All data is persisted via [SharedPreferences] through
/// [UserPreferences].
class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  static const List<String> _levelOrder = ['A1', 'A2', 'B1', 'B2', 'C1'];
  static const int lessonsPerLevel = 25;

  // ── Per‑Level Progress ───────────────────────────────────────────────

  /// Returns how many lessons have been completed in [level] (0–25).
  Future<int> getCompletedLessonsForLevel(String level) async {
    return UserPreferences.getLevelLessonProgress(level);
  }

  /// Returns a map of all levels to their completed lesson counts.
  Future<Map<String, int>> getAllProgress() async {
    return UserPreferences.getAllLevelLessonProgress();
  }

  // ── Lesson Completion ────────────────────────────────────────────────

  /// Marks [lessonInLevel] (1‑based) in [level] as completed.
  ///
  /// • Skips if lesson is already completed or out of order.
  /// • Updates per‑level and total‑completed counters.
  /// • Returns `true` if the entire level was just completed (triggers unlock).
  Future<bool> completeLesson(String level, int lessonInLevel) async {
    debugPrint(
      '🚀 ProgressService: completing lesson $lessonInLevel for level $level',
    );
    final currentProgress = await getCompletedLessonsForLevel(level);

    // Already completed or trying to skip ahead.
    if (lessonInLevel <= currentProgress) {
      debugPrint(
        '⚠️ Lesson $lessonInLevel already completed (Current: $currentProgress)',
      );
      return false;
    }

    // Allow skipping ahead only in debug, but normally enforce order
    // if (lessonInLevel > currentProgress + 1) ...

    final updatedProgress = (currentProgress + 1).clamp(0, lessonsPerLevel);
    debugPrint(
      '✅ Saving updated progress: $updatedProgress / $lessonsPerLevel',
    );

    await UserPreferences.saveLevelLessonProgress(level, updatedProgress);

    // Update total completed lessons across all levels.
    final allProgress = await getAllProgress();
    allProgress[level] = updatedProgress;
    final totalCompleted = allProgress.values.fold<int>(0, (sum, v) => sum + v);
    await UserPreferences.saveCompletedLessons(totalCompleted);

    // Track exercise completion for quest system.
    await UserPreferences.recordExerciseCompleted();

    // Check if the level is now fully completed.
    if (updatedProgress >= lessonsPerLevel) {
      debugPrint(
        '🏆 Level $level fully completed! ($updatedProgress/$lessonsPerLevel)',
      );
      await _handleLevelCompletion(level);
      return true;
    }

    return false;
  }

  // ── Level Completion & Unlock ────────────────────────────────────────

  Future<void> _handleLevelCompletion(String level) async {
    debugPrint('🔓 Handling Level Completion for $level...');

    // Mark this level as completed.
    final completedLevels = await UserPreferences.getCompletedLevels();
    if (!completedLevels.contains(level)) {
      completedLevels.add(level);
      await UserPreferences.saveCompletedLevels(completedLevels);
      debugPrint('✅ Added $level to completed levels list.');
    }

    // Unlock the next level and promote current level.
    final nextLevel = _nextLevel(level);
    if (nextLevel != null) {
      debugPrint('🔓 Unlocking next level: $nextLevel');
      await UserPreferences.unlockLevel(nextLevel);
      await UserPreferences.saveCurrentLevel(nextLevel);
      debugPrint('✅ Active level updated to $nextLevel');
    } else {
      debugPrint('🏁 No next level (User finished final level: $level)');
    }
  }

  /// Returns the next level after [level], or `null` if it's the last.
  String? _nextLevel(String level) {
    final index = _levelOrder.indexOf(level);
    if (index == -1 || index >= _levelOrder.length - 1) return null;
    return _levelOrder[index + 1];
  }

  // ── Query Helpers ────────────────────────────────────────────────────

  /// Whether all 25 lessons of [level] are done.
  Future<bool> isLevelCompleted(String level) async {
    final progress = await getCompletedLessonsForLevel(level);
    return progress >= lessonsPerLevel;
  }

  /// Whether the given [lessonInLevel] (1‑based) in [level] is already done.
  Future<bool> isLessonCompleted(String level, int lessonInLevel) async {
    final progress = await getCompletedLessonsForLevel(level);
    return lessonInLevel <= progress;
  }

  // ── Reset (Testing) ─────────────────────────────────────────────────

  /// Clears all lesson progress (for testing / debug).
  Future<void> resetProgress() async {
    for (final level in _levelOrder) {
      await UserPreferences.saveLevelLessonProgress(level, 0);
    }
    await UserPreferences.saveCompletedLessons(0);
    await UserPreferences.saveCompletedLevels([]);
    await UserPreferences.saveUnlockedLevels(['A1']);
    await UserPreferences.saveCurrentLevel('A1');
  }
}
