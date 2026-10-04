import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skill_bridge/screens/splash_screen.dart';

import 'firebase_options.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'localization/app_localizations.dart';
import 'localization/language_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Connect Firebase Cloud Functions to local emulator
  // for development/testing on physical Android phone.
  if (kDebugMode) {
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    if (kIsWeb) {
      functions.useFunctionsEmulator('127.0.0.1', 5001);
    } else {
      functions.useFunctionsEmulator('10.44.128.192', 5001);
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: const SkillBridgeApp(),
    ),
  );
}

class SkillBridgeApp extends StatelessWidget {
  const SkillBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillBridge',
      home: const SkillBridgeSplashScreen(),

      locale: context.watch<LanguageProvider>().locale,

      supportedLocales: const [Locale('en'), Locale('mr'), Locale('hi')],

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
    );
  }
}
