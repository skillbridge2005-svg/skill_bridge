import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/theme_provider.dart';
import '../../localization/app_localizations.dart';
import 'language_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF4F46E5),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            elevation: 0,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                'Dark Mode',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                themeProvider.isDarkMode
                    ? 'Dark theme is enabled'
                    : 'Light theme is enabled',
              ),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (_) {
                  context.read<ThemeProvider>().toggleTheme();
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'LANGUAGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF4F46E5),
            ),
          ),

          const SizedBox(height: 10),

          Card(
            elevation: 0,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                'Language',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(l10n.selectLanguage),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LanguageScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
