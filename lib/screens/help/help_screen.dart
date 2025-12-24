// lib/screens/help/help_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const Color _brand = Color(0xFF001225);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return BottomNavScaffold(
      child: Stack(
        children: [
          // ===== Fondo suave (igual Home) =====
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
                      // Top bar: menu izquierda + logo derecha
                      Row(
                        children: [
                          Builder(
                            builder: (context) => _HeaderIconButton(
                              icon: Icons.grid_view_rounded,
                              onTap: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Título + subtítulo centrados (igual estilo)
                      const SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Ayuda',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: .2,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Guía rápida, consejos y respuestas a preguntas frecuentes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color.fromRGBO(255, 255, 255, .82),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 1),
                    ],
                  ),
                ),
              ),

              // ===== CONTENIDO =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Separador (blanco)
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
                              'Guías y preguntas',
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
                      const SizedBox(height: 16),

                      // ===== Secciones en Glass Cards =====
                      _GlassSectionCard(
                        icon: Icons.rocket_launch_rounded,
                        title: 'Cómo empezar',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Bullet(
                              'Ve a “Tiempo real” para escuchar con el micrófono.',
                            ),
                            _Bullet(
                              'O toca “Subir audio” para analizar un archivo.',
                            ),
                            _Bullet(
                              'Otorga el permiso de micrófono cuando se solicite.',
                            ),
                            _Bullet(
                              'Mantén el teléfono estable y apunta hacia el ave.',
                            ),
                            _Bullet(
                              'Cuando la app identifique el canto, abre el resultado.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      _GlassSectionCard(
                        icon: Icons.tips_and_updates_rounded,
                        title: 'Consejos para mejores resultados',
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Bullet('Graba entre 10 y 30 segundos.'),
                            _Bullet(
                              'Evita viento fuerte y ruido de autos/voces.',
                            ),
                            _Bullet(
                              'Acércate (sin perturbar) y apunta el micrófono.',
                            ),
                            _Bullet('Si puedes, usa un protector antiviento.'),
                            _Bullet('En “Subir audio” usa formato .wav.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      _GlassSectionCard(
                        icon: Icons.help_outline_rounded,
                        title: 'Preguntas frecuentes',
                        child: Column(
                          children: const [
                            _Faq(
                              q: 'No identifica el ave, ¿qué hago?',
                              a: 'Acércate más, reduce ruido ambiente y prueba con otro fragmento del canto (10–30 s). Repite 2–3 veces.',
                            ),
                            _Faq(
                              q: '¿Necesito internet?',
                              a: 'Algunas funciones pueden requerir conexión según el modo de identificación y la descarga de información.',
                            ),
                            _Faq(
                              q: '¿Qué permisos usa?',
                              a: 'Micrófono para audio en tiempo real. Puedes gestionarlos desde Configuración del sistema.',
                            ),
                            _Faq(
                              q: '¿Qué formatos de audio admite?',
                              a: 'Recomendado: .wav. (Ajusta esto según tu backend/modelo).',
                            ),
                            _Faq(
                              q: '¿Cómo leo el espectrograma?',
                              a: 'Muestra el sonido en el tiempo: patrones y bandas indican energía por frecuencia; repeticiones suelen ser cantos.',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // CTA pequeño (opcional) para volver al Home
                      _SecondaryCTA(
                        brand: _brand,
                        title: 'Volver al inicio',
                        subtitle: 'Regresa a la pantalla principal',
                        icon: Icons.home_rounded,
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          Routes.home,
                        ),
                      ),

                      // ===== Footer Orbix =====
                      const SizedBox(height: 18),
                      Center(
                        child: Opacity(
                          opacity: 0.55,
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/logo_orbix.png',
                                width: 70,
                                height: 70,
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
                    ],
                  ),
                ),
              ),

              // evita huecos raros si el contenido es corto
              const SliverFillRemaining(
                hasScrollBody: false,
                child: SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================== UI helpers (mismo estilo del Home) =====================

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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(.92)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(.92),
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _GlassSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(.16), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

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
              color: Colors.white.withOpacity(.70),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.35,
                color: Colors.white.withOpacity(.90),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.q, required this.a});
  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white.withOpacity(.90),
        title: Text(
          q,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15.5,
            color: Colors.white.withOpacity(.95),
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              a,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: Colors.white.withOpacity(.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reutilizo el CTA secundario del estilo Home (código compacto aquí)
class _SecondaryCTA extends StatelessWidget {
  final Color brand;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryCTA({
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: brand.withOpacity(.16), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: brand.withOpacity(.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: brand.withOpacity(.14), width: 1),
                ),
                child: Icon(icon, color: brand, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: brand,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withOpacity(.62),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.8,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: brand.withOpacity(.85),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
