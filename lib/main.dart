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
import 'localization/app_localizations.dart';
import 'localization/language_provider.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables.
  try {
    await dotenv.load(fileName: '.env');

    if (kDebugMode) {
      debugPrint('Environment configuration loaded.');
    }
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Root .env could not be loaded: $error');
    }
  }

  // 2. Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    debugPrint('Firebase initialized successfully.');
  }

  // 3. Configure optional Firebase local emulators.
  // Live Firebase services are used by default.
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

    final host = configuredEmulatorHost.trim().isNotEmpty
        ? configuredEmulatorHost.trim()
        : defaultHost;

    FirebaseAuth.instance.useAuthEmulator(host, 9199);

    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      8180,
    );

    FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).useFunctionsEmulator(host, 5101);

    debugPrint('Using Firebase emulators at $host');
  }

  // 4. Read Supabase configuration.
  // --dart-define values take precedence over .env values.
  const defineSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );

  const defineSupabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  final envSupabaseUrl =
      dotenv.env['SUPABASE_URL']?.trim() ?? '';

  final envSupabasePublishableKey =
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';

  final supabaseUrl = defineSupabaseUrl.trim().isNotEmpty
      ? defineSupabaseUrl.trim()
      : envSupabaseUrl;

  final supabasePublishableKey =
      defineSupabasePublishableKey.trim().isNotEmpty
          ? defineSupabasePublishableKey.trim()
          : envSupabasePublishableKey;

  // 5. Initialize Supabase with the current Firebase ID token.
  if (supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,

        // Forward the signed-in Firebase user's ID token
        // for Supabase Third-Party Auth integration.
        accessToken: () async {
          final user = FirebaseAuth.instance.currentUser;

          if (user == null) {
            if (kDebugMode) {
              debugPrint(
                'Supabase auth: No Firebase user is signed in.',
              );
            }

            return null;
          }

          try {
            final token = await user.getIdToken();

            if (kDebugMode) {
              debugPrint(
                'Supabase auth: Firebase ID token retrieved.',
              );
            }

            return token;
          } catch (error) {
            if (kDebugMode) {
              debugPrint(
                'Supabase auth: Unable to retrieve Firebase token: $error',
              );
            }

            return null;
          }
        },
      );

      if (kDebugMode) {
        debugPrint('Supabase initialized successfully.');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Supabase initialization failed: $error');
      }
    }
  } else {
    if (kDebugMode) {
      debugPrint(
        'Supabase was not initialized. Configure SUPABASE_URL '
        'and SUPABASE_PUBLISHABLE_KEY in .env or --dart-define.',
      );
    }
  }

  // 6. Initialize Firebase Cloud Messaging.
  await FcmService.instance.initialize();

  // 7. Launch the application.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
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

      // Current language.
      locale: context.watch<LanguageProvider>().locale,

      supportedLocales: const [
        Locale('en'),
        Locale('mr'),
        Locale('hi'),
      ],

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Light theme.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
      ),

      // Dark theme.
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
      ),

      // Current theme.
      themeMode: context.watch<ThemeProvider>().themeMode,

      // Splash -> AuthWrapper -> appropriate screen.
      home: const SkillBridgeSplashScreen(),
    );
  }
}