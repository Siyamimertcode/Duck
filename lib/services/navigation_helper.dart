import 'package:flutter/material.dart';
import 'user_preferences.dart';

class NavigationHelper {
  NavigationHelper._();

  static Future<void> safePopOrHome(
    BuildContext context, {
    Object? result,
  }) async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
      return;
    }

    final userName = await UserPreferences.getUserName() ?? 'Kullanıcı';
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed('/home', arguments: userName);
  }
}
