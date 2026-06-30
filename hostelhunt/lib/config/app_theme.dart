import 'package:flutter/material.dart';

class AppTheme {

  static ThemeData lightTheme = ThemeData(

    useMaterial3: true,

    colorSchemeSeed: Colors.blue,

    scaffoldBackgroundColor: Colors.white,

    appBarTheme: const AppBarTheme(

      centerTitle: true,

      elevation: 0,

      backgroundColor: Colors.blue,

      foregroundColor: Colors.white,

    ),

    inputDecorationTheme: InputDecorationTheme(

      border: OutlineInputBorder(

        borderRadius: BorderRadius.circular(12),

      ),

    ),

    elevatedButtonTheme: ElevatedButtonThemeData(

      style: ElevatedButton.styleFrom(

        minimumSize: const Size(double.infinity, 55),

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(12),

        ),

      ),

    ),

  );

}