import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skill_bridge/screens/splash_screen.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Connect Firebase Cloud Functions to local emulator
  // for development/testing on physical Android phone.
  if (kDebugMode) {
    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator('10.44.128.192', 5001);
  }

  runApp(const SkillBridgeApp());
}

class SkillBridgeApp extends StatelessWidget {
  const SkillBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillBridge',
      home: const SkillBridgeSplashScreen(),
    );
  }
}
