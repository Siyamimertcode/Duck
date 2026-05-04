import 'dart:convert';
import 'package:flutter/services.dart';

class WordItem {
  final String english;
  final String turkish;

  WordItem({required this.english, required this.turkish});

  /// Parse a word entry like "Apple - Elma" into WordItem
  factory WordItem.fromString(String entry) {
    final parts = entry.split(' - ');
    if (parts.length >= 2) {
      return WordItem(
        english: parts[0].trim(),
        turkish: parts.sublist(1).join(' - ').trim(),
      );
    }
    return WordItem(english: entry, turkish: entry);
  }
}

class WordService {
  static Map<String, List<WordItem>>? _cachedWords;

  /// Get all words for a specific level (A1, A2, B1, B2, C1)
  static Future<List<WordItem>> getWordsForLevel(String level) async {
    // Normalize level
    final normalizedLevel = level.toUpperCase();

    // Check cache
    if (_cachedWords != null && _cachedWords!.containsKey(normalizedLevel)) {
      return _cachedWords![normalizedLevel]!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'json/${normalizedLevel}_words.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);

      final List<dynamic> wordStrings = data['words'] ?? [];
      final List<WordItem> words = wordStrings
          .map((w) => WordItem.fromString(w.toString()))
          .toList();

      // Cache the result
      _cachedWords ??= {};
      _cachedWords![normalizedLevel] = words;

      return words;
    } catch (e) {
      print('Error loading words for level $level: $e');
      return [];
    }
  }

  /// Get random wrong translations for a word from the same level
  static List<String> getWrongTranslations(
    WordItem correctWord,
    List<WordItem> allWords,
    int count,
  ) {
    final List<String> wrongTranslations = [];
    final List<WordItem> shuffled = List.from(allWords)..shuffle();

    for (final word in shuffled) {
      if (word.turkish != correctWord.turkish &&
          !wrongTranslations.contains(word.turkish)) {
        wrongTranslations.add(word.turkish);
        if (wrongTranslations.length >= count) break;
      }
    }

    return wrongTranslations;
  }

  /// Clear cache
  static void clearCache() {
    _cachedWords = null;
  }
}
