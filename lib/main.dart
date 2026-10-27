import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'localization/app_localizations.dart';
import 'localization/language_provider.dart';
import 'services/fcm_service.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('Root .env loaded successfully.');
  } catch (error) {
    debugPrint('Could not load root .env: $error');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const defineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const defineSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  final envSupabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
  final envSupabasePublishableKey =
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';
  final supabaseUrl = defineSupabaseUrl.trim().isNotEmpty
      ? defineSupabaseUrl.trim()
      : envSupabaseUrl;
  final supabasePublishableKey = defineSupabasePublishableKey.trim().isNotEmpty
      ? defineSupabasePublishableKey.trim()
      : envSupabasePublishableKey;
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  } else {
    debugPrint(
      'Supabase was not initialized. Check the root .env file or provide '
      'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY using --dart-define.',
    );
  }

  // Use live Firebase services by default. Opt into local emulators explicitly
  // when needed for isolated development testing.
  const useFunctionsEmulator = bool.fromEnvironment(
    'USE_FUNCTIONS_EMULATOR',
    defaultValue: false,
  );
  const configuredEmulatorHost = String.fromEnvironment(
    'FUNCTIONS_EMULATOR_HOST',
  );

  if (kDebugMode && useFunctionsEmulator) {
    final defaultHost =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    final host = configuredEmulatorHost.isNotEmpty
        ? configuredEmulatorHost
        : defaultHost;

    FirebaseAuth.instance.useAuthEmulator(host, 9199);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8180);
    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator(host, 5101);

    debugPrint('Using local Firebase emulators at $host');
  }

  await FcmService.instance.initialize();

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
