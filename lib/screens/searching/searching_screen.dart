import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../ml/birdnet_service.dart';
import '../history/history_store.dart';

/// Partes de un label del modelo (nombre común, científico e id normalizado)
class _LabelParts {
  final String common; // nombre común
  final String sci; // nombre científico
  final String speciesId; // id normalizado, ej: buteo_nitidus

  const _LabelParts({
    required this.common,
    required this.sci,
    required this.speciesId,
  });
}

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with TickerProviderStateMixin {
  // ===== UI brand =====
  static const Color _brand = Color(0xFF001225);

  String _status = 'Cargando modelo…';
  double _progress = 0.1;

  String? _audioPath;
  bool _started = false;

  // Animaciones
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  Timer? _tipTimer;
  int _tipIndex = 0;

  final List<String> _tips = const [
    'Esto puede tardar unos segundos…',
    'Si hay ruido de fondo, intenta acercarte más al sonido.',
    'Estamos comparando con el modelo de reconocimiento.',
    'Tip: grabaciones de 7–12s suelen dar mejores resultados.',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulse = Tween<double>(
      begin: 0.98,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _tipTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _audioPath = switch (args) {
      String s => s,
      Map m => m['audioPath'] as String?,
      _ => null,
    };

    _run();
  }

  /// Separa el label en nombre común / científico y genera un speciesId estable.
  _LabelParts _splitLabel(String label) {
    final l = label.trim();

    // 1) "Común (Latín)"
    final pm = RegExp(r'^(.*?)(?:\s*\(([^)]+)\))$').firstMatch(l);
    if (pm != null) {
      final common = (pm.group(1) ?? '').trim();
      final sci = (pm.group(2) ?? '').trim();
      final speciesId = sci
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      return _LabelParts(common: common, sci: sci, speciesId: speciesId);
    }

    // 2) Con guion bajo: "Taraba major_Batará Mayor", o al revés
    if (l.contains('_')) {
      final parts = l.split('_').map((e) => e.trim()).toList();
      if (parts.length >= 2) {
        String a = parts.first, b = parts.sublist(1).join(' ');
        bool looksLatin(String s) =>
            RegExp(r'^[A-Z][a-zA-Z-]+\s+[a-z-]+$').hasMatch(s);
        String sci, common;
        if (looksLatin(a)) {
          sci = a;
          common = b;
        } else if (looksLatin(b)) {
          sci = b;
          common = a;
        } else {
          sci = a;
          common = b;
        }
        final speciesId = sci
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
        return _LabelParts(common: common, sci: sci, speciesId: speciesId);
      }
    }

    // 3) Fallback
    final sci = l;
    final speciesId = sci
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return _LabelParts(common: l, sci: sci, speciesId: speciesId);
  }

  void _cancelAndGoHome() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
  }

  Future<void> _run() async {
    final audioPath = _audioPath;

    try {
      setState(() {
        _status = 'Inicializando…';
        _progress = 0.15;
      });

      await BirdnetService.I.load();

      setState(() {
        _status = 'Analizando audio…';
        _progress = 0.55;
      });

      if (audioPath == null || !await File(audioPath).exists()) {
        throw 'Audio no encontrado';
      }

      final preds = await BirdnetService.I.predictFromWav(
        audioPath,
        segmentSeconds: 3,
        hopSeconds: 1,
        scoreThreshold: 0.20,
        topK: 5,
      );

      setState(() {
        _status = 'Preparando resultados…';
        _progress = 0.9;
      });

      // Determinar el origen (realtime vs uploaded)
      HistorySource src = HistorySource.realtime;
      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      if (rawArgs is Map && rawArgs['source'] == 'uploaded') {
        src = HistorySource.uploaded;
      }

      // Guardar en historial si hubo predicciones
      if (preds.isNotEmpty) {
        final top = preds.first;
        final parts = _splitLabel(top.label);

        final entry = HistoryEntry(
          id: const Uuid().v4(),
          speciesId: parts.speciesId,
          bird: parts.common,
          sci: parts.sci,
          confidence: top.score,
          source: src,
          dateTime: DateTime.now(),
          audioPath: audioPath,
        );
        await HistoryStore.add(entry);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        Routes.result,
        arguments: {
          'audioPath': audioPath,
          'topBird': preds.isNotEmpty ? preds.first.label : 'Sin coincidencias',
          'candidates': preds
              .map(
                (p) => {
                  'name': p.label,
                  'confidence': p.score,
                  'start': p.startSec,
                  'end': p.endSec,
                },
              )
              .toList(),
        },
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('Searching ERROR: $e\n$st');

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        Routes.result,
        arguments: {
          'audioPath': audioPath,
          'topBird': 'Error al analizar',
          'candidates': const [],
          'error': e.toString(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress.clamp(0.0, 1.0) * 100).round();

    return Scaffold(
      body: Stack(
        children: [
          // Fondo (igual a tu estilo principal)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_brand, _brand.withOpacity(.92), Colors.white],
                stops: const [0, .52, 1],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  // Header con "pill"
                  const SizedBox(height: 18),

                  // Contenido principal centrado
                  Expanded(
                    child: Center(
                      child: _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Buscando aves…',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No cierres la app mientras analizamos el audio.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.80),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Progreso circular + % en el centro
                              ScaleTransition(
                                scale: _pulse,
                                child: SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        strokeWidth: 7,
                                        value: _progress < 0.98
                                            ? _progress
                                            : null,
                                        color: Colors.white,
                                        backgroundColor: Colors.white
                                            .withOpacity(.18),
                                      ),
                                      Text(
                                        '$percent%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Estado actual
                              Text(
                                _status,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.90),
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Tip rotativo (suave)
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  _tips[_tipIndex],
                                  key: ValueKey(_tipIndex),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(.72),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Barra lineal elegante
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: _progress < 0.98 ? _progress : null,
                                  minHeight: 10,
                                  backgroundColor: Colors.white.withOpacity(
                                    .14,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Botón cancelar
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: _cancelAndGoHome,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.white.withOpacity(
                                      .10,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: Colors.white.withOpacity(.18),
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Footer Orbix
                  Opacity(
                    opacity: 0.60,
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo_orbix.png',
                          width: 54,
                          height: 54,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ================== UI pieces (mismo estilo del realtime) ================== */

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
