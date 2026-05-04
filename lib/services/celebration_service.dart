/// Service for checking birthdays and Turkish national holidays.
class CelebrationService {
  /// Check if today is user's birthday (given stored MM-DD).
  static bool isBirthday(String? birthdayMmDd) {
    if (birthdayMmDd == null) return false;
    final now = DateTime.now();
    final todayMmdd =
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return birthdayMmDd == todayMmdd;
  }

  /// Get Turkish national holiday info for today, or null if none.
  static HolidayInfo? getTodayHoliday() {
    final now = DateTime.now();
    final mmdd =
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return _holidays[mmdd];
  }

  /// All Turkish national holidays (fixed-date).
  static final Map<String, HolidayInfo> _holidays = {
    '01-01': HolidayInfo(
      title: 'Yeni Yıl',
      message: 'Yeni yılınız kutlu olsun! 🎉',
      emoji: '🎆',
    ),
    '04-23': HolidayInfo(
      title: '23 Nisan',
      message: '23 Nisan Ulusal Egemenlik ve Çocuk Bayramı kutlu olsun! 🇹🇷',
      emoji: '🇹🇷',
    ),
    '05-01': HolidayInfo(
      title: '1 Mayıs',
      message: '1 Mayıs Emek ve Dayanışma Günü kutlu olsun! 💪',
      emoji: '✊',
    ),
    '05-19': HolidayInfo(
      title: '19 Mayıs',
      message:
          '19 Mayıs Atatürk\'ü Anma, Gençlik ve Spor Bayramı kutlu olsun! 🇹🇷',
      emoji: '🇹🇷',
    ),
    '07-15': HolidayInfo(
      title: '15 Temmuz',
      message:
          '15 Temmuz Demokrasi ve Milli Birlik Günü. Şehitlerimizi saygıyla anıyoruz. 🇹🇷',
      emoji: '🇹🇷',
    ),
    '08-30': HolidayInfo(
      title: '30 Ağustos',
      message: '30 Ağustos Zafer Bayramı kutlu olsun! 🇹🇷',
      emoji: '🏆',
    ),
    '10-29': HolidayInfo(
      title: '29 Ekim',
      message: '29 Ekim Cumhuriyet Bayramı kutlu olsun! 🇹🇷',
      emoji: '🇹🇷',
    ),
    '11-10': HolidayInfo(
      title: '10 Kasım',
      message:
          'Ulu Önder Mustafa Kemal Atatürk\'ü saygı ve özlemle anıyoruz. 🖤',
      emoji: '🖤',
    ),
  };
}

class HolidayInfo {
  final String title;
  final String message;
  final String emoji;

  HolidayInfo({
    required this.title,
    required this.message,
    required this.emoji,
  });
}
