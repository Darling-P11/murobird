import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Paleta
const kBrand = Color(0xFF10A37F);
const kBrandDark = Color(0xFF0C7D60);
const kBg = Color(0xFFF4FAF8);
const kNavBg = Color(0xFFEAF6F2);
const kText = Color(0xFF2F3B3A);
const kDivider = Color(0xFFDAE7E3);

ThemeData buildBirbyTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    primary: kBrand,
    onPrimary: Colors.white,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBg,

    // 👇 CLAVE: fuerza status bar blanca cuando haya AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: kBrand,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Android -> iconos blancos
        statusBarBrightness: Brightness.dark, // iOS -> texto blanco
      ),
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w900, color: kText),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: kText),
      bodyMedium: TextStyle(color: kText, height: 1.36),
      labelLarge: TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}
