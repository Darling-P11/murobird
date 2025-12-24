// lib/screens/home/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/routes.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _brand = Color(0xFF001225);

  bool _offlinePrefEnabled = false;
  bool _noInternet = false;
  late final Stream<List<ConnectivityResult>> _connStream;

  @override
  void initState() {
    super.initState();
    _loadOfflinePref();

    _connStream = Connectivity().onConnectivityChanged;
    _connStream.listen((results) {
      final noNet = results.contains(ConnectivityResult.none);
      if (mounted) setState(() => _noInternet = noNet);
    });

    Connectivity().checkConnectivity().then((r) {
      if (mounted) setState(() => _noInternet = (r == ConnectivityResult.none));
    });
  }

  Future<void> _loadOfflinePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('offline_enabled') ?? false;
      if (mounted) setState(() => _offlinePrefEnabled = enabled);
    } catch (_) {
      if (mounted) setState(() => _offlinePrefEnabled = false);
    }
  }

  bool get _showOfflineBanner => _offlinePrefEnabled || _noInternet;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return BottomNavScaffold(
      //index: null,
      child: Stack(
        children: [
          // ===== Fondo suave =====
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
              // ===== HERO HEADER (nuevo) =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, top + 10, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        children: [
                          Builder(
                            builder: (context) => _HeaderIconButton(
                              icon: Icons.grid_view_rounded, // dashboard/menu
                              onTap: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                          const Spacer(),
                          _LogoPill(
                            brand: _brand,
                            logoPath: 'assets/images/orbird_ai_blanco.png',
                            title: 'OrBird AI',
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // Título + subtítulo
                      // Título + subtítulo (centrado + responsive)
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Detecta aves por su canto',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Text(
                                'Graba en tiempo real o sube un audio y te mostramos la especie con su información.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.82),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Chips de estado (nuevo)
                      // Chips de estado (centrados + ocupan ancho)
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _StatusChip(
                              icon: Icons.mic_rounded,
                              label: 'Audio',
                              color: Colors.white.withOpacity(.12),
                              border: Colors.white.withOpacity(.20),
                            ),
                            _StatusChip(
                              icon: Icons.graphic_eq_rounded,
                              label: 'Espectro',
                              color: Colors.white.withOpacity(.12),
                              border: Colors.white.withOpacity(.20),
                            ),
                            _StatusChip(
                              icon: _showOfflineBanner
                                  ? Icons.wifi_off_rounded
                                  : Icons.wifi_rounded,
                              label: _showOfflineBanner ? 'Offline' : 'Online',
                              color: _showOfflineBanner
                                  ? const Color(0xFFB00020).withOpacity(.18)
                                  : const Color(0xFF00C2FF).withOpacity(.16),
                              border: _showOfflineBanner
                                  ? const Color(0xFFFF6B6B).withOpacity(.45)
                                  : const Color(0xFF7AE3FF).withOpacity(.35),
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Card con Lottie (nuevo estilo)
                      _GlassCard(
                        child: SizedBox(
                          height: 150,
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 14),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Listo para escuchar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tip: acerca el micrófono a la fuente del sonido.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.78),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 10,
                                  left: 8,
                                ),
                                child: SizedBox(
                                  width: 110,
                                  child: Lottie.asset(
                                    'assets/mock/bird.json',
                                    fit: BoxFit.contain,
                                  ),
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

              // ===== CONTENIDO PRINCIPAL =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Separador nuevo
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
                              'Selecciona una opción',
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
                      const SizedBox(height: 25),

                      _PrimaryCTA(
                        brand: _brand,
                        title: 'Tiempo real',
                        subtitle: 'Escucha el canto y detecta al instante',
                        icon: Icons.wifi_tethering_rounded,
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.realtime),
                      ),
                      const SizedBox(height: 14),

                      _SecondaryCTA(
                        brand: _brand,
                        title: 'Subir audio',
                        subtitle: 'Analiza un archivo y obtén la especie',
                        icon: Icons.upload_rounded,
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.upload),
                      ),

                      const SizedBox(height: 16),

                      if (_showOfflineBanner) ...[
                        _OfflineBanner(
                          brand: _brand,
                          message: _noInternet
                              ? 'Sin internet: se activó el modo offline'
                              : 'Modo offline activado',
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ===== FOOTER ORBIX (aquí va) =====
                      const SizedBox(height: 1),
                      Center(
                        child: Opacity(
                          opacity: 0.35,
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/BANNER_inferior.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================== COMPONENTES UI (NUEVOS) =====================

class _LogoPill extends StatelessWidget {
  final Color brand;
  final String logoPath;
  final String title;

  const _LogoPill({
    required this.brand,
    required this.logoPath,
    required this.title,
  });

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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color border;
  final Color? textColor;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.border,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = textColor ?? Colors.white.withOpacity(.92);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tc),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: tc,
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

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(.16), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  final Color brand;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryCTA({
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: brand,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brand, brand.withOpacity(.92), const Color(0xFF05305A)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.80),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.8,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class _MiniCard extends StatelessWidget {
  final Color brand;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniCard({
    required this.brand,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(.06), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: brand.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.black.withOpacity(.78),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.black.withOpacity(.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final Color brand;
  final String message;

  const _OfflineBanner({required this.brand, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAEA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B6B), width: 1.3),
      ),
      child: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFB00020)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo offline activado',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFFB00020),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSheet extends StatelessWidget {
  final Color brand;
  const _InfoSheet({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.podcasts_rounded, color: brand),
              const SizedBox(width: 10),
              Text(
                'OrBird AI',
                style: TextStyle(
                  color: brand,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Identifica aves mediante un extracto de audio capturado por micrófono o archivo.',
            style: TextStyle(
              color: Colors.black.withOpacity(.72),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
