import 'package:flutter/material.dart';
import '../core/routes.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.currentRoute,
    required this.brand,
    required this.logoPath,
    this.appName = 'OrBird AI',
  });

  final String? currentRoute;
  final Color brand;
  final String logoPath;
  final String appName;

  void _go(BuildContext context, String route) {
    if (currentRoute == route) {
      Navigator.pop(context); // solo cierra
      return;
    }
    Navigator.pop(context); // cierra drawer
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header pro
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 54, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  brand,
                  brand.withOpacity(.92),
                  const Color(0xFF05305A),
                ],
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 46,
                    height: 46,
                    color: Colors.white.withOpacity(.12),
                    child: Image.asset(
                      logoPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.podcasts_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          _DrawerItem(
            icon: Icons.home_rounded,
            label: 'Inicio',
            selected: currentRoute == Routes.home,
            onTap: () => _go(context, Routes.home),
            brand: brand,
          ),
          _DrawerItem(
            icon: Icons.graphic_eq_rounded,
            label: 'Grabaciones',
            selected: currentRoute == Routes.recordings,
            onTap: () => _go(context, Routes.recordings),
            brand: brand,
          ),
          _DrawerItem(
            icon: Icons.photo_library_rounded,
            label: 'Colección',
            selected:
                currentRoute ==
                Routes.history, // ajusta si tu colección tiene otra ruta
            onTap: () => _go(context, Routes.history),
            brand: brand,
          ),
          _DrawerItem(
            icon: Icons.help_outline_rounded,
            label: 'Ayuda',
            selected: currentRoute == Routes.help,
            onTap: () => _go(context, Routes.help),
            brand: brand,
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _DrawerItem(
              icon: Icons.settings_rounded,
              label: 'Configuración',
              selected: currentRoute == Routes.settings,
              onTap: () => _go(context, Routes.settings),
              brand: brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.brand,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? brand.withOpacity(.10) : Colors.transparent;
    final fg = selected ? brand : Colors.black.withOpacity(.70);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black.withOpacity(.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
