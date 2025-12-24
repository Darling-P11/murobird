// lib/screens/upload/upload_audio_screen.dart
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/routes.dart';
import '../../ml/birdnet_service.dart';
import '../../widgets/blocking_loader.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class UploadAudioScreen extends StatefulWidget {
  const UploadAudioScreen({super.key});

  @override
  State<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends State<UploadAudioScreen> {
  static const Color _brand = Color(0xFF001225);

  final List<PlatformFile> _picked = [];
  bool _busy = false;
  double _progress = 0;
  String? _error;

  Future<void> _pickFiles() async {
    if (_busy) return;
    setState(() => _error = null);

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: const ['wav'],
    );

    if (res == null) return;

    final files = res.files.where((f) => f.path != null).take(3).toList();
    setState(() {
      _picked
        ..clear()
        ..addAll(files);
    });
  }

  Future<List<_Pred>> _analyzeOne(String path) async {
    if (!await File(path).exists()) return const [];
    final preds = await BirdnetService.I.predictFromWav(
      path,
      segmentSeconds: 3,
      hopSeconds: 1,
      scoreThreshold: 0.30,
      topK: 5,
    );
    return preds
        .map((p) => _Pred(p.label, p.score, p.startSec, p.endSec))
        .toList();
  }

  Map<String, dynamic> _mergeAndBuildArgs(List<List<_Pred>> all) {
    String norm(String s) =>
        s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    final Map<String, _Pred> best = {};
    for (final list in all) {
      for (final p in list) {
        final k = norm(p.name);
        final prev = best[k];
        if (prev == null || p.confidence > prev.confidence) best[k] = p;
      }
    }

    final merged = best.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final topBird = merged.isNotEmpty ? merged.first.name : '';
    final candidates = merged.skip(1).map((p) {
      return {
        'name': p.name,
        'confidence': p.confidence,
        'start': p.start,
        'end': p.end,
      };
    }).toList();

    return {'topBird': topBird, 'candidates': candidates};
  }

  Future<void> _analyze() async {
    if (_picked.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });

    showBlockingLoader(context, message: 'Analizando audios…');
    final started = DateTime.now();

    try {
      await BirdnetService.I.load();

      final results = <List<_Pred>>[];
      for (var i = 0; i < _picked.length; i++) {
        final p = _picked[i];
        final preds = await _analyzeOne(p.path!);
        results.add(preds);
        if (mounted) setState(() => _progress = (i + 1) / _picked.length);
      }

      final args = _mergeAndBuildArgs(results);

      final elapsed = DateTime.now().difference(started);
      const minMs = 400;
      if (elapsed.inMilliseconds < minMs) {
        await Future.delayed(
          Duration(milliseconds: minMs - elapsed.inMilliseconds),
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // cierra loader
      Navigator.pushNamed(context, Routes.result, arguments: args);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _error = 'Error al analizar: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final canAnalyze = _picked.isNotEmpty && !_busy;

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
          // Fondo (igual Home)
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
              // ===== HEADER HOME-LIKE =====
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
                          const _LogoPill(
                            logoPath: 'assets/images/orbird_ai_blanco.png',
                            title: 'OrBird AI',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Text(
                          'Subir audio',
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
                        'Selecciona hasta 3 archivos WAV y obtén la especie detectada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),

                      if (_busy) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progress == 0 ? null : _progress,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ===== BODY =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    children: [
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
                      const SizedBox(height: 14),

                      // CTA pick (glass)
                      _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(.16),
                                  ),
                                ),
                                child: Icon(
                                  Icons.folder_open_rounded,
                                  color: Colors.white.withOpacity(.92),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Seleccionar audio (WAV)',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(.95),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Máximo 3 archivos por análisis',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(.82),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _PillButton(
                                label: 'Elegir',
                                onTap: _busy ? null : _pickFiles,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tabla (glass)
                      _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: _FilesTable(
                            rows: _picked
                                .map((f) => _FileRow('--:--', f.name))
                                .toList(),
                            onDelete: (index) {
                              if (_busy) return;
                              setState(() => _picked.removeAt(index));
                            },
                            brand: _brand,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Requisitos (glass)
                      const _GlassCard(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: _Section(
                            icon: Icons.rule_rounded,
                            title: 'Requisitos para el análisis',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Bullet('Formato: WAV (PCM 16-bit)'),
                                _Bullet('Tiempo máximo: 30 minutos'),
                                _Bullet('Tiempo mínimo: 30 segundos'),
                                _Bullet('Máximo por análisis: 3 audios'),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.92),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          const Spacer(),
                          _PrimaryCTAButton(
                            label: 'Analizar',
                            icon: Icons.arrow_forward_rounded,
                            enabled: canAnalyze,
                            onTap: canAnalyze ? _analyze : null,
                          ),
                        ],
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
                                'Desarrollado po Orbix',
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

/* =======================  TABLE (Home-like)  ======================= */

class _FilesTable extends StatelessWidget {
  const _FilesTable({
    required this.rows,
    required this.onDelete,
    required this.brand,
  });

  final List<_FileRow> rows;
  final ValueChanged<int> onDelete;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final compact = width < 380;
        return _TableCore(
          rows: rows,
          compact: compact,
          onDelete: onDelete,
          brand: brand,
        );
      },
    );
  }
}

class _TableCore extends StatelessWidget {
  const _TableCore({
    required this.rows,
    required this.compact,
    required this.onDelete,
    required this.brand,
  });

  final List<_FileRow> rows;
  final bool compact;
  final ValueChanged<int> onDelete;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: compact ? 12 : 13,
    );

    final timeFlex = 24;
    final nameFlex = 60;
    final actFlex = 16;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(.12)),
              ),
            ),
            padding: EdgeInsets.symmetric(
              vertical: compact ? 10 : 12,
              horizontal: compact ? 10 : 12,
            ),
            child: Row(
              children: [
                _HeaderCell(
                  'Hora',
                  flex: timeFlex,
                  style: headerStyle,
                  center: true,
                ),
                const _VSep(),
                _HeaderCell(
                  'Archivo',
                  flex: nameFlex,
                  style: headerStyle,
                  center: true,
                ),
                const _VSep(),
                _HeaderCell(
                  'Acción',
                  flex: actFlex,
                  style: headerStyle,
                  center: true,
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white.withOpacity(.85),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aún no has seleccionado audios.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.85),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (int i = 0; i < rows.length; i++) ...[
              _DataRow(
                index: i,
                row: rows[i],
                compact: compact,
                timeFlex: timeFlex,
                nameFlex: nameFlex,
                actFlex: actFlex,
                onDelete: onDelete,
              ),
              if (i != rows.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withOpacity(.10),
                ),
            ],
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.text, {
    required this.flex,
    required this.style,
    this.center = false,
  });

  final String text;
  final int flex;
  final TextStyle style;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: style,
        ),
      ),
    );
  }
}

