import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Primary Firebase.initializeApp error: $e');
    try {
      // Fallback: initialize using native configuration (google-services.json)
      await Firebase.initializeApp();
    } catch (fallbackError) {
      debugPrint('Fallback Firebase.initializeApp error: $fallbackError');
    }
  }

  runApp(const HostelHuntApp());
}