import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'screens/splash/splash_screen.dart';

class HostelHuntApp extends StatelessWidget {

  const HostelHuntApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: "HostelHunt",

      theme: AppTheme.lightTheme,

      home: const SplashScreen(),

    );
  }
}