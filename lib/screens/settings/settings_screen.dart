import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../offline/offline_prefs.dart';
import '../../offline/offline_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Estados demo (prototipo)
  bool _darkMode = false;
  bool _saveAuto = true;
  bool _haptics = true;
  bool _uiSounds = false;
  bool _tips = true;

  // Offline
  bool _offlineEnabled = false;
  bool _busy = false; // bloquea acciones mientras descarga
  double _progress = 0.0; // 0..1
  String _verifyMsg = ''; // resultado de verificación

  String _language = 'es';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _offlineEnabled = await OfflinePrefs.enabled;
    setState(() {});
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
      if (mounted) {
        // ignore: avoid_print
        print('DESCARGA OFFLINE ERROR: $e\n$st');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // Header consistente
          SliverAppBar(
            backgroundColor: kBrand,
            pinned: true,
            toolbarHeight: 96,
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Configuración',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                children: [
                  // ===== App / Perfil =====
                  _Card(
                    title: 'Aplicación',
                    icon: Icons.apps_rounded,
                    child: Column(
                      children: [
                        _NavTile(
                          leading: const Icon(
                            Icons.info_outline,
                            color: kBrand,
                          ),
                          title: 'Acerca de MuroBird',
                          subtitle: 'Versión 1.0.0 (demo)',
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.about),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Preferencias =====
                  _Card(
                    title: 'Preferencias',
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        // Switch Modo offline (persistente)
                        _SwitchTile(
                          leading: const Icon(
                            Icons.cloud_off_rounded,
                            color: kBrand,
                          ),
                          title: 'Modo offline',
                          subtitle:
                              'Usar datos locales y no consultar internet',
                          value: _offlineEnabled,
                          onChanged: (v) async {
                            await OfflinePrefs.setEnabled(v);
                            setState(() => _offlineEnabled = v);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  v
                                      ? 'Modo offline ACTIVADO (se priorizan datos locales).'
                                      : 'Modo offline DESACTIVADO (se usarán servicios online).',
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        _SwitchTile(
                          leading: const Icon(
                            Icons.save_alt_rounded,
                            color: kBrand,
                          ),
                          title: 'Guardar automáticamente las grabaciones',
                          subtitle: 'Se guardan en “Grabaciones” al finalizar',
                          value: _saveAuto,
                          onChanged: (v) => setState(() => _saveAuto = v),
                        ),
                        const Divider(height: 1),
                        // Otros switches que ya tenías podrían ir aquí...
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Permisos & Privacidad =====
                  _Card(
                    title: 'Permisos y privacidad',
                    icon: Icons.privacy_tip_outlined,
                    child: Column(
                      children: [
                        _NavTile(
                          leading: const Icon(Icons.mic_rounded, color: kBrand),
                          title: 'Permisos de la app',
                          subtitle: 'Micrófono y otros',
                          onTap: () => Navigator.pushNamed(
                            context,
                            Routes.appPermissions,
                          ),
                        ),
                        const Divider(height: 1),
                        _NavTile(
                          leading: const Icon(
                            Icons.policy_rounded,
                            color: kBrand,
                          ),
                          title: 'Política de privacidad',
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.privacy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Datos locales / mantenimiento =====
                  _Card(
                    title: 'Datos locales',
                    icon: Icons.storage_rounded,
                    child: Column(
                      children: [
                        // Descargar/actualizar paquete offline (con barra de progreso)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          leading: const Icon(
                            Icons.download_rounded,
                            color: kBrand,
                          ),
                          title: const Text(
                            'Descargar/actualizar paquete offline',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Imágenes, audios y mapas de especies',
                          ),
                          trailing: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: _busy ? null : _download,
                        ),

                        // Barra de progreso
                        if (_busy || _progress > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: _busy
                                      ? (_progress == 0 ? null : _progress)
                                      : _progress,
                                  backgroundColor: Colors.black12,
                                  color: kBrand,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _busy
                                      ? (_progress == 0
                                            ? 'Preparando descarga...'
                                            : 'Progreso: ${(_progress * 100).toStringAsFixed(0)}%')
                                      : 'Último progreso: ${(_progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const Divider(height: 1),

                        // Verificar instalación
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          leading: const Icon(
                            Icons.verified_rounded,
                            color: kBrand,
                          ),
                          title: const Text(
                            'Verificar descarga',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _verifyMsg.isEmpty
                                ? 'Comprobar si está instalado correctamente'
                                : _verifyMsg,
                          ),
                          trailing: const Icon(Icons.refresh_rounded),
                          onTap: () async {
                            final info = await OfflineManager.verifyInstall();
                            final ready = await OfflineManager.isReady();
                            final msg = StringBuffer()
                              ..writeln(
                                ready
                                    ? 'Instalación: OK'
                                    : 'Instalación: NO LISTA',
                              )
                              ..writeln('Ruta base: ${info['base_dir'] ?? '-'}')
                              ..writeln(
                                'DB: ${info['db_exists'] ? 'sí' : 'no'}',
                              )
                              ..writeln('Especies: ${info['count_species']}')
                              ..writeln(
                                'Assets muestra: ${info['assets_ok'] ? 'ok' : 'faltan'}',
                              );
                            setState(() => _verifyMsg = msg.toString().trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ready
                                      ? 'Offline listo'
                                      : 'Offline incompleto',
                                ),
                              ),
                            );
                          },
                        ),

                        const Divider(height: 1),

                        // Eliminar paquete offline
                        _DangerTile(
                          leading: const Icon(
                            Icons.delete_forever_rounded,
                            color: Colors.red,
                          ),
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

                        const Divider(height: 1),

                        // (Opcionales) tus acciones previas
                        _DangerTile(
                          leading: const Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.red,
                          ),
                          title: 'Borrar historial',
                          onTap: () => _confirm(
                            context,
                            title: 'Borrar historial',
                            message:
                                'Se eliminarán todas las entradas del historial. Esta acción no se puede deshacer.',
                            onOk: () => _ok('Historial borrado'),
                          ),
                        ),
                        const Divider(height: 1),
                        _DangerTile(
                          leading: const Icon(
                            Icons.delete_rounded,
                            color: Colors.red,
                          ),
                          title: 'Borrar grabaciones locales',
                          onTap: () => _confirm(
                            context,
                            title: 'Borrar grabaciones',
                            message:
                                'Se eliminarán las grabaciones guardadas en el dispositivo (demo).',
                            onOk: () => _ok('Grabaciones borradas'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),
                  // Nota de versión / copyright
                  const Text(
                    'MuroBird • prototipo UI\n© 2025',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
            style: FilledButton.styleFrom(backgroundColor: kBrand),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}

/* ======================= Widgets auxiliares ======================= */

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kBrand),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: trailing,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      secondary: leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
      activeColor: kBrand,
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.leading,
    required this.title,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
      onTap: onTap,
    );
  }
}
