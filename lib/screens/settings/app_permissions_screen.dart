// lib/screens/settings/app_permissions_screen.dart
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/routes.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  static const Color _brand = Color(0xFF001225);

  PermissionStatus mic = PermissionStatus.denied;
  PermissionStatus storage = PermissionStatus.denied;
  PermissionStatus photos = PermissionStatus.denied; // iOS
  PermissionStatus media = PermissionStatus.denied; // Android 13+
  PermissionStatus location = PermissionStatus.denied;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    setState(() => _loading = true);

    final micS = await Permission.microphone.status;

    PermissionStatus storageS = PermissionStatus.denied;
    PermissionStatus photosS = PermissionStatus.denied;
    PermissionStatus mediaS = PermissionStatus.denied;

    if (Platform.isAndroid) {
      // Android 13+ (imágenes) se suele mapear con Permission.photos
      mediaS = await Permission.photos.status;
      storageS = await Permission.storage.status; // compat < 13
    } else if (Platform.isIOS) {
      photosS = await Permission.photos.status;
    }

    final locS = await Permission.locationWhenInUse.status;

    if (!mounted) return;
    setState(() {
      mic = micS;
      storage = storageS;
      photos = photosS;
      media = mediaS;
      location = locS;
      _loading = false;
    });
  }

  Future<void> _request(Permission p) async {
    await p.request();
    await _refreshStatuses();
  }

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
                      const Text(
                        'Permisos de la app',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: .2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Administra los permisos necesarios para grabar y consultar información.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== CONTENIDO =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
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
                              'Permisos',
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

                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 26, bottom: 26),
                          child: CircularProgressIndicator(),
                        )
                      else ...[
                        _GlassCard(
                          child: _PermCard(
                            brand: _brand,
                            title: 'Micrófono',
                            icon: Icons.mic_rounded,
                            description:
                                'Necesario para detectar aves mediante audio en tiempo real.',
                            status: mic,
                            onRequest: () => _request(Permission.microphone),
                          ),
                        ),
                        const SizedBox(height: 12),

                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 14),

                      // Nota
                      Text(
                        'Puedes modificar estos permisos en cualquier momento desde los Ajustes del sistema.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.80),
                          fontWeight: FontWeight.w600,
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

                      const SizedBox(height: 8),
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

/* ===================== Permission Card ===================== */

class _PermCard extends StatelessWidget {
  final Color brand;
  final String title;
  final IconData icon;
  final String description;
  final PermissionStatus status;
  final VoidCallback onRequest;
  final bool showIfDeniedOnly;

  const _PermCard({
    required this.brand,
    required this.title,
    required this.icon,
    required this.description,
    required this.status,
    required this.onRequest,
    this.showIfDeniedOnly = false,
  });

  bool get _isGranted => status == PermissionStatus.granted;

  bool get _isHardDenied =>
      status == PermissionStatus.permanentlyDenied ||
      status == PermissionStatus.restricted;

  Color _chipColor() {
    if (_isGranted) return const Color(0xFF1DB954);
    if (status == PermissionStatus.limited) return const Color(0xFFFFA000);
    return const Color(0xFFFF6B6B);
  }

  String _statusText() {
    switch (status) {
      case PermissionStatus.granted:
        return 'Concedido';
      case PermissionStatus.limited:
        return 'Limitado';
      case PermissionStatus.denied:
        return 'Denegado';
      case PermissionStatus.restricted:
        return 'Restringido';
      case PermissionStatus.permanentlyDenied:
        return 'Bloqueado';
      default:
        return status.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showIfDeniedOnly && _isGranted) {
      // Oculta tarjetas “opcionales” si ya está concedido
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(.92)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.95),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _StatusChip(color: _chipColor(), label: _statusText()),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(.85),
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  brand: brand,
                  icon: Icons.security_rounded,
                  label: _isHardDenied ? 'Abrir ajustes' : 'Solicitar permiso',
                  onTap: () async {
                    if (_isHardDenied) {
                      await openAppSettings();
                    } else {
                      onRequest();
                    }
                  },
                  filled: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  brand: brand,
                  icon: Icons.open_in_new_rounded,
                  label: 'Ajustes',
                  onTap: () async => openAppSettings(),
                  filled: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.45), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final Color brand;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ActionBtn({
    required this.brand,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? Colors.white.withOpacity(.14) : Colors.transparent;
    final bd = Colors.white.withOpacity(.18);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bd, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
