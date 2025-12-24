import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/routes.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  static const Color _brand = Color(0xFF001225);

  Future<void> _requestMic(BuildContext context) async {
    final status = await Permission.microphone.request();

    if (!context.mounted) return;

    if (status.isGranted || status.isDenied) {
      Navigator.pushReplacementNamed(context, Routes.home);
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // ===== Fondo consistente =====
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_brand, _brand.withOpacity(.92), Colors.white],
            stops: const [0, .45, 1],
          ),
        ),

        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ===== Imagen del micrófono =====
              Image.asset(
                'assets/images/microfono.png', // <-- TU IMAGEN
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 28),

              // ===== Título =====
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Permitir acceso al micrófono',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ===== Descripción corta =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  'Se utiliza únicamente para identificar aves por su canto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.80),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ===== BOTÓN PRINCIPAL =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _requestMic(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _brand,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                    child: const Text('Permitir micrófono'),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ===== NO PERMITIR (SOLO TEXTO) =====
              GestureDetector(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, Routes.home),
                child: Text(
                  'No permitir',
                  style: TextStyle(
                    color: const Color.fromARGB(160, 0, 18, 37),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
