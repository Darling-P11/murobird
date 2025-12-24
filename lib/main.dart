import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Fuerza íconos blancos en la status bar (hora, wifi, batería)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // transparente
      statusBarIconBrightness: Brightness.light, // ANDROID → iconos blancos
      statusBarBrightness: Brightness.dark, // IOS → texto blanco
    ),
  );

  runApp(const BirbyApp());
}
