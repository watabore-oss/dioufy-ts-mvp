import 'package:flutter/material.dart';

class DioufyTheme {
  static const Color deepBlue = Color(0xFF0F172A);
  static const Color trustBlue = Color(0xFF1E3A8A);
  static const Color actionBlue = Color(0xFF2563EB);
  static const Color gold = Color(0xFFFBBF24);
  static const Color emerald = Color(0xFF059669);

  static ThemeData get light => ThemeData(
        primaryColor: trustBlue,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      );
}
