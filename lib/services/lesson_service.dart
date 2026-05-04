import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LessonService {
  static Map<String, dynamic>? _lessonData;
  static bool _loaded = false;

  static Future<void> loadLessons() async {
    if (_loaded) return;

    try {
      final jsonString = await rootBundle.loadString('json/konular.json');
      _lessonData = json.decode(jsonString);
      _loaded = true;
    } catch (e) {
      print('Error loading konular.json: $e');
      _lessonData = null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllLessons() async {
    await loadLessons();
    if (_lessonData == null) return [];

    final levels = _lessonData!['levels'] as List<dynamic>? ?? [];
    final allLessons = <Map<String, dynamic>>[];
    int lessonNumber = 1;

    for (var level in levels) {
      final levelName = level['level'] as String;
      final description = level['description'] as String;
      final lessons = level['lessons'] as List<dynamic>? ?? [];

      for (int i = 0; i < lessons.length; i++) {
        allLessons.add({
          'lessonNumber': lessonNumber,
          'level': levelName,
          'levelDescription': description,
          'title': lessons[i] as String,
          'lessonInLevel': i + 1,
        });
        lessonNumber++;
      }
    }

    return allLessons;
  }

  static String getEmojiForLevel(String level) {
    switch (level) {
      case 'A1':
        return '🐣';
      case 'A2':
        return '🦆';
      case 'B1':
        return '🦅';
      case 'B2':
        return '🦉';
      case 'C1':
        return '👑';
      default:
        return '📚';
    }
  }

  static Color getColorForLevel(String level) {
    switch (level) {
      case 'A1':
        return const Color(0xFF4CAF50);
      case 'A2':
        return const Color(0xFF8BC34A);
      case 'B1':
        return const Color(0xFFFF9800);
      case 'B2':
        return const Color(0xFFFF5722);
      case 'C1':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF1D6755);
    }
  }
}