class _VSep extends StatelessWidget {
  const _VSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: Colors.white.withOpacity(.22),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.index,
    required this.row,
    required this.compact,
    required this.timeFlex,
    required this.nameFlex,
    required this.actFlex,
    required this.onDelete,
  });

  final int index;
  final _FileRow row;
  final bool compact;
  final int timeFlex;
  final int nameFlex;
  final int actFlex;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final bold = TextStyle(
      color: Colors.white.withOpacity(.92),
      fontWeight: FontWeight.w900,
      fontSize: compact ? 13 : 14,
    );
    final text = TextStyle(
      color: Colors.white.withOpacity(.86),
      fontWeight: FontWeight.w700,
      fontSize: compact ? 13 : 14,
    );

    final iconSize = compact ? 18.0 : 20.0;
    final constraints = BoxConstraints.tightFor(
      width: compact ? 34 : 36,
      height: compact ? 34 : 36,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 8 : 10,
        horizontal: compact ? 8 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: timeFlex,
            child: Text(row.time, style: bold),
          ),
          Expanded(
            flex: nameFlex,
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text,
            ),
          ),
          Expanded(
            flex: actFlex,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: constraints,
                iconSize: iconSize,
                onPressed: () => onDelete(index),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.white.withOpacity(.92),
                ),
                splashRadius: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow {
  final String time;
  final String name;
  const _FileRow(this.time, this.name);
}

/* =======================  HOME-LIKE WIDGETS  ======================= */

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
    return Column(
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

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? Colors.white : Colors.white.withOpacity(.45),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF001225).withOpacity(enabled ? 1 : .55),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryCTAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PrimaryCTAButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.white : Colors.white.withOpacity(.45),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF001225).withOpacity(enabled ? 1 : .55),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                icon,
                color: const Color(0xFF001225).withOpacity(enabled ? 1 : .55),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =======================  MODELO LOCAL PARA MERGE  ======================= */

class _Pred {
  final String name;
  final double confidence;
  final double start;
  final double end;
  _Pred(this.name, this.confidence, this.start, this.end);
}
