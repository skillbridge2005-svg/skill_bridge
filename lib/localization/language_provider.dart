import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void changeLanguage(Locale locale) {
    if (_locale.languageCode == locale.languageCode) {
      return;
    }

    _locale = locale;
    notifyListeners();
  }
}
