import 'package:audioplayers/audioplayers.dart';
import 'user_preferences.dart';

/// All available sound effects in the app.
enum SoundEffect {
  correct,
  wrong,
  tap,
  swoosh,
  levelUp,
  streak,
  complete,
  welcome,
  navigation,
  countdownTick,
  match,
}

/// Professional centralized sound effects service.
/// Uses singleton pattern with pre-loaded audio players for instant playback.
class SoundService {
  SoundService._internal();
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;

  bool _isInitialized = false;

  // Audio player pool for concurrent playback
  final Map<SoundEffect, AudioPlayer> _players = {};

  // Map enum to asset file names
  static const Map<SoundEffect, String> _soundFiles = {
    SoundEffect.correct: 'correct.wav',
    SoundEffect.wrong: 'wrong.wav',
    SoundEffect.tap: 'tap.wav',
    SoundEffect.swoosh: 'swoosh.wav',
    SoundEffect.levelUp: 'level_up.wav',
    SoundEffect.streak: 'streak.wav',
    SoundEffect.complete: 'complete.wav',
    SoundEffect.welcome: 'welcome.wav',
    SoundEffect.navigation: 'navigation.wav',
    SoundEffect.countdownTick: 'countdown_tick.wav',
    SoundEffect.match: 'match.wav',
  };

  /// Initialize all audio players. Call once at app start.
  Future<void> init() async {
    if (_isInitialized) return;

    for (final effect in SoundEffect.values) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      _players[effect] = player;
    }

    _isInitialized = true;
  }

  /// Play a sound effect. Respects mute setting.
  Future<void> play(SoundEffect effect, {double volume = 1.0}) async {
    try {
      // Check mute state
      if (await UserPreferences.getMuted()) return;

      if (!_isInitialized) await init();

      final player = _players[effect];
      if (player == null) return;

      final fileName = _soundFiles[effect];
      if (fileName == null) return;

      // Stop any current playback of this sound
      await player.stop();

      // Set volume
      await player.setVolume(volume);

      // Play from asset
      await player.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      // Silently fail – sound effects should never crash the app
    }
  }

  /// Play correct answer sound.
  Future<void> playCorrect() => play(SoundEffect.correct);

  /// Play wrong answer sound (buzzer).
  Future<void> playWrong() => play(SoundEffect.wrong);

  /// Play subtle UI tap sound.
  Future<void> playTap() => play(SoundEffect.tap, volume: 0.5);

  /// Play transition swoosh.
  Future<void> playSwoosh() => play(SoundEffect.swoosh, volume: 0.6);

  /// Play level-up fanfare.
  Future<void> playLevelUp() => play(SoundEffect.levelUp);

  /// Play streak achievement sparkle.
  Future<void> playStreak() => play(SoundEffect.streak, volume: 0.7);

  /// Play lesson complete celebration.
  Future<void> playComplete() => play(SoundEffect.complete);

  /// Play app welcome chime.
  Future<void> playWelcome() => play(SoundEffect.welcome, volume: 0.8);

  /// Play navigation/screen transition sound.
  Future<void> playNavigation() => play(SoundEffect.navigation, volume: 0.4);

  /// Play countdown tick.
  Future<void> playCountdownTick() =>
      play(SoundEffect.countdownTick, volume: 0.5);

  /// Play matching pair found.
  Future<void> playMatch() => play(SoundEffect.match, volume: 0.7);

  /// Dispose all players. Call on app exit.
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _isInitialized = false;
  }
}
