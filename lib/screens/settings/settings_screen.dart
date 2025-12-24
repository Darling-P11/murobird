// lib/screens/settings/settings_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/routes.dart';
import '../../offline/offline_prefs.dart';
import '../../offline/offline_manager.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _brand = Color(0xFF001225);

  // Demo
  bool _darkMode = false;
  bool _haptics = true;
  bool _uiSounds = false;
  bool _tips = true;

  // Prefs reales
  bool _saveAuto = false;
  bool _offlineEnabled = false;

  // Offline manager
  bool _busy = false;
  double _progress = 0.0;
  String _verifyMsg = '';

  String _language = 'es';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _offlineEnabled = await OfflinePrefs.enabled;
    _saveAuto = await OfflinePrefs.autoSaveRecordings;
    if (mounted) setState(() {});
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _progress = 0.0;
    });

    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sin conexión para descargar')),
          );
        }
        return;
      }

      await OfflineManager.downloadAndInstallWithProgress((p) {
        if (!mounted) return;
        setState(() => _progress = p.clamp(0.0, 1.0));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paquete offline instalado')),
        );
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('DESCARGA OFFLINE ERROR: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _ok(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onOk,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onOk();
            },
            style: FilledButton.styleFrom(backgroundColor: _brand),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return BottomNavScaffold(
      child: Stack(
        children: [
          // Fondo Home-like
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

                      // Título centrado
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Configuración',
                              textAlign: TextAlign.center,
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
                              'Personaliza la app, permisos y modo offline.',
                              textAlign: TextAlign.center,
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

                      const SizedBox(height: 14),

                      // Chips centrados (estado)
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _StatusChip(
                              icon: _offlineEnabled
                                  ? Icons.wifi_off_rounded
                                  : Icons.wifi_rounded,
                              label: _offlineEnabled ? 'Offline' : 'Online',
                              danger: _offlineEnabled,
                            ),
                            _StatusChip(
                              icon: Icons.save_alt_rounded,
                              label: _saveAuto
                                  ? 'Auto-guardado ON'
                                  : 'Auto-guardado OFF',
                            ),
                            if (_busy)
                              _StatusChip(
                                icon: Icons.downloading_rounded,
                                label: _progress == 0
                                    ? 'Descargando…'
                                    : '${(_progress * 100).toStringAsFixed(0)}%',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== CONTENIDO (cards) =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    children: [
                      // Separador “Selecciona una opción” (blanco)
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
                              'Ajustes principales',
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

                      // ===== Aplicación =====
                      _GlassCard(
                        child: _Section(
                          brand: _brand,
                          title: 'Aplicación',
                          icon: Icons.apps_rounded,
                          child: Column(
                            children: [
                              _NavTile(
                                brand: _brand,
                                icon: Icons.info_outline,
                                title: 'Acerca de OrBird AI',
                                subtitle: 'Versión 1.0',
                                onTap: () =>
                                    Navigator.pushNamed(context, Routes.about),
                              ),
                              const _SoftDivider(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== Preferencias =====
                      _GlassCard(
                        child: _Section(
                          brand: _brand,
                          title: 'Preferencias',
                          icon: Icons.tune_rounded,
                          child: Column(
                            children: [
                              _SwitchTile(
                                brand: _brand,
                                icon: Icons.cloud_off_rounded,
                                title: 'Modo offline',
                                subtitle: 'Prioriza datos locales',
                                value: _offlineEnabled,
                                onChanged: (v) async {
                                  await OfflinePrefs.setEnabled(v);
                                  setState(() => _offlineEnabled = v);
                                  _ok(
                                    v
                                        ? 'Modo offline ACTIVADO'
                                        : 'Modo offline DESACTIVADO',
                                  );
                                },
                              ),
                              const _SoftDivider(),
                              _SwitchTile(
                                brand: _brand,
                                icon: Icons.save_alt_rounded,
                                title: 'Guardar grabaciones automáticamente',
                                subtitle: 'Se guardan al finalizar',
                                value: _saveAuto,
                                onChanged: (v) async {
                                  await OfflinePrefs.setAutoSaveRecordings(v);
                                  setState(() => _saveAuto = v);
                                  _ok(
                                    v
                                        ? 'Auto-guardado ACTIVADO'
                                        : 'Auto-guardado DESACTIVADO',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== Permisos =====
                      _GlassCard(
                        child: _Section(
                          brand: _brand,
                          title: 'Permisos y privacidad',
                          icon: Icons.privacy_tip_outlined,
                          child: Column(
                            children: [
                              _NavTile(
                                brand: _brand,
                                icon: Icons.mic_rounded,
                                title: 'Permisos de la app',
                                subtitle: 'Micrófono y otros',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  Routes.appPermissions,
                                ),
                              ),
                              const _SoftDivider(),
                              _NavTile(
                                brand: _brand,
                                icon: Icons.policy_rounded,
                                title: 'Política de privacidad',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  Routes.privacy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ===== Datos locales =====
                      _GlassCard(
                        child: _Section(
                          brand: _brand,
                          title: 'Datos locales',
                          icon: Icons.storage_rounded,
                          child: Column(
                            children: [
                              _ActionTile(
                                brand: _brand,
                                icon: Icons.download_rounded,
                                title: 'Descargar/actualizar paquete offline',
                                subtitle: 'Imágenes, audios y mapas',
                                busy: _busy,
                                onTap: _busy ? null : _download,
                              ),

                              if (_busy || _progress > 0)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    0,
                                    14,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: _busy
                                              ? (_progress == 0
                                                    ? null
                                                    : _progress)
                                              : _progress,
                                          minHeight: 8,
                                          backgroundColor: Colors.white
                                              .withOpacity(.15),
                                          color: Colors.white.withOpacity(.90),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _busy
                                            ? (_progress == 0
                                                  ? 'Preparando descarga...'
                                                  : 'Progreso: ${(_progress * 100).toStringAsFixed(0)}%')
                                            : 'Último progreso: ${(_progress * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(.78),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const _SoftDivider(),

                              _NavTile(
                                brand: _brand,
                                icon: Icons.verified_rounded,
                                title: 'Verificar descarga',
                                subtitle: _verifyMsg.isEmpty
                                    ? 'Comprobar si está instalado correctamente'
                                    : _verifyMsg,
                                trailing: const Icon(Icons.refresh_rounded),
                                onTap: () async {
                                  final info =
                                      await OfflineManager.verifyInstall();
                                  final ready = await OfflineManager.isReady();
                                  final msg = StringBuffer()
                                    ..writeln(
                                      ready
                                          ? 'Instalación: OK'
                                          : 'Instalación: NO LISTA',
                                    )
                                    ..writeln(
                                      'Ruta base: ${info['base_dir'] ?? '-'}',
                                    )
                                    ..writeln(
                                      'DB: ${info['db_exists'] ? 'sí' : 'no'}',
                                    )
                                    ..writeln(
                                      'Especies: ${info['count_species']}',
                                    )
                                    ..writeln(
                                      'Assets muestra: ${info['assets_ok'] ? 'ok' : 'faltan'}',
                                    );
                                  setState(
                                    () => _verifyMsg = msg.toString().trim(),
                                  );
                                  _ok(
                                    ready
                                        ? 'Offline listo'
                                        : 'Offline incompleto',
                                  );
                                },
                              ),

                              const _SoftDivider(),

                              _DangerTile(
                                title: 'Eliminar paquete offline',
                                onTap: () => _confirm(
                                  context,
                                  title: 'Eliminar paquete offline',
                                  message:
                                      'Se eliminarán los datos descargados (imágenes, audios y mapas). ¿Deseas continuar?',
                                  onOk: () async {
                                    setState(() {
                                      _progress = 0.0;
                                      _verifyMsg = '';
                                    });
                                    await OfflineManager.uninstall();
                                    _ok('Paquete offline eliminado');
                                  },
                                ),
                              ),
                            ],
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
                                width: 64,
                                height: 64,
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

/* ===================== Components (Home-like) ===================== */

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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _StatusChip({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? const Color(0xFFB00020).withOpacity(.18)
        : Colors.white.withOpacity(.12);
    final br = danger
        ? const Color(0xFFFF6B6B).withOpacity(.45)
        : Colors.white.withOpacity(.20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: br, width: 1),
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

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.white.withOpacity(.10));
  }
}

class _Section extends StatelessWidget {
  final Color brand;
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.brand,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
          child,
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final Color brand;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavTile({
    required this.brand,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(.14),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(.92), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.95),
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.72),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.2,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(.85),
                ),
          ],
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final Color brand;
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback onTap;

  const _RowTile({
    required this.brand,
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(.14),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(.92), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(.95),
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final Color brand;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.brand,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(.14),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(.92), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.95),
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.72),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.2,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(.35),
            inactiveThumbColor: Colors.white.withOpacity(.80),
            inactiveTrackColor: Colors.white.withOpacity(.12),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final Color brand;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.brand,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(.14),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(.92), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.95),
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.72),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.2,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(.85),
              ),
          ],
        ),
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _DangerTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFB00020).withOpacity(.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFF6B6B).withOpacity(.45),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(.90),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillValue extends StatelessWidget {
  final String value;
  const _PillValue({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.20), width: 1),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: Colors.white.withOpacity(.92),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: .2,
        ),
      ),
    );
  }
}
