import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_preferences.dart';
import '../services/notification_service.dart';
import '../services/app_state.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;

  const SettingsScreen({super.key, required this.userName});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Dynamic theme colors (resolve from context)
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;
  Color get lightOrange => _c.lightOrange;
  Color get cream => _c.cream;
  Color get cardBg => _c.cardColor;

  // Settings State
  late String _userName;
  int _nameChangesThisMonth = 0;
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _isDarkTheme = false;
  String _selectedLanguage = 'tr';

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final storedName = await UserPreferences.getUserName();
    final nameChanges = await UserPreferences.getNameChangesCount();
    final appState = AppState.instance;

    if (mounted) {
      setState(() {
        if (storedName != null && storedName.isNotEmpty) {
          _userName = storedName;
        }
        _nameChangesThisMonth = nameChanges;
        _notificationsEnabled = appState.notificationsEnabled;
        _vibrationEnabled = appState.vibrationEnabled;
        _isDarkTheme = appState.isDark;
        _selectedLanguage = appState.locale;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(S.get('settings_preferences')),
                    const SizedBox(height: 12),
                    _buildPreferencesSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(S.get('settings_appearance')),
                    const SizedBox(height: 12),
                    _buildAppearanceSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(S.get('settings_language')),
                    const SizedBox(height: 12),
                    _buildLanguageSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(S.get('settings_about')),
                    const SizedBox(height: 12),
                    _buildAboutSection(),
                    const SizedBox(height: 12),
                    _buildLegalSection(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cream,
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: darkGreen,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Text(
            S.get('settings_title'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: darkGreen,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Duck icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lightGreen, darkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/duckavatar.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [darkGreen, lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/duckavatar.png',
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showEditNameDialog,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  S.get(
                    'settings_name_changes',
                    args: {'n': '${2 - _nameChangesThisMonth}'},
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkGreen.withOpacity(0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.notifications_rounded,
            iconColor: orange,
            title: S.get('settings_notifications'),
            subtitle: S.get('settings_notifications_desc'),
            value: _notificationsEnabled,
            onChanged: (value) async {
              setState(() => _notificationsEnabled = value);
              await AppState.instance.setNotifications(value);
              await NotificationService().setEnabled(value);
              if (_vibrationEnabled) HapticFeedback.lightImpact();
            },
          ),
          _buildDivider(),
          _buildSwitchTile(
            icon: Icons.vibration_rounded,
            iconColor: lightGreen,
            title: S.get('settings_vibration'),
            subtitle: S.get('settings_vibration_desc'),
            value: _vibrationEnabled,
            onChanged: (value) async {
              setState(() => _vibrationEnabled = value);
              await AppState.instance.setVibration(value);
              if (value) HapticFeedback.mediumImpact();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _buildThemeSelector(),
    );
  }

  Widget _buildThemeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: lightOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.palette_rounded,
                  color: lightOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                S.get('settings_theme'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildThemeOption(
                  icon: Icons.light_mode_rounded,
                  label: S.get('settings_theme_light'),
                  isSelected: !_isDarkTheme,
                  onTap: () async {
                    setState(() => _isDarkTheme = false);
                    await AppState.instance.setThemeMode(ThemeMode.light);
                    if (_vibrationEnabled) HapticFeedback.selectionClick();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildThemeOption(
                  icon: Icons.dark_mode_rounded,
                  label: S.get('settings_theme_dark'),
                  isSelected: _isDarkTheme,
                  onTap: () async {
                    setState(() => _isDarkTheme = true);
                    await AppState.instance.setThemeMode(ThemeMode.dark);
                    if (_vibrationEnabled) HapticFeedback.selectionClick();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? darkGreen : cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? darkGreen : lightGreen.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? _c.textOnPrimary : darkGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? _c.textOnPrimary : darkGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: darkGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.language_rounded, color: darkGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                S.get('settings_app_language'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildLanguageOption(
                  flag: '🇹🇷',
                  label: 'Türkçe',
                  code: 'tr',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLanguageOption(
                  flag: '🇬🇧',
                  label: 'English',
                  code: 'en',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String flag,
    required String label,
    required String code,
  }) {
    final isSelected = _selectedLanguage == code;

    return GestureDetector(
      onTap: () async {
        setState(() => _selectedLanguage = code);
        await AppState.instance.setLocale(code);
        if (_vibrationEnabled) HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? darkGreen : cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? darkGreen : lightGreen.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? _c.textOnPrimary : darkGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    const double partnerLogoBaseHeight = 110;
    const double partnerLogoMaxWidth = 180;
    const double atakLogoScale = 1.5;
    const double royalLogoScale = 0.75;
    final double partnerLogoSlotHeight = partnerLogoBaseHeight * atakLogoScale;

    Widget buildPartnerLogo({required String asset, required double scale}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: partnerLogoSlotHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: partnerLogoMaxWidth * scale,
                  maxHeight: partnerLogoBaseHeight * scale,
                ),
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // App Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/Duckicon.png',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Duck',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: darkGreen,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Versiyon 1.0.0',
            style: TextStyle(fontSize: 13, color: darkGreen.withOpacity(0.4)),
          ),
          const SizedBox(height: 12),
          // Logo section (no boxes)
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: buildPartnerLogo(
                  asset: 'assets/Atakstulogo.png',
                  scale: atakLogoScale,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: buildPartnerLogo(
                  asset: 'assets/logo.png',
                  scale: royalLogoScale,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Placement: move the 'produced by' note under the logos
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: darkGreen.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: darkGreen.withOpacity(0.08)),
            ),
            child: Text(
              'Uygulama Atak Studios tarafından Royal English Time için özel olarak üretilmiştir.',
              style: TextStyle(
                fontSize: 12,
                color: darkGreen.withOpacity(0.7),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '© 2025 Atak Studios. Tüm hakları saklıdır.',
            style: TextStyle(fontSize: 12, color: darkGreen.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLegalTile(
            icon: Icons.description_rounded,
            title: S.get('settings_terms'),
            onTap: () =>
                _showLegalPage(S.get('settings_terms'), _termsOfService),
          ),
          _buildDivider(),
          _buildLegalTile(
            icon: Icons.privacy_tip_rounded,
            title: S.get('settings_privacy'),
            onTap: () =>
                _showLegalPage(S.get('settings_privacy'), _privacyPolicy),
          ),
          _buildDivider(),
          _buildLegalTile(
            icon: Icons.shield_rounded,
            title: S.get('settings_kvkk'),
            onTap: () => _showLegalPage(S.get('settings_kvkk'), _kvkkText),
          ),
          _buildDivider(),
          _buildLegalTile(
            icon: Icons.mail_rounded,
            title: 'İletişim',
            onTap: () => _showLegalPage('İletişim', _contactInfo),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: darkGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: darkGreen.withOpacity(0.6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: darkGreen,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: darkGreen.withOpacity(0.3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLegalPage(String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: cream,
          appBar: AppBar(
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            backgroundColor: DuckTheme.brandGreen,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: darkGreen.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: darkGreen.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.gavel_rounded,
                          color: orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atak Studios',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: darkGreen,
                              ),
                            ),
                            Text(
                              S.get('settings_last_update'),
                              style: TextStyle(
                                fontSize: 12,
                                color: darkGreen.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Content
                _buildLegalContent(title, content),
                const SizedBox(height: 24),
                // Footer
                Center(
                  child: Text(
                    '© 2025 Atak Studios. Tüm hakları saklıdır.',
                    style: TextStyle(
                      fontSize: 12,
                      color: darkGreen.withOpacity(0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalContent(String title, String content) {
    final TextStyle baseStyle = TextStyle(
      fontSize: 14,
      color: darkGreen.withOpacity(0.8),
      height: 1.7,
    );
    final TextStyle linkStyle = baseStyle.copyWith(
      color: lightGreen,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    if (title != 'İletişim') {
      return Text(content, style: baseStyle);
    }

    return SelectableText.rich(
      TextSpan(children: _linkifyText(content, baseStyle, linkStyle)),
    );
  }

  List<InlineSpan> _linkifyText(
    String text,
    TextStyle baseStyle,
    TextStyle linkStyle,
  ) {
    final RegExp pattern = RegExp(
      r'([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|(?:https?:\/\/)?(?:www\.)?[A-Za-z0-9.-]+\.[A-Za-z]{2,})',
    );
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final Match match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final String matchText = match.group(0) ?? '';
      if (matchText.isEmpty) continue;

      if (matchText.contains('@')) {
        final String email = matchText;
        final String url = _gmailComposeUrl(email);
        spans.add(
          TextSpan(
            text: matchText,
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
          ),
        );
      } else {
        final String url = matchText.startsWith('http')
            ? matchText
            : 'https://$matchText';
        spans.add(
          TextSpan(
            text: matchText,
            style: linkStyle,
            recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return spans;
  }

  String _gmailComposeUrl(String email) {
    final String encoded = Uri.encodeComponent(email);
    return 'https://mail.google.com/mail/?view=cm&fs=1&to=$encoded';
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Legal Texts ────────────────────────────────────────────────────

  static const String _termsOfService = '''
DUCK UYGULAMASI KULLANIM KOŞULLARI

1. GENEL HÜKÜMLER

1.1. Bu kullanım koşulları ("Koşullar"), Siyami Mert ATAK / Atak Studios ("Yazılım Geliştirici") tarafından Royal English Time için özel olarak geliştirilen ve yayınlanan Duck İngilizce Öğrenme Uygulaması'nın ("Uygulama") kullanımını düzenlemektedir.

1.2. Uygulamayı indirerek, yükleyerek veya kullanarak bu Koşulları kabul etmiş sayılırsınız. Bu Koşulları kabul etmiyorsanız Uygulamayı kullanmayınız.

1.3. Yazılım Geliştirici, bu Koşulları önceden bildirimde bulunmaksızın değiştirme hakkını saklı tutar.

2. HİZMET TANIMI

2.1. Duck, Royal English Time'ın öğrencilerine İngilizce dil eğitimi sunan mobil bir uygulamadır. Uygulama; interaktif dersler, alıştırmalar, kelime çalışmaları, quiz, çeviri, eşleştirme ve konuşma egzersizleri gibi öğrenme araçları içermektedir.

2.2. Uygulama içeriği tamamen eğitim amaçlıdır ve profesyonel dil eğitiminin yerini almayı amaçlamamaktadır.

2.3. Uygulama internet bağlantısı gerektirmez. Tüm işlemler ve veriler cihazınızda yerel olarak işlenir ve saklanır.

3. KULLANICI YÜKÜMLÜLÜKLERİ

3.1. Kullanıcı, Uygulamayı yalnızca kişisel ve eğitim amaçlarıyla kullanmayı kabul eder.

3.2. Kullanıcı, Uygulama içeriğini kopyalamayacağını, çoğaltmayacağını, dağıtmayacağını, tersine mühendislik yapmayacağını veya herhangi bir şekilde değiştirmeyeceğini kabul eder.

3.3. Kullanıcı, Uygulamayı yasalara aykırı amaçlarla kullanmayacağını taahhüt eder.

3.4. Kullanıcı, Uygulamada sağladığı bilgilerin doğruluğundan sorumludur.

4. SAHİPLİLİK VE FİKRİ MÜLKİYET HAKLARI

4.1. Uygulamanın çekirdek yazılım altyapısı, kaynak kodları, tasarım şablonları ve algoritmaları üzerindeki tüm fikri ve sınai mülkiyet hakları münhasıran Siyami Mert ATAK (Atak Studios)'a aittir. Kaynak kodları ve yazılıma ilişkin tüm haklar Siyami Mert ATAK'e aittir.

4.2. Royal English Time'a, Uygulamanın sadece 'münhasır olmayan' bir kullanım lisansı verilmiştir; bu lisans Uygulamayı kendi eğitim faaliyetleri kapsamında kullanma hakkını verir, ancak kaynak kodlar ve yazılımın kendisi üzerinde mülkiyet hakkı vermez.

4.3. Uygulama içindeki Royal English Time logoları ve kuruma özel hazırlanan eğitim materyalleri (soru, video, metin) Royal English Time'ın mülkiyetindedir.

4.4. Yazılımın 'motoru' ve işleyişi Siyami Mert ATAK (Atak Studios) mülkiyetinde kalmaya devam eder.

4.5. Uygulama Türkiye Cumhuriyeti ve uluslararası fikri mülkiyet yasaları ile korunmaktadır.

4.6. "Duck", "Atak Studios" ve "Royal English Time" isimleri ve ilgili logolar ilgili kurumlarının tescilli markalarıdır.

5. SORUMLULUK SINIRLAMASI

5.1. Uygulama "olduğu gibi" sunulmaktadır. Atak Studios, Uygulamanın kesintisiz veya hatasız çalışacağını garanti etmemektedir.

5.2. Atak Studios, Uygulamanın kullanımından veya kullanılamamasından kaynaklanan doğrudan veya dolaylı zararlardan sorumlu tutulamaz.

6. UYGULANACAK HUKUK

6.1. Bu Koşullar Türkiye Cumhuriyeti hukukuna tabidir.

6.2. Bu Koşullardan doğan uyuşmazlıklarda Türkiye Cumhuriyeti mahkemeleri yetkilidir.

7. İLETİŞİM

Yazılım Geliştiricisi: Siyami Mert ATAK (Atak Studios)
E-mail: atakstudios2025@gmail.com

Müşteri Kurum: Royal English Time
E-mail: izmirgelisimakademi@gmail.com

© 2025 Atak Studios. Tüm hakları saklıdır.
''';

  static const String _privacyPolicy = '''
DUCK UYGULAMASI GİZLİLİK POLİTİKASI

Siyami Mert ATAK (Atak Studios) olarak kullanıcılarımızın gizliliğine büyük önem veriyoruz. Duck uygulaması Royal English Time için özel olarak geliştirilmiş olup, bu Gizlilik Politikası, Duck uygulamasını kullanırken kişisel verilerinizin nasıl toplandığını, kullanıldığını ve korunduğunu açıklamaktadır.

1. TOPLANAN VERİLER

1.1. Doğrudan Sağladığınız Veriler:
• Kullanıcı adı (takma ad)
• Dil seviyesi tercihi
• Uygulama içi ilerleme ve performans verileri

1.2. Otomatik Toplanan Veriler:
• Cihaz türü ve işletim sistemi bilgisi
• Uygulama kullanım istatistikleri
• Ders tamamlama ve başarı oranları

2. VERİLERİN KULLANIM AMACI

Topladığımız verileri yalnızca aşağıdaki amaçlarla kullanmaktayız:
• Size kişiselleştirilmiş bir öğrenme deneyimi sunmak
• İlerlemenizi kaydetmek ve takip etmek
• Uygulamayı iyileştirmek ve geliştirmek
• Size hatırlatma bildirimleri göndermek (izniniz dahilinde)
• Teknik sorunları tespit etmek ve çözmek

3. VERİLERİN SAKLANMASI VE İNTERNET BAĞLANTISI

3.1. Kişisel verileriniz cihazınızda yerel olarak (SharedPreferences) saklanmaktadır. Hiçbir veri uzak sunuculara gönderilmez.

3.2. Duck uygulaması internet bağlantısı gerektirmez. Tüm veriler cihazınızda kalır ve yalnızca cihaz içinde işlenir.

3.3. Uygulamayı sildiğinizde tüm yerel verileriniz kalıcı olarak silinir ve hiçbir veri kalmaz.

3.4. Uygulamanın tamamen çevrimdışı (offline) çalıştığını, hiçbir verinin merkezi bir sunucuya aktarılmadığını ve veri güvenliği sorumluluğunun yerel depolama dahilinde olduğunu vurgularız.

4. VERİ GÜVENLİĞİ

4.1. Verilerinizin güvenliğini sağlamak için endüstri standardı teknik ve organizasyonel önlemler uygulamaktayız.

4.2. Kişisel verilerinizi üçüncü taraflarla hiçbir şekilde paylaşmamakta, satmamakta veya kiralamaktayız.

4.3. Verileriniz sadece cihazınızda bulunur ve merkezi bir veritabanına kaydedilmez.

5. BİLDİRİMLER

5.1. Uygulama, izniniz dahilinde motivasyonel hatırlatma bildirimleri gönderebilir.

5.2. Bildirim tercihlerinizi istediğiniz zaman Uygulama ayarlarından değiştirebilirsiniz.

6. ÇOCUKLARIN GİZLİLİĞİ

6.1. Uygulamamız her yaş grubuna uygundur. 13 yaş altı kullanıcılardan bilerek ek kişisel bilgi toplamıyoruz.

7. SAHİPLİK VE FİKRİ MÜLKİYET

7.1. Uygulamanın çekirdek yazılım altyapısı, kaynak kodları, tasarım şablonları ve algoritmaları üzerindeki tüm fikri ve sınai mülkiyet hakları münhasıran Siyami Mert ATAK (Atak Studios)'a aittir. Kaynak kodları ve yazılımın tüm hakları Atak Studios tarafından saklı tutulur.

7.2. Royal English Time'a Uygulamanın sadece 'münhasır olmayan' bir kullanım lisansı verilmiştir; bu lisans Uygulamayı eğitim faaliyetleri kapsamında kullanma hakkını verir ancak kaynak kodlar üzerinde mülkiyet hakkı vermez.

7.3. Uygulama içindeki Royal English Time logoları ve kuruma özel hazırlanan eğitim materyalleri (soru, video, metin) Royal English Time'ın mülkiyetindedir. Yazılımın 'motoru' ve işleyişi Atak Studios mülkiyetinde kalmaya devam eder.

8. DEĞİŞİKLİKLER

8.1. Bu Gizlilik Politikası zaman zaman güncellenebilir. Önemli değişiklikler olması halinde Uygulama üzerinden bilgilendirileceksiniz.

9. İLETİŞİM

Gizlilik ile ilgili sorularınız için atakstudios2025@gmail.com adresinden bizimle iletişime geçebilirsiniz.

© 2025 Atak Studios. Tüm hakları saklıdır.
''';

  static const String _kvkkText = '''
KİŞİSEL VERİLERİN KORUNMASI KANUNU (KVKK) AYDINLATMA METNİ

Siyami Mert ATAK (Atak Studios), 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında aşağıdaki hususları bilginize sunarız. Duck uygulaması Royal English Time için özel olarak geliştirilmiştir.

1. TOPLANAN KİŞİSEL VERİLER

Duck uygulaması kapsamında aşağıdaki kişisel veriler işlenmektedir:

• Kullanıcı Adı: Uygulama içi tanımlama ve kişiselleştirme amacıyla
• Öğrenme Verileri: Seviye, ilerleme durumu, tamamlanan dersler, başarı oranları
• Cihaz Bilgileri: İşletim sistemi türü, cihaz modeli
• Tercih Bilgileri: Dil tercihi, bildirim ayarları, tema seçimi

2. VERİ SORUMLUSU VE VERİ İŞLEYEN

Veri Sorumlusu: Royal English Time (izmirgelisimakademi@gmail.com)

2.1. 6698 sayılı KVKK kapsamında, uygulamanın son kullanıcılarından (öğrencilerden) toplanan verilerin 'Veri Sorumlusu' Royal English Time kurumudur. Veri sorumlusu olarak Royal English Time, kişisel verilerin hukuka uygun olarak işlenmesinden, korunmasından ve gerektiğinde ilgili veri sahiplerine karşı gerekli bildirim ve işlemleri yürütmekten sorumludur.

2.2. Siyami Mert ATAK (Atak Studios), uygulamanın teknik altyapısını sağlayan 'Veri İşleyen' konumundadır ve yalnızca Royal English Time'ın talimatları doğrultusunda, cihaz üzerinde yerel olarak gerçekleştirilen veri işleme faaliyetlerini yürütür.

2.3. Veri işleme faaliyetleri, cihaz üzerinde yerel olarak (çevrimdışı) gerçekleşmekte olup, merkezi bir sunucuya veri aktarımı söz konusu değildir.

3. VERİ İŞLEMENİN HUKUKİ SEBEBİ

Kişisel verileriniz, KVKK'nın 5. maddesi kapsamında aşağıdaki hukuki sebepler doğrultusunda işlenmektedir:

• Açık rızanız (bildirim gönderimi için)
• Sözleşmenin ifası (hizmetin sunulması için)
• Meşru menfaat (uygulamanın iyileştirilmesi için)

4. VERİLERİN AKTARILMASI VE SAKLANMASI - ÇEVRİMDIŞI YAPILANMA

4.1. Kişisel verileriniz üçüncü kişilere hiçbir şekilde aktarılmamaktadır.

4.2. Tüm veriler cihazınızda yerel olarak saklanmaktadır.

4.3. Uygulama, hiçbir kişisel veriyi internet üzerinden göndermez.

4.4. Uygulama tamamen çevrimdışı (offline) çalışır. Veri işleme tamamen cihaz içinde gerçekleşir.

4.5. Hiçbir veri merkezi bir sunucuya aktarılmaz ve uzak sunuculara yedeklenmez.

4.6. Veri güvenliği sorumluluğu yerel depolama dahilinde olup, cihazda şifreli olarak saklanır.

5. VERİ SAKLAMA SÜRESİ

Kişisel verileriniz, uygulamayı kullandığınız süre boyunca cihazınızda saklanmaktadır. Uygulamayı sildiğinizde tüm verileriniz kalıcı olarak silinir ve hiçbir veri kalmaz.

6. VERİ SAHİBİ OLARAK HAKLARINIZ

KVKK'nın 11. maddesi uyarınca aşağıdaki haklara sahipsiniz:

a) Kişisel verilerinizin işlenip işlenmediğini öğrenme
b) İşlenmişse buna ilişkin bilgi talep etme
c) İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme
d) Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme
e) Eksik veya yanlış işlenmişse düzeltilmesini isteme
f) KVKK'nın 7. maddesi çerçevesinde silinmesini veya yok edilmesini isteme
g) Düzeltme ve silme işlemlerinin aktarıldığı üçüncü kişilere bildirilmesini isteme
h) İşlenen verilerin münhasıran otomatik sistemler aracılığıyla analiz edilmesi suretiyle aleyhinize bir sonucun ortaya çıkmasına itiraz etme
i) Kanuna aykırı olarak işlenmesi sebebiyle zarara uğramanız halinde zararın giderilmesini talep etme

7. SAHİPLİK VE FİKRİ MÜLKİYET

7.1. Uygulamanın çekirdek yazılım altyapısı, kaynak kodları, tasarım şablonları ve algoritmaları üzerindeki tüm fikri ve sınai mülkiyet hakları münhasıran Siyami Mert ATAK (Atak Studios)'a aittir.

7.2. Royal English Time'a, Uygulamanın sadece 'münhasır olmayan' bir kullanım lisansı verilmiştir.

7.3. Uygulama içindeki Royal English Time logoları ve kuruma özel hazırlanan eğitim materyalleri (soru, video, metin) Royal English Time'ın mülkiyetindedir.

7.4. Ancak yazılımın 'motoru' ve işleyişi Atak Studios mülkiyetinde kalmaya devam eder.

8. VERİ GÜVENLİĞİ VE ÇEVRİMDIŞI İŞLEYİŞ

8.1. Royal English Time, veri sorumlusu olarak kişisel verilerin gizliliği, bütünlüğü ve güvenliğinden sorumludur. Uygulamanın gizliliği ve veri koruma tedbirleri, Siyami Mert ATAK (Atak Studios) ile Royal English Time arasında yapılan yazılı anlaşma ile korunmaktadır.

8.2. Siyami Mert ATAK (Atak Studios), veri işleyen sıfatıyla teknik ve idari tedbirlerin uygulanmasına destek sağlar ve yalnızca Royal English Time'ın talimatları doğrultusunda hareket eder.

8.3. Veriler cihaz içinde şifreli olarak saklanır ve uygulama tamamen offline (cihaz üzerinde yerel) çalışır; hiçbir veri merkezi bir sunucuya aktarılmaz.

9. BAŞVURU

KVKK kapsamındaki haklarınızı kullanmak için atakstudios2025@gmail.com adresine yazılı olarak başvurabilirsiniz.

İşbu aydınlatma metni 1 Ocak 2025 tarihinde yürürlüğe girmiştir.

© 2025 Atak Studios. Tüm hakları saklıdır.
''';

  static const String _contactInfo = '''
İLETİŞİM BİLGİLERİ

Yazılım Geliştiricisi
Kurum Adı: Atak Studios
Sorumlu Kişi: Siyami Mert ATAK
E-posta: atakstudios2025@gmail.com
Web: atak-studios.com

Uygulayan Kurum
Kurum Adı: Royal English Time
Sorumlu Kişi: Zeki Ekinci
E-posta: izmirgelisimakademi@gmail.com
Web: royalenglishtime.com
''';

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _showLogoutDialog,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.red[400], size: 22),
                const SizedBox(width: 10),
                Text(S.get('settings_logout'), style: TextStyle()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: darkGreen,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: darkGreen.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return darkGreen;
              return _c.textSecondary;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return lightGreen.withOpacity(0.4);
              }
              return _c.divider;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: darkGreen.withOpacity(0.08)),
    );
  }

  void _showEditNameDialog() {
    if (_nameChangesThisMonth >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  S.get('settings_name_limit'),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final controller = TextEditingController(text: _userName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: darkGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit_rounded, color: darkGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              S.get('settings_edit_name'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              maxLength: 20,
              style: TextStyle(fontSize: 16, color: darkGreen),
              decoration: InputDecoration(
                hintText: S.get('settings_new_name_hint'),
                hintStyle: TextStyle(color: darkGreen.withOpacity(0.4)),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: lightGreen.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: lightGreen.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: darkGreen, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.get(
                'settings_name_changes_left',
                args: {'n': '${2 - _nameChangesThisMonth}'},
              ),
              style: TextStyle(fontSize: 12, color: orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              S.get('cancel'),
              style: TextStyle(
                color: darkGreen.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _userName) {
                await UserPreferences.saveUserName(newName);
                await UserPreferences.saveNameChangesCount(
                  _nameChangesThisMonth + 1,
                );

                setState(() {
                  _userName = newName;
                  _nameChangesThisMonth++;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          S.get(
                            'settings_name_updated',
                            args: {'name': newName},
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    backgroundColor: DuckTheme.brandGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: darkGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(S.get('save')),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: Colors.red[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              S.get('settings_logout'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
          ],
        ),
        content: Text(
          S.get('settings_logout_msg'),
          style: TextStyle(fontSize: 15, color: darkGreen.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              S.get('cancel'),
              style: TextStyle(
                color: darkGreen.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await UserPreferences.clearAllData();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/onboarding',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(S.get('settings_logout')),
          ),
        ],
      ),
    );
  }
}
