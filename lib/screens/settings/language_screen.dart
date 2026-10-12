import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/app_localizations.dart';
import '../../localization/language_provider.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageProvider = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.selectLanguage,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _languageTile(
              context,
              title: l10n.english,
              subtitle: 'English',
              locale: const Locale('en'),
              isSelected: languageProvider.locale.languageCode == 'en',
            ),
            _languageTile(
              context,
              title: l10n.marathi,
              subtitle: 'मराठी',
              locale: const Locale('mr'),
              isSelected: languageProvider.locale.languageCode == 'mr',
            ),
            _languageTile(
              context,
              title: l10n.hindi,
              subtitle: 'हिंदी',
              locale: const Locale('hi'),
              isSelected: languageProvider.locale.languageCode == 'hi',
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Locale locale,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 6,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEEF2FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.language_rounded,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF6B7280),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5))
              : const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
          onTap: () {
            context.read<LanguageProvider>().changeLanguage(locale);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
