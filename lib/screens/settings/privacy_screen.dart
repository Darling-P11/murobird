// lib/screens/settings/privacy_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/routes.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const Color _brand = Color(0xFF001225);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    void goBack() {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      } else {
        nav.pushReplacementNamed(Routes.home);
      }
    }

    return BottomNavScaffold(
      child: Stack(
        children: [
          // Fondo igual al Home
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_brand, _brand.withOpacity(.92), Colors.white],
                stops: const [0, .42, 1],
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ===== HERO HEADER =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, top + 10, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // top bar
                      Row(
                        children: [
                          _HeaderIconButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: goBack,
                          ),
                          const Spacer(),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Título centrado
                      Center(
                        child: Text(
                          'Política de privacidad',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: .2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      Text(
                        'Cómo se usan y protegen los datos dentro de la aplicación.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // ===== CONTENIDO =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    children: [
                      // Separador blanco
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              thickness: 1.6,
                              color: Colors.white.withOpacity(.85),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Información',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.85),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              thickness: 1.6,
                              color: Colors.white.withOpacity(.85),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cards (glass)
                      const _GlassCard(
                        child: _Section(
                          icon: Icons.info_outline,
                          title: 'Introducción',
                          child: Text(
                            'Esta política explica de forma clara cómo la app administra la información durante el uso en línea y sin conexión. '
                            'El enfoque está en ofrecer una experiencia informativa y segura, con tratamiento responsable de los datos.',
                            style: TextStyle(height: 1.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const _GlassCard(
                        child: _Section(
                          icon: Icons.data_usage_rounded,
                          title: 'Datos utilizados',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'La aplicación usa únicamente lo necesario para funcionar correctamente:',
                                style: TextStyle(height: 1.3),
                              ),
                              SizedBox(height: 10),
                              _Bullet(
                                'Audios grabados por el usuario, cuando decide analizarlos o guardarlos.',
                              ),
                              _Bullet(
                                'Preferencias locales (idioma, modo offline y ajustes de uso).',
                              ),
                              _Bullet(
                                'Estado de conectividad, para determinar si hay acceso a servicios en línea.',
                              ),
                              SizedBox(height: 10),
                              Text(
                                'No se recopila información personal sensible, credenciales o identificadores privados.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const _GlassCard(
                        child: _Section(
                          icon: Icons.manage_search_rounded,
                          title: 'Finalidad del uso',
                          child: Text(
                            'La información local se emplea para brindar funciones internas como historial, almacenamiento de grabaciones y verificación de recursos descargados. '
                            'La app no vende, comparte ni transfiere estos datos a terceros.',
                            style: TextStyle(height: 1.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const _GlassCard(
                        child: _Section(
                          icon: Icons.cloud_off_rounded,
                          title: 'Modo offline',
                          child: Text(
                            'Cuando activas el modo offline, la app puede trabajar con recursos descargados (por ejemplo, imágenes, audios o datos de especies). '
                            'Ese contenido se guarda únicamente en tu dispositivo y puedes eliminarlo cuando quieras desde Configuración.',
                            style: TextStyle(height: 1.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const _GlassCard(
                        child: _Section(
                          icon: Icons.security_rounded,
                          title: 'Control del usuario',
                          child: Text(
                            'Puedes revisar y borrar datos locales en cualquier momento. '
                            'No se realiza seguimiento del comportamiento del usuario ni almacenamiento en servidores externos como requisito para usar la app.',
                            style: TextStyle(height: 1.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const _GlassCard(
                        child: _Section(
                          icon: Icons.mail_outline_rounded,
                          title: 'Contacto',
                          child: Text(
                            'Si necesitas ayuda o deseas realizar consultas sobre esta política, puedes contactarnos:\n\n'
                            'Creador: Orbix Labs\n'
                            'Email: orbixec.soporte@gmail.com',
                            style: TextStyle(height: 1.3),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Footer Orbix
                      Center(
                        child: Opacity(
                          opacity: 0.55,
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/logo_orbix.png',
                                width: 62,
                                height: 62,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Desarrollado por Orbix',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              const SliverFillRemaining(
                hasScrollBody: false,
                child: SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ===================== UI Helpers (Home-like) ===================== */

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _LogoPill extends StatelessWidget {
  final String logoPath;
  final String title;
  const _LogoPill({required this.logoPath, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            logoPath,
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.podcasts_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(.16), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(.92)),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(.95),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DefaultTextStyle(
            style: TextStyle(
              color: Colors.white.withOpacity(.88),
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Colors.white.withOpacity(.85),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(.88),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
