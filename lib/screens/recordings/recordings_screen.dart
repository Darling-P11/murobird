// lib/screens/recordings/recordings_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/routes.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  static const Color _brand = Color(0xFF001225);

  final TextEditingController _search = TextEditingController();
  final List<_Recording> _all = [];
  final Set<String> _selected = {};

  final AudioPlayer _player = AudioPlayer();
  String? _playingPath;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _player.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _player.dispose();
    super.dispose();
  }

  bool get selectionMode => _selected.isNotEmpty;

  List<_Recording> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((r) {
      final byQuery = q.isEmpty || r.name.toLowerCase().contains(q);
      return byQuery;
    }).toList();
  }

  Future<void> _loadRecordings() async {
    setState(() {
      _loading = true;
      _selected.clear();
    });

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/recordings');

    if (!await dir.exists()) {
      setState(() {
        _all.clear();
        _loading = false;
      });
      return;
    }

    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.wav'))
        .cast<File>()
        .toList();

    final items = <_Recording>[];
    for (final f in files) {
      try {
        final stat = await f.stat();
        final sizeBytes = stat.size;
        final dur = await _wavDuration(f);
        items.add(
          _Recording(
            id: f.path,
            path: f.path,
            name: _niceNameFromPath(f.path),
            dateTime: stat.modified,
            duration: dur,
            sizeMb: sizeBytes / (1024 * 1024),
            ext: '.wav',
          ),
        );
      } catch (_) {}
    }

    items.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    setState(() {
      _all
        ..clear()
        ..addAll(items);
      _loading = false;
    });
  }

  String _niceNameFromPath(String p) {
    final base = p.split(Platform.pathSeparator).last;
    return base.replaceAll('.wav', '');
  }

  Future<Duration> _wavDuration(File f) async {
    const sr = 16000;
    const ch = 1;
    const bits = 16;
    final length = await f.length();
    final dataBytes = math.max<int>(0, length - 44);
    final secs = dataBytes / (sr * ch * (bits / 8));
    return Duration(milliseconds: (secs * 1000).round());
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _deleteOne(_Recording r) async {
    try {
      final f = File(r.path);
      if (await f.exists()) await f.delete();

      setState(() => _all.removeWhere((e) => e.id == r.id));

      if (_playingPath == r.path) {
        await _player.stop();
        if (mounted) setState(() => _playingPath = null);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grabación eliminada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    final toDelete = _all.where((e) => _selected.contains(e.id)).toList();
    for (final r in toDelete) {
      await _deleteOne(r);
    }
    _selected.clear();
    setState(() {});
  }

  Future<void> _shareOne(_Recording r) async {
    try {
      await Share.shareXFiles([XFile(r.path)], text: r.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo compartir: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _playOrPause(_Recording r) async {
    if (_playingPath == r.path) {
      await _player.stop();
      setState(() => _playingPath = null);
      return;
    }

    if (_playingPath != null) {
      await _player.stop();
    }

    await _player.play(DeviceFileSource(r.path));
    setState(() => _playingPath = r.path);
  }

  void _reanalyze(_Recording r) {
    Navigator.pushNamed(context, Routes.searching, arguments: r.path);
  }

  void _showDetails(_Recording r) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: _brand),
                const SizedBox(width: 8),
                const Text(
                  'Detalles',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _kv('Nombre', r.name),
            _kv('Fecha', r.dateTime.formatNice()),
            _kv('Duración', r.duration.formatNice()),
            _kv('Tamaño', '${r.sizeMb.toStringAsFixed(2)} MB'),
            _kv('Ruta', r.path),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final items = _filtered;

    return BottomNavScaffold(
      child: Stack(
        children: [
          // ===== Fondo (igual Home) =====
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
                      // Top bar
                      Row(
                        children: [
                          Builder(
                            builder: (context) => _HeaderIconButton(
                              icon: selectionMode
                                  ? Icons.close_rounded
                                  : Icons.grid_view_rounded,
                              onTap: () {
                                if (selectionMode) {
                                  _clearSelection();
                                } else {
                                  Scaffold.of(context).openDrawer();
                                }
                              },
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
                            Text(
                              selectionMode
                                  ? '${_selected.length} seleccionada(s)'
                                  : 'Grabaciones',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectionMode
                                  ? 'Acciones masivas disponibles abajo.'
                                  : 'Reproduce, comparte o vuelve a analizar tus audios.',
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

                      // Chips de acción
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _StatusChip(
                              icon: Icons.library_music_rounded,
                              label: '${_all.length} audios',
                            ),
                            if (!selectionMode)
                              _StatusChip(
                                icon: Icons.refresh_rounded,
                                label: 'Actualizar',
                                onTap: _loadRecordings,
                              ),
                            if (selectionMode)
                              _StatusChip(
                                icon: Icons.delete_outline_rounded,
                                label: 'Eliminar',
                                danger: true,
                                onTap: _deleteSelected,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== BUSCADOR (glass) =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre…',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(.65),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white.withOpacity(.9),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ===== CONTENIDO =====
              if (_loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: _GlassCard(
                        child: SizedBox(
                          height: 110,
                          child: Row(
                            children: [
                              const SizedBox(width: 18),
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.8,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Cargando grabaciones…',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(.92),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (items.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 44),
                    child: _EmptyRecordingsModern(),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final r = items[i];
                    final selected = _selected.contains(r.id);
                    final isPlaying = _playingPath == r.path;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _RecordingTileModern(
                        brand: _brand,
                        recording: r,
                        selected: selected,
                        isPlaying: isPlaying,
                        selectionMode: selectionMode,
                        onTap: () {
                          if (selectionMode) {
                            _toggleSelect(r.id);
                          } else {
                            _playOrPause(r);
                          }
                        },
                        onLongPress: () => _toggleSelect(r.id),
                        onMore: () => _showDetails(r),
                        onDelete: () => _deleteOne(r),
                        onShare: () => _shareOne(r),
                        onReanalyze: () => _reanalyze(r),
                      ),
                    );
                  },
                ),

              // ===== Footer Orbix =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Center(
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

/* ============================ UI helpers ============================= */

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
  final VoidCallback? onTap;
  final bool danger;

  const _StatusChip({
    required this.icon,
    required this.label,
    this.onTap,
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

    final chip = Container(
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

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

/* ============================ Tiles modern ============================= */

class _RecordingTileModern extends StatelessWidget {
  const _RecordingTileModern({
    required this.brand,
    required this.recording,
    required this.selected,
    required this.isPlaying,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
    required this.onDelete,
    required this.onShare,
    required this.onReanalyze,
  });

  final Color brand;
  final _Recording recording;
  final bool selected;
  final bool isPlaying;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onReanalyze;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(.06), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                // Avatar (play / check)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? brand : brand.withOpacity(.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : brand.withOpacity(.14),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_rounded
                        : (isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded),
                    color: selected ? Colors.white : brand,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),

                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recording.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${recording.dateTime.formatNice()}  •  ${recording.duration.formatNice()}  •  ${recording.sizeMb.toStringAsFixed(2)} MB',
                        style: TextStyle(
                          color: Colors.black.withOpacity(.55),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Acciones (ocúltalas en selección para limpiar UI)
                if (!selectionMode)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniIconButton(
                        icon: Icons.more_horiz,
                        color: brand,
                        onTap: onMore,
                      ),
                      _MiniIconButton(
                        icon: Icons.ios_share_rounded,
                        color: brand,
                        onTap: onShare,
                      ),
                      _MiniIconButton(
                        icon: Icons.manage_search_rounded,
                        color: brand,
                        onTap: onReanalyze,
                      ),
                      _MiniIconButton(
                        icon: Icons.delete_outline,
                        color: brand,
                        onTap: onDelete,
                      ),
                    ],
                  )
                else
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

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      tooltip: '',
    );
  }
}

class _EmptyRecordingsModern extends StatelessWidget {
  const _EmptyRecordingsModern();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _GlassCard(
        child: SizedBox(
          height: 170,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_music_outlined,
                  size: 58,
                  color: Colors.white.withOpacity(.85),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sin grabaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(.95),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Graba en “Tiempo real” con el auto-guardado activo o vuelve luego.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.80),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================== Modelo ============================== */

class _Recording {
  final String id;
  final String path;
  final String name;
  final DateTime dateTime;
  final Duration duration;
  final double sizeMb;
  final String ext;

  _Recording({
    required this.id,
    required this.path,
    required this.name,
    required this.dateTime,
    required this.duration,
    required this.sizeMb,
    required this.ext,
  });
}

/* ============================== Utils =============================== */

extension _FmtDT on DateTime {
  String formatNice() {
    final d = day.toString().padLeft(2, '0');
    final m = month.toString().padLeft(2, '0');
    final y = year.toString();
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}

extension _FmtDur on Duration {
  String formatNice() {
    final h = inHours;
    final m = inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

Widget _kv(String key, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 110,
        child: Text(
          key,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          softWrap: true,
          style: const TextStyle(color: Colors.black87),
        ),
      ),
    ],
  ),
);
