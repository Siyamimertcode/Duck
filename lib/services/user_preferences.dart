import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _keyUserName = 'user_name';
  static const String _keyNameChangesThisMonth = 'name_changes_this_month';
  static const String _keyLastChangeMonth = 'last_change_month';
  static const String _keyEnglishLevel = 'english_level';
  static const String _keyStreak = 'streak_count';
  static const String _keyLastVisitDate = 'last_visit_date';
  static const String _keyXP = 'user_xp';
  static const String _keyLevel = 'user_level';
  static const String _keyCompletedQuests = 'completed_quests';
  static const String _keyClaimedQuests = 'claimed_quests';
  static const String _keyAssignedDailyQuests = 'assigned_daily_quests';
  static const String _keyAssignedWeeklyQuests = 'assigned_weekly_quests';
  static const String _keyDailyQuestCounter = 'daily_quest_counter';
  static const String _keyWeeklyQuestCounter = 'weekly_quest_counter';

  // Daily/Weekly reset keys
  static const String _keyLastDailyReset = 'last_daily_reset'; // YYYY-MM-DD
  static const String _keyLastWeeklyReset =
      'last_weekly_reset'; // Monday YYYY-MM-DD

  // Daily counters
  static const String _keyOpensToday = 'opens_today';
  static const String _keyExercisesToday = 'exercises_today';
  static const String _keyMinutesToday = 'minutes_today';
  static const String _keyXPToday = 'xp_today';
  static const String _keyGamesToday = 'games_today';
  static const String _keyWordsToday = 'words_today';
  static const String _keyTestsToday = 'tests_today';
  static const String _keyCorrectStreakToday = 'correct_streak_today';
  static const String _keyMaxCorrectStreakToday = 'max_correct_streak_today';
  static const String _keyErrorFreeTasksToday = 'error_free_tasks_today';
  static const String _keyListeningToday = 'listening_today';
  static const String _keySpeakingToday = 'speaking_today';
  static const String _keyWritingToday = 'writing_today';
  static const String _keyWordReviewsToday = 'word_reviews_today';
  static const String _keyTasksCompletedToday = 'tasks_completed_today';

  // Weekly counters
  static const String _keyOpensWeek = 'opens_week';
  static const String _keyExercisesWeek = 'exercises_week';
  static const String _keyMinutesWeek = 'minutes_week';
  static const String _keyXPWeek = 'xp_week';
  static const String _keyLevelsWeek = 'levels_week';
  static const String _keyGamesWeek = 'games_week';
  static const String _keyWordsWeek = 'words_week';
  static const String _keyTestsWeek = 'tests_week';
  static const String _keyErrorFreeTasksWeek = 'error_free_tasks_week';
  static const String _keyListeningWeek = 'listening_week';
  static const String _keySpeakingWeek = 'speaking_week';
  static const String _keyWritingWeek = 'writing_week';
  static const String _keyTasksCompletedWeek = 'tasks_completed_week';

  // Achievement keys
  static const String _keyCompletedAchievements = 'completed_achievements';

  // Lesson progress key
  static const String _keyCompletedLessons = 'completed_lessons';
  static const String _keyCurrentLessonNumber = 'current_lesson_number';
  static const String _keyUnlockedLevels = 'unlocked_levels';
  static const String _keyLevelProgressPrefix = 'level_progress_';
  static const List<String> languageLevels = ['A1', 'A2', 'B1', 'B2', 'C1'];

  // Lifetime/Total stats (never reset)
  static const String _keyTotalAppOpens = 'total_app_opens';
  static const String _keyTotalGamesPlayed = 'total_games_played';
  static const String _keyTotalLessonsCompleted = 'total_lessons_completed';
  static const String _keyTotalErrorFreeGames = 'total_error_free_games';
  static const String _keyTotalMinutesSpent = 'total_minutes_spent';
  static const String _keyTotalXPEarned = 'total_xp_earned';
  static const String _keyTotalQuestsCompleted = 'total_quests_completed';

  // One-time experience flags
  static const String _keyFirstLaunchDone = 'first_launch_done';
  static const String _keyFirstHomeEffectDone = 'first_home_effect_done';
  static const String _keyBirthday = 'user_birthday'; // MM-DD format

  // Save user name
  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  // Get user name
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  // ── Birthday ────────────────────────────────────────────────────────

  /// Save user birthday (stored as 'MM-DD' for annual comparison)
  static Future<void> saveBirthday(int month, int day) async {
    final prefs = await SharedPreferences.getInstance();
    final mmdd =
        '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    await prefs.setString(_keyBirthday, mmdd);
  }

  /// Get user birthday as 'MM-DD' string, or null if not set.
  static Future<String?> getBirthday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBirthday);
  }

  /// Returns true if today is the user's birthday.
  static Future<bool> isTodayBirthday() async {
    final birthday = await getBirthday();
    if (birthday == null) return false;
    final now = DateTime.now();
    final todayMmdd =
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return birthday == todayMmdd;
  }

  // ── Mute State ──────────────────────────────────────────────────────

  /// Saves the mute state (true = silent, false = sound on).
  static Future<void> saveMuted(bool isMuted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_muted', isMuted);
  }

  /// Returns true if sound is muted, false otherwise (default false).
  static Future<bool> getMuted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_muted') ?? false;
  }

  // ── One-time Experience Flags ───────────────────────────────────────

  /// Returns true if this is the very first app launch on this device.
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_keyFirstLaunchDone) ?? false);
  }

  /// Marks that first launch onboarding / welcome has been shown.
  static Future<void> setFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunchDone, true);
  }

  /// Returns true if we should play the one-time home entry sound effect.
  static Future<bool> shouldPlayFirstHomeEffect() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_keyFirstHomeEffectDone) ?? false);
  }

  /// Marks that the one-time home entry sound effect has been played.
  static Future<void> markFirstHomeEffectPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstHomeEffectDone, true);
  }

  // Save English level (initial selection)
  static Future<void> saveEnglishLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEnglishLevel, level);
    // Also set as current level if not already set
    final currentLevel = prefs.getString('current_level');
    if (currentLevel == null || currentLevel.isEmpty) {
      await prefs.setString('current_level', level);
    }
  }

  // Get English level
  static Future<String?> getEnglishLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEnglishLevel);
  }

  // Save completed levels (comma separated: A1,A2,B1)
  static Future<void> saveCompletedLevels(List<String> levels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('completed_levels', levels.join(','));
  }

  // Get completed levels
  static Future<List<String>> getCompletedLevels() async {
    final prefs = await SharedPreferences.getInstance();
    final levelsString = prefs.getString('completed_levels');
    if (levelsString == null || levelsString.isEmpty) {
      return [];
    }
    return levelsString.split(',');
  }

  // Save current level (A1, A2, B1, B2, C1)
  static Future<void> saveCurrentLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_level', level);
  }

  // Get current level
  static Future<String> getCurrentLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_level') ?? 'A1';
  }

  // Save completed lessons count
  static Future<void> saveCompletedLessons(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCompletedLessons, count);
  }

  // Save/get current lesson number
  static Future<void> saveCurrentLessonNumber(int lessonNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCurrentLessonNumber, lessonNumber);
  }

  static Future<int> getCurrentLessonNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCurrentLessonNumber) ?? 1;
  }

  // per-level progress (e.g. A1 -> 0..25)
  static Future<void> saveLevelLessonProgress(String level, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyLevelProgressPrefix$level', count);
  }

  static Future<int> getLevelLessonProgress(String level) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyLevelProgressPrefix$level') ?? 0;
  }

  static Future<Map<String, int>> getAllLevelLessonProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final progress = <String, int>{};
    for (final level in languageLevels) {
      progress[level] = prefs.getInt('$_keyLevelProgressPrefix$level') ?? 0;
    }
    return progress;
  }

  // Unlocked levels management (A1 unlocked by default)
  static Future<List<String>> getUnlockedLevels() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyUnlockedLevels);
    if (stored == null || stored.isEmpty) {
      return ['A1'];
    }

    final result = <String>[];
    for (final raw in stored.split(',')) {
      final level = raw.trim();
      if (level.isEmpty) continue;
      if (!result.contains(level)) {
        result.add(level);
      }
    }

    if (!result.contains('A1')) {
      result.insert(0, 'A1');
    }

    return result;
  }

  static Future<void> saveUnlockedLevels(List<String> levels) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = <String>[];
    for (final level in levels) {
      final trimmed = level.trim();
      if (trimmed.isEmpty) continue;
      if (!normalized.contains(trimmed)) {
        normalized.add(trimmed);
      }
    }

    if (!normalized.contains('A1')) {
      normalized.insert(0, 'A1');
    }

    await prefs.setString(_keyUnlockedLevels, normalized.join(','));
  }

  static Future<void> unlockLevel(String level) async {
    final unlocked = await getUnlockedLevels();
    if (!unlocked.contains(level)) {
      unlocked.add(level);
      await saveUnlockedLevels(unlocked);
    }
  }

  // Get completed lessons count
  static Future<int> getCompletedLessons() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCompletedLessons) ?? 0;
  }

  // Save name change count
  static Future<void> saveNameChangesCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNameChangesThisMonth, count);
    await prefs.setString(_keyLastChangeMonth, _getCurrentMonth());
  }

  // Get name change count (resets if new month)
  static Future<int> getNameChangesCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMonth = prefs.getString(_keyLastChangeMonth);
    final currentMonth = _getCurrentMonth();

    // Reset if new month
    if (lastMonth != currentMonth) {
      await saveNameChangesCount(0);
      return 0;
    }

    return prefs.getInt(_keyNameChangesThisMonth) ?? 0;
  }

  static String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month}';
  }

  // Get current date as string (YYYY-MM-DD)
  static String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // Check and update streak
  static Future<int> checkAndUpdateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getCurrentDate();
    final lastVisit = prefs.getString(_keyLastVisitDate);
    int currentStreak = prefs.getInt(_keyStreak) ?? 0;

    if (lastVisit == null) {
      // First visit
      currentStreak = 1;
      await prefs.setString(_keyLastVisitDate, today);
      await prefs.setInt(_keyStreak, currentStreak);
      return currentStreak;
    }

    if (lastVisit == today) {
      // Already visited today
      return currentStreak;
    }

    // Check if yesterday
    final lastVisitDate = DateTime.parse(lastVisit);
    final todayDate = DateTime.parse(today);
    final difference = todayDate.difference(lastVisitDate).inDays;

    if (difference == 1) {
      // Consecutive day - increment streak
      currentStreak++;
    } else if (difference > 1) {
      // Streak broken - reset to 1
      currentStreak = 1;
    }

    await prefs.setString(_keyLastVisitDate, today);
    await prefs.setInt(_keyStreak, currentStreak);
    return currentStreak;
  }

  // Get current streak
  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStreak) ?? 0;
  }

  // Save streak manually
  static Future<void> saveStreak(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStreak, streak);
  }

  // XP System
  // Get current XP
  static Future<int> getXP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyXP) ?? 0;
  }

  // Save XP
  static Future<void> saveXP(int xp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyXP, xp);
  }

  // Add XP and return new total (resets to 0-100 per level)
  static Future<int> addXP(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentXP = await getXP();
    int currentLevel = await getUserLevel();
    int newXP = currentXP + amount;
    int levelsGained = 0;

    // Check if level up (XP >= 100)
    while (newXP >= 100) {
      newXP -= 100;
      currentLevel += 1;
      levelsGained += 1;
    }

    await saveXP(newXP);
    await saveUserLevel(currentLevel);

    // Track daily/weekly XP and levels gained
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(_keyXPToday, (prefs.getInt(_keyXPToday) ?? 0) + amount);
    await prefs.setInt(_keyXPWeek, (prefs.getInt(_keyXPWeek) ?? 0) + amount);
    // Track lifetime XP earned
    await prefs.setInt(
      _keyTotalXPEarned,
      (prefs.getInt(_keyTotalXPEarned) ?? 0) + amount,
    );
    if (levelsGained > 0) {
      await prefs.setInt(
        _keyLevelsWeek,
        (prefs.getInt(_keyLevelsWeek) ?? 0) + levelsGained,
      );
    }

    return newXP;
  }

  // Get current level
  static Future<int> getUserLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLevel) ?? 1;
  }

  // Save level
  static Future<void> saveUserLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLevel, level);
  }

  // Calculate level from XP (deprecated - now levels are tracked separately)
  static int calculateLevelFromXP(int xp) {
    // XP is now 0-100 per level, so this just returns current level
    // Keep for compatibility but use getUserLevel() instead
    return (xp ~/ 100) + 1;
  }

  // Calculate XP needed for current level (always 0)
  static int getXPForCurrentLevel(int level) {
    return 0; // Each level starts at 0 XP
  }

  // Calculate XP needed for next level (always 100)
  static int getXPForNextLevel(int level) {
    return 100; // Each level requires 100 XP
  }

  // Get progress to next level (0.0 to 1.0)
  static double getLevelProgress(int currentXP, int currentLevel) {
    // currentXP is already 0-100 for current level
    return (currentXP / 100).clamp(0.0, 1.0);
  }

  // Check and update level based on XP
  static Future<bool> checkAndUpdateLevel() async {
    final currentXP = await getXP();
    final currentLevel = await getUserLevel();
    final calculatedLevel = calculateLevelFromXP(currentXP);

    if (calculatedLevel > currentLevel) {
      await saveUserLevel(calculatedLevel);
      return true; // Level up occurred
    }
    return false; // No level up
  }

  // Quest System
  // Save completed quests (comma separated quest IDs)
  static Future<void> saveCompletedQuests(List<String> questIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCompletedQuests, questIds.join(','));
  }

  // Get completed quests
  static Future<List<String>> getCompletedQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final questsString = prefs.getString(_keyCompletedQuests);
    if (questsString == null || questsString.isEmpty) {
      return [];
    }
    return questsString.split(',');
  }

  // Save claimed quests (quests that rewards were collected)
  static Future<void> saveClaimedQuests(List<String> questIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClaimedQuests, questIds.join(','));
  }

  // Get claimed quests
  static Future<List<String>> getClaimedQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final questsString = prefs.getString(_keyClaimedQuests);
    if (questsString == null || questsString.isEmpty) {
      return [];
    }
    return questsString.split(',');
  }

  // Mark quest as completed
  static Future<void> markQuestCompleted(String questId) async {
    final completed = await getCompletedQuests();
    if (!completed.contains(questId)) {
      completed.add(questId);
      await saveCompletedQuests(completed);
      // Track lifetime quests completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _keyTotalQuestsCompleted,
        (prefs.getInt(_keyTotalQuestsCompleted) ?? 0) + 1,
      );
    }
  }

  // Mark quest reward as claimed
  static Future<void> markQuestClaimed(String questId) async {
    final claimed = await getClaimedQuests();
    if (!claimed.contains(questId)) {
      claimed.add(questId);
      await saveClaimedQuests(claimed);
    }
  }

  // Check if quest is completed
  static Future<bool> isQuestCompleted(String questId) async {
    final completed = await getCompletedQuests();
    return completed.contains(questId);
  }

  // Check if quest reward is claimed
  static Future<bool> isQuestClaimed(String questId) async {
    final claimed = await getClaimedQuests();
    return claimed.contains(questId);
  }

  // Save assigned daily quests
  static Future<void> saveAssignedDailyQuests(List<String> questIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAssignedDailyQuests, questIds.join(','));
  }

  // Get assigned daily quests
  static Future<List<String>> getAssignedDailyQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final questsString = prefs.getString(_keyAssignedDailyQuests);
    if (questsString == null || questsString.isEmpty) {
      return [];
    }
    return questsString.split(',');
  }

  // Save assigned weekly quests
  static Future<void> saveAssignedWeeklyQuests(List<String> questIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAssignedWeeklyQuests, questIds.join(','));
  }

  // Get assigned weekly quests
  static Future<List<String>> getAssignedWeeklyQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final questsString = prefs.getString(_keyAssignedWeeklyQuests);
    if (questsString == null || questsString.isEmpty) {
      return [];
    }
    return questsString.split(',');
  }

  // Get daily quest counter (which group of 3 to assign next)
  static Future<int> getDailyQuestCounter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyQuestCounter) ?? 0;
  }

  // Increment daily quest counter
  static Future<void> incrementDailyQuestCounter(int totalTasks) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getDailyQuestCounter();
    final next = (current + 3) % totalTasks;
    await prefs.setInt(_keyDailyQuestCounter, next);
  }

  // Get weekly quest counter (which group of 3 to assign next)
  static Future<int> getWeeklyQuestCounter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWeeklyQuestCounter) ?? 0;
  }

  // Increment weekly quest counter
  static Future<void> incrementWeeklyQuestCounter(int totalTasks) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getWeeklyQuestCounter();
    final next = (current + 3) % totalTasks;
    await prefs.setInt(_keyWeeklyQuestCounter, next);
  }

  // ---------- Achievement System ----------
  // Save completed achievements (comma separated achievement IDs)
  static Future<void> saveCompletedAchievements(
    List<String> achievementIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCompletedAchievements, achievementIds.join(','));
  }

  // Get completed achievements
  static Future<List<String>> getCompletedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsString = prefs.getString(_keyCompletedAchievements);
    if (achievementsString == null || achievementsString.isEmpty) {
      return [];
    }
    return achievementsString.split(',');
  }

  // Mark achievement as completed
  static Future<void> markAchievementCompleted(String achievementId) async {
    final completed = await getCompletedAchievements();
    if (!completed.contains(achievementId)) {
      completed.add(achievementId);
      await saveCompletedAchievements(completed);
    }
  }

  // Check if achievement is completed
  static Future<bool> isAchievementCompleted(String achievementId) async {
    final completed = await getCompletedAchievements();
    return completed.contains(achievementId);
  }

  // ---------- Daily/Weekly Reset & Counters ----------
  static Future<void> ensureDailyWeeklyResets() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
  }

  static Future<void> _ensureDailyWeeklyResetsInternal(
    SharedPreferences prefs,
  ) async {
    final today = _getCurrentDate();
    final lastDaily = prefs.getString(_keyLastDailyReset);
    if (lastDaily != today) {
      // Reset daily counters
      await prefs.setInt(_keyOpensToday, 0);
      await prefs.setInt(_keyExercisesToday, 0);
      await prefs.setInt(_keyMinutesToday, 0);
      await prefs.setInt(_keyXPToday, 0);
      await prefs.setInt(_keyGamesToday, 0);
      await prefs.setInt(_keyWordsToday, 0);
      await prefs.setInt(_keyTestsToday, 0);
      await prefs.setInt(_keyCorrectStreakToday, 0);
      await prefs.setInt(_keyMaxCorrectStreakToday, 0);
      await prefs.setInt(_keyErrorFreeTasksToday, 0);
      await prefs.setInt(_keyListeningToday, 0);
      await prefs.setInt(_keySpeakingToday, 0);
      await prefs.setInt(_keyWritingToday, 0);
      await prefs.setInt(_keyWordReviewsToday, 0);
      await prefs.setInt(_keyTasksCompletedToday, 0);
      // Clear daily quests (prefixed with daily_)
      await _clearQuestsByPrefix(prefs, prefix: 'daily_');
      // Clear assigned daily quests to force regeneration
      await prefs.setString(_keyAssignedDailyQuests, '');
      await prefs.setString(_keyLastDailyReset, today);
    }

    final monday = _getMondayOfCurrentWeek();
    final lastWeekly = prefs.getString(_keyLastWeeklyReset);
    if (lastWeekly != monday) {
      // Reset weekly counters
      await prefs.setInt(_keyOpensWeek, 0);
      await prefs.setInt(_keyExercisesWeek, 0);
      await prefs.setInt(_keyMinutesWeek, 0);
      await prefs.setInt(_keyXPWeek, 0);
      await prefs.setInt(_keyLevelsWeek, 0);
      await prefs.setInt(_keyGamesWeek, 0);
      await prefs.setInt(_keyWordsWeek, 0);
      await prefs.setInt(_keyTestsWeek, 0);
      await prefs.setInt(_keyErrorFreeTasksWeek, 0);
      await prefs.setInt(_keyListeningWeek, 0);
      await prefs.setInt(_keySpeakingWeek, 0);
      await prefs.setInt(_keyWritingWeek, 0);
      await prefs.setInt(_keyTasksCompletedWeek, 0);
      // Clear weekly quests (prefixed with weekly_)
      await _clearQuestsByPrefix(prefs, prefix: 'weekly_');
      // Clear assigned weekly quests to force regeneration
      await prefs.setString(_keyAssignedWeeklyQuests, '');
      await prefs.setString(_keyLastWeeklyReset, monday);
    }
  }

  static Future<void> _clearQuestsByPrefix(
    SharedPreferences prefs, {
    required String prefix,
  }) async {
    final completed = (await getCompletedQuests())
        .where((id) => !id.startsWith(prefix))
        .toList();
    final claimed = (await getClaimedQuests())
        .where((id) => !id.startsWith(prefix))
        .toList();
    await saveCompletedQuests(completed);
    await saveClaimedQuests(claimed);
  }

  // Event counters API
  static Future<void> recordAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(_keyOpensToday, (prefs.getInt(_keyOpensToday) ?? 0) + 1);
    await prefs.setInt(_keyOpensWeek, (prefs.getInt(_keyOpensWeek) ?? 0) + 1);
    // Track lifetime stat
    await prefs.setInt(
      _keyTotalAppOpens,
      (prefs.getInt(_keyTotalAppOpens) ?? 0) + 1,
    );
  }

  static Future<void> recordExerciseCompleted({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyExercisesToday,
      (prefs.getInt(_keyExercisesToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keyExercisesWeek,
      (prefs.getInt(_keyExercisesWeek) ?? 0) + count,
    );
    // Track lifetime stat
    await prefs.setInt(
      _keyTotalLessonsCompleted,
      (prefs.getInt(_keyTotalLessonsCompleted) ?? 0) + count,
    );
  }

  static Future<void> recordMinutesSpent(int minutes) async {
    if (minutes <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyMinutesToday,
      (prefs.getInt(_keyMinutesToday) ?? 0) + minutes,
    );
    await prefs.setInt(
      _keyMinutesWeek,
      (prefs.getInt(_keyMinutesWeek) ?? 0) + minutes,
    );
    // Track lifetime stat
    await prefs.setInt(
      _keyTotalMinutesSpent,
      (prefs.getInt(_keyTotalMinutesSpent) ?? 0) + minutes,
    );
  }

  static Future<void> recordGamePlayed({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyGamesToday,
      (prefs.getInt(_keyGamesToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keyGamesWeek,
      (prefs.getInt(_keyGamesWeek) ?? 0) + count,
    );
    // Track lifetime stat
    await prefs.setInt(
      _keyTotalGamesPlayed,
      (prefs.getInt(_keyTotalGamesPlayed) ?? 0) + count,
    );
  }

  static Future<void> recordWordsLearned({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyWordsToday,
      (prefs.getInt(_keyWordsToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keyWordsWeek,
      (prefs.getInt(_keyWordsWeek) ?? 0) + count,
    );
  }

  static Future<void> recordTestCompleted({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyTestsToday,
      (prefs.getInt(_keyTestsToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keyTestsWeek,
      (prefs.getInt(_keyTestsWeek) ?? 0) + count,
    );
  }

  static Future<void> recordCorrectAnswer() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    final currentStreak = (prefs.getInt(_keyCorrectStreakToday) ?? 0) + 1;
    await prefs.setInt(_keyCorrectStreakToday, currentStreak);
    final maxStreak = prefs.getInt(_keyMaxCorrectStreakToday) ?? 0;
    if (currentStreak > maxStreak) {
      await prefs.setInt(_keyMaxCorrectStreakToday, currentStreak);
    }
  }

  static Future<void> recordWrongAnswer() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(_keyCorrectStreakToday, 0);
  }

  static Future<void> recordErrorFreeTask({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyErrorFreeTasksToday,
      (prefs.getInt(_keyErrorFreeTasksToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keyErrorFreeTasksWeek,
      (prefs.getInt(_keyErrorFreeTasksWeek) ?? 0) + count,
    );
    // Track lifetime stat
    await prefs.setInt(
      _keyTotalErrorFreeGames,
      (prefs.getInt(_keyTotalErrorFreeGames) ?? 0) + count,
    );
  }

  static Future<void> recordListeningActivity({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyListeningToday,
      (prefs.getInt(_keyListeningToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keyListeningWeek,
      (prefs.getInt(_keyListeningWeek) ?? 0) + count,
    );
  }

  static Future<void> recordSpeakingActivity({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keySpeakingToday,
      (prefs.getInt(_keySpeakingToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keySpeakingWeek,
      (prefs.getInt(_keySpeakingWeek) ?? 0) + count,
    );
  }

  static Future<void> recordWritingActivity({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyWritingToday,
      (prefs.getInt(_keyWritingToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keyWritingWeek,
      (prefs.getInt(_keyWritingWeek) ?? 0) + count,
    );
  }

  static Future<void> recordWordReview({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyWordReviewsToday,
      (prefs.getInt(_keyWordReviewsToday) ?? 0) + count,
    );
  }

  static Future<void> recordTaskCompleted({int count = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureDailyWeeklyResetsInternal(prefs);
    await prefs.setInt(
      _keyTasksCompletedToday,
      (prefs.getInt(_keyTasksCompletedToday) ?? 0) + count,
    );
    await prefs.setInt(
      _keyTasksCompletedWeek,
      (prefs.getInt(_keyTasksCompletedWeek) ?? 0) + count,
    );
  }

  // Getters for counters
  static Future<int> getOpensToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyOpensToday) ?? 0;
  }

  static Future<int> getExercisesToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyExercisesToday) ?? 0;
  }

  static Future<int> getMinutesToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMinutesToday) ?? 0;
  }

  static Future<int> getXPToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyXPToday) ?? 0;
  }

  static Future<int> getXPWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyXPWeek) ?? 0;
  }

  static Future<int> getExercisesWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyExercisesWeek) ?? 0;
  }

  static Future<int> getOpensWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyOpensWeek) ?? 0;
  }

  static Future<int> getMinutesWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMinutesWeek) ?? 0;
  }

  static Future<int> getLevelsWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLevelsWeek) ?? 0;
  }

  static Future<int> getGamesToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyGamesToday) ?? 0;
  }

  static Future<int> getGamesWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyGamesWeek) ?? 0;
  }

  static Future<int> getWordsToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWordsToday) ?? 0;
  }

  static Future<int> getWordsWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWordsWeek) ?? 0;
  }

  static Future<int> getTestsToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTestsToday) ?? 0;
  }

  static Future<int> getTestsWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTestsWeek) ?? 0;
  }

  static Future<int> getMaxCorrectStreakToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMaxCorrectStreakToday) ?? 0;
  }

  static Future<int> getErrorFreeTasksToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyErrorFreeTasksToday) ?? 0;
  }

  static Future<int> getErrorFreeTasksWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyErrorFreeTasksWeek) ?? 0;
  }

  static Future<int> getListeningToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyListeningToday) ?? 0;
  }

  static Future<int> getListeningWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyListeningWeek) ?? 0;
  }

  static Future<int> getSpeakingToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySpeakingToday) ?? 0;
  }

  static Future<int> getSpeakingWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySpeakingWeek) ?? 0;
  }

  static Future<int> getWritingToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWritingToday) ?? 0;
  }

  static Future<int> getWritingWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWritingWeek) ?? 0;
  }

  static Future<int> getWordReviewsToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyWordReviewsToday) ?? 0;
  }

  static Future<int> getTasksCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTasksCompletedToday) ?? 0;
  }

  static Future<int> getTasksCompletedWeek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTasksCompletedWeek) ?? 0;
  }

  // ---------- Lifetime/Total Stats ----------
  static Future<int> getTotalAppOpens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalAppOpens) ?? 0;
  }

  static Future<int> getTotalGamesPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalGamesPlayed) ?? 0;
  }

  static Future<int> getTotalLessonsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalLessonsCompleted) ?? 0;
  }

  static Future<int> getTotalErrorFreeGames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalErrorFreeGames) ?? 0;
  }

  static Future<int> getTotalMinutesSpent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalMinutesSpent) ?? 0;
  }

  static Future<int> getTotalXPEarned() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalXPEarned) ?? 0;
  }

  static Future<int> getTotalQuestsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTotalQuestsCompleted) ?? 0;
  }

  // Clear all data (logout)
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Helpers
  static String _getMondayOfCurrentWeek() {
    final now = DateTime.now();
    final int weekday = now.weekday; // 1=Mon
    final monday = now.subtract(Duration(days: weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }
}
