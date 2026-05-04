import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'user_preferences.dart';

/// Centralized Text-to-Speech service for the app.
/// Uses singleton pattern so TTS engine is shared across screens.
///
/// Supports bilingual reading: Turkish parts with Turkish accent,
/// English parts with English accent.
class TtsService {
  TtsService._internal();
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  // Completer to wait for speech completion
  Completer<void>? _speechCompleter;

  /// Initialize the TTS engine.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      _flutterTts!.setCompletionHandler(() {
        _speechCompleter?.complete();
        _speechCompleter = null;
      });

      _flutterTts!.setErrorHandler((msg) {
        _speechCompleter?.complete();
        _speechCompleter = null;
      });

      _isInitialized = true;
    } catch (e) {
      _flutterTts = null;
      _isInitialized = false;
    }
  }

  /// Speak the given [text] in English (US accent).
  Future<void> speakEnglish(String text) async {
    try {
      if (text.isEmpty) return;
      if (await UserPreferences.getMuted()) return;

      await _ensureInitialized();
      if (_flutterTts == null) return;
      await _flutterTts!.stop();

      await _flutterTts!.setLanguage('en-US');
      await _flutterTts!.setSpeechRate(0.5);

      _speechCompleter = Completer<void>();
      await _flutterTts!.speak(text);
      await _speechCompleter?.future;
    } catch (e) {
      _speechCompleter = null;
    }
  }

  /// Speak the given [text] in Turkish.
  Future<void> speakTurkish(String text) async {
    try {
      if (text.isEmpty) return;
      if (await UserPreferences.getMuted()) return;

      await _ensureInitialized();
      if (_flutterTts == null) return;
      await _flutterTts!.stop();

      await _flutterTts!.setLanguage('tr-TR');
      await _flutterTts!.setSpeechRate(0.5);

      // Phonetic corrections for better pronunciation
      final processedText = text.replaceAll(
        RegExp(r'Duck', caseSensitive: false),
        'Dak',
      );

      _speechCompleter = Completer<void>();
      await _flutterTts!.speak(processedText);
      await _speechCompleter?.future;
    } catch (e) {
      _speechCompleter = null;
    }
  }

  /// Speak text with automatic language detection.
  /// Determines the dominant language of the entire sentence first,
  /// then handles quoted foreign segments within it.
  /// If [forceAlphabetMode] is true, everything is read in Turkish.
  Future<void> speakSmart(String text, {bool forceAlphabetMode = false}) async {
    try {
      if (text.isEmpty) return;
      if (await UserPreferences.getMuted()) return;

      await _ensureInitialized();
      if (_flutterTts == null) return;
      await _flutterTts!.stop();

      if (forceAlphabetMode) {
        await speakTurkish(text);
        return;
      }

      // Determine the dominant language of the whole sentence
      final isTurkish = _isDominantlyTurkish(text);

      if (isTurkish) {
        // Check for quoted English segments within Turkish text
        final segments = _extractQuotedSegments(text);
        if (segments.length <= 1) {
          // Pure Turkish - read as a single Turkish utterance
          await _speakSegment(text, 'tr-TR', 0.5);
        } else {
          // Turkish text with embedded English quotes
          for (final seg in segments) {
            if (seg.text.trim().isEmpty) continue;
            if (seg.isEnglish) {
              await _speakSegment(seg.text, 'en-US', 0.45);
            } else {
              await _speakSegment(seg.text, 'tr-TR', 0.5);
            }
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      } else {
        // Entire sentence is English - read as a single English utterance
        await _speakSegment(text, 'en-US', 0.45);
      }
    } catch (e) {
      _speechCompleter = null;
    }
  }

  /// Low-level helper to speak a single segment in a given language.
  Future<void> _speakSegment(String text, String language, double rate) async {
    try {
      if (text.trim().isEmpty) return;
      if (_flutterTts == null) return;

      await _flutterTts!.setLanguage(language);
      await _flutterTts!.setSpeechRate(rate);

      String processed = text;
      if (language == 'tr-TR') {
        processed = text.replaceAll(
          RegExp(r'Duck', caseSensitive: false),
          'Dak',
        );
      }

      _speechCompleter = Completer<void>();
      await _flutterTts!.speak(processed);
      try {
        await _speechCompleter?.future.timeout(
          Duration(seconds: processed.length ~/ 3 + 3),
        );
      } catch (_) {
        // Timeout - move on
      }
    } catch (e) {
      _speechCompleter = null;
    }
  }

  /// Determine whether text is dominantly Turkish.
  ///
  /// Uses two signals:
  /// 1. Presence of Turkish-specific characters
  /// 2. Ratio of recognized Turkish words vs English words
  bool _isDominantlyTurkish(String text) {
    // Strong signal: Turkish-specific characters (ç, ğ, ı, İ, ö, ş, ü)
    if (RegExp(r'[çÇğĞıİöÖşŞüÜ]').hasMatch(text)) {
      return true;
    }

    // Remove quoted portions to analyze the "frame" language
    final stripped = text.replaceAll(
      RegExp(
        r"""['"\u2018\u2019\u201C\u201D][^'"\u2018\u2019\u201C\u201D]+['"\u2018\u2019\u201C\u201D]""",
      ),
      '',
    );

    final words = stripped
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase())
        .where((w) => w.length > 1)
        .toList();

    if (words.isEmpty) return false;

    int turkishScore = 0;
    int englishScore = 0;

    for (final w in words) {
      if (_turkishWordSet.contains(w)) {
        turkishScore++;
      } else if (_englishWordSet.contains(w)) {
        englishScore++;
      }
    }

    // If no words recognized in either language, default to English
    if (turkishScore == 0 && englishScore == 0) return false;

    // Default to Turkish when equal (app UI language is Turkish)
    return turkishScore >= englishScore;
  }

  /// Extract quoted segments as English within a dominantly-Turkish text.
  List<_TextSegment> _extractQuotedSegments(String text) {
    final segments = <_TextSegment>[];
    final quotedRegex = RegExp(
      r"""['"\u2018\u2019\u201C\u201D]([^'"\u2018\u2019\u201C\u201D]+)['"\u2018\u2019\u201C\u201D]""",
    );

    int lastEnd = 0;
    for (final match in quotedRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        final before = text.substring(lastEnd, match.start).trim();
        if (before.isNotEmpty) {
          segments.add(_TextSegment(before, isEnglish: false));
        }
      }
      final quoted = match.group(1) ?? '';
      if (quoted.isNotEmpty) {
        segments.add(_TextSegment(quoted, isEnglish: true));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        segments.add(_TextSegment(remaining, isEnglish: false));
      }
    }

    return segments;
  }

  // --- Static word sets for sentence-level language detection ---

  static const _turkishWordSet = {
    'bir',
    'bu',
    'su',
    've',
    'ile',
    'de',
    'da',
    'mi',
    'mu',
    'ne',
    'nasil',
    'nedir',
    'neden',
    'icin',
    'ise',
    'gibi',
    'var',
    'yok',
    'olarak',
    'olan',
    'olur',
    'olmak',
    'olma',
    'eder',
    'eden',
    'edilir',
    'edilen',
    'yapar',
    'der',
    'dir',
    'hangi',
    'kac',
    'tane',
    'adet',
    'kelime',
    'kelimesinin',
    'cumle',
    'cumlede',
    'cumledeki',
    'cumleyi',
    'anlam',
    'anlami',
    'harfi',
    'harf',
    'harfinin',
    'harfleri',
    'telaffuz',
    'telaffuzu',
    'okunur',
    'okunusu',
    'soylenir',
    'dogru',
    'yanlis',
    'cevap',
    'soru',
    'secenek',
    'asagidakilerden',
    'hangisi',
    'asagida',
    'yukarida',
    'turkce',
    'ingilizce',
    'karsiligi',
    'boslugu',
    'doldurun',
    'siralarin',
    'eslestirin',
    'cevirin',
    'tamamlayin',
    'alfabede',
    'alfabesi',
    'vardir',
    'dil',
    'dili',
    'dilinde',
    'bilgi',
    'siraya',
    'koy',
    'sonra',
    'gelen',
    'sonraki',
    'uygun',
    'sekilde',
    'ifade',
    'anlatan',
    'belirten',
    'nerede',
    'zaman',
    'kadar',
    'daha',
    'en',
    'hem',
    'ya',
    'ben',
    'sen',
    'biz',
    'siz',
    'onlar',
  };

  static const _englishWordSet = {
    'the',
    'is',
    'am',
    'are',
    'was',
    'were',
    'been',
    'be',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'can',
    'may',
    'might',
    'not',
    'no',
    'yes',
    'hello',
    'hi',
    'bye',
    'goodbye',
    'please',
    'thank',
    'thanks',
    'sorry',
    'excuse',
    'what',
    'where',
    'when',
    'why',
    'how',
    'who',
    'which',
    'this',
    'that',
    'these',
    'those',
    'my',
    'your',
    'his',
    'her',
    'its',
    'our',
    'their',
    'you',
    'he',
    'she',
    'it',
    'we',
    'they',
    'me',
    'him',
    'us',
    'them',
    'book',
    'cat',
    'dog',
    'house',
    'car',
    'pen',
    'apple',
    'good',
    'bad',
    'big',
    'small',
    'new',
    'old',
    'nice',
    'fine',
    'go',
    'come',
    'see',
    'look',
    'take',
    'give',
    'make',
    'like',
    'want',
    'need',
    'know',
    'think',
    'say',
    'tell',
    'meet',
    'in',
    'on',
    'at',
    'to',
    'from',
    'with',
    'of',
    'for',
    'and',
    'but',
    'or',
    'so',
    'because',
    'if',
    'then',
    'very',
    'much',
    'many',
    'some',
    'any',
    'all',
    'every',
    'name',
    'student',
    'teacher',
    'brother',
    'sister',
    'mother',
    'father',
    'friend',
    'family',
    'country',
    'city',
    'school',
    'morning',
    'evening',
    'night',
    'today',
    'tomorrow',
    'yesterday',
    'after',
    'before',
    'next',
    'last',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
    'january',
    'february',
    'march',
    'april',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
    'christmas',
    'birthday',
    'ten',
    'twenty',
    'thirty',
    'forty',
    'fifty',
    'hundred',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'zero',
    'minus',
    'plus',
    'equals',
    'tired',
    'happy',
    'sad',
    'hungry',
    'thirsty',
    'french',
    'german',
    'english',
    'turkish',
    'american',
    'british',
    'france',
    'germany',
    'turkey',
    'england',
    'america',
  };

  /// Stop any ongoing speech.
  Future<void> stop() async {
    if (!_isInitialized) return;
    await _flutterTts!.stop();
    _speechCompleter?.complete();
    _speechCompleter = null;
  }

  /// Dispose the TTS engine and reset state.
  Future<void> dispose() async {
    if (!_isInitialized) return;
    await _flutterTts!.stop();
    _speechCompleter?.complete();
    _speechCompleter = null;
    _isInitialized = false;
    _flutterTts = null;
  }
}

/// Internal class representing a text segment with its language.
class _TextSegment {
  String text;
  final bool isEnglish;

  _TextSegment(this.text, {required this.isEnglish});

  @override
  String toString() => '${isEnglish ? "EN" : "TR"}: "$text"';
}
