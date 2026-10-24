import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'localization/app_localizations.dart';
import 'localization/language_provider.dart';
import 'theme/theme_provider.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Forward the current Firebase ID token to Supabase.
  await Supabase.initialize(
    url: 'https://qfrzqhyqfrhwkfkgskrn.supabase.co',
    publishableKey: 'sb_publishable_M8oF_cwH2NNZFXeFyc-Ulg_xX2dL6os',

    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('SUPABASE AUTH: No Firebase user is signed in.');
        return null;
      }

      final token = await user.getIdToken();

      if (token == null) {
        debugPrint('SUPABASE AUTH: Token is null.');
        return null;
      }

      debugPrint('SUPABASE AUTH: Firebase token available = true');
      debugPrint('SUPABASE AUTH: User UID = ${user.uid}');

      // Decode the JWT payload locally; never print the complete token.
      final parts = token.split('.');

      if (parts.length == 3) {
        try {
          final normalized = base64Url.normalize(parts[1]);
          final payload = utf8.decode(base64Url.decode(normalized));
          final claims = jsonDecode(payload) as Map<String, dynamic>;

          debugPrint('SUPABASE JWT CLAIMS:');
          debugPrint('  issuer (iss): ${claims['iss']}');
          debugPrint('  audience (aud): ${claims['aud']}');
          debugPrint('  subject (sub): ${claims['sub']}');
          debugPrint('  role: ${claims['role'] ?? 'MISSING'}');
          debugPrint('  firebase project: ${claims['firebase']}');
        } catch (e) {
          debugPrint('SUPABASE AUTH: Could not decode JWT claims: $e');
        }
      }

      return token;
    },
  );

  // In debug builds, call the local Functions emulator.
  // Android emulators reach the host via 10.0.2.2; desktop/web use localhost.
  if (kDebugMode) {
    final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? '10.0.2.2'
        : '127.0.0.1';

    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator(host, 5001);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
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

      // Language
      locale: context.watch<LanguageProvider>().locale,

      supportedLocales: const [Locale('en'), Locale('mr'), Locale('hi')],

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
      ),

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
      ),

      // Current theme
      themeMode: context.watch<ThemeProvider>().themeMode,

      // Splash → AuthWrapper → appropriate screen
      home: const SkillBridgeSplashScreen(),
    );
  }
}
