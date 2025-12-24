import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/routes.dart';
import '../../offline/offline_prefs.dart';
import '../../widgets/blocking_loader.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class RealtimeScreen extends StatefulWidget {
  const RealtimeScreen({super.key});

  @override
  State<RealtimeScreen> createState() => _RealtimeScreenState();
}

class _RealtimeScreenState extends State<RealtimeScreen>
    with TickerProviderStateMixin {
  static const Color _brand = Color(0xFF001225);

  // ===== Grabación / archivo WAV =====
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  RandomAccessFile? _wavFile;
  int _wavDataBytes = 0;
  bool _autoSaveActive = false;

  // Config stream PCM
  static const int _sr = 16000;
  static const int _bits = 16;
  static const int _ch = 1;
  Uint8List? _pcmCarry;

  // ===== Timer =====
  Timer? _timer;
  int _elapsed = 0;
  static const int _minSecondsToIdentify = 7;

  // ===== Onda (AMPlitud real con onAmplitudeChanged, como el primerito) =====
  StreamSubscription<Amplitude>? _ampSub;
  final int _bars = 64;
  final List<double> _levels = [];
  bool _usingFallbackWave = false;
  Timer? _fakeWaveTimer;
  double _lastDb = double.nan;

  // Suavizado para que la onda no “parpadee”
  double _ema = 0.20;

  // ===== Stream PCM para guardar WAV =====
  StreamSubscription<Uint8List>? _pcmSub;

  @override
  void initState() {
    super.initState();
    // Piso inicial visible
    _levels.addAll(List.filled(_bars, 0.20));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _pcmSub?.cancel();
    _fakeWaveTimer?.cancel();
    _finalizeWavHeaderIfOpen();
    _recorder.dispose();
    super.dispose();
  }

  // ===================== WAV helpers =====================

  Future<String> _nextWavPath({required bool keep}) async {
    final base = keep
        ? await getApplicationDocumentsDirectory()
        : await getTemporaryDirectory();

    final sub = keep ? 'recordings' : 'tmp';
    final recDir = Directory('${base.path}/$sub');
    if (!await recDir.exists()) await recDir.create(recursive: true);

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    return '${recDir.path}/realtime_$ts.wav';
  }

  Future<void> _writeWavHeader(
    RandomAccessFile f, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
    required int dataLength,
  }) async {
    await f.writeFrom([0x52, 0x49, 0x46, 0x46]); // RIFF
    await _writeInt32LE(f, 36 + dataLength);
    await f.writeFrom([0x57, 0x41, 0x56, 0x45]); // WAVE

    await f.writeFrom([0x66, 0x6d, 0x74, 0x20]); // fmt
    await _writeInt32LE(f, 16);
    await _writeInt16LE(f, 1); // PCM
    await _writeInt16LE(f, channels);
    await _writeInt32LE(f, sampleRate);
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    await _writeInt32LE(f, byteRate);
    final blockAlign = channels * bitsPerSample ~/ 8;
    await _writeInt16LE(f, blockAlign);
    await _writeInt16LE(f, bitsPerSample);

    await f.writeFrom([0x64, 0x61, 0x74, 0x61]); // data
    await _writeInt32LE(f, dataLength);
  }

  Future<void> _finalizeWavHeaderIfOpen() async {
    if (_wavFile == null) return;
    try {
      await _wavFile!.setPosition(4);
      await _writeInt32LE(_wavFile!, 36 + _wavDataBytes);
      await _wavFile!.setPosition(40);
      await _writeInt32LE(_wavFile!, _wavDataBytes);
      await _wavFile!.close();
    } catch (_) {}
    _wavFile = null;
  }

  Future<void> _writeInt16LE(RandomAccessFile f, int v) async {
    await f.writeFrom([v & 0xFF, (v >> 8) & 0xFF]);
  }

  Future<void> _writeInt32LE(RandomAccessFile f, int v) async {
    await f.writeFrom([
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);
  }

  // ===================== Fallback onda =====================

  void _startFallbackWave() {
    _usingFallbackWave = true;
    _fakeWaveTimer?.cancel();
    final rng = math.Random();
    _fakeWaveTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      final v = (0.22 + rng.nextDouble() * 0.68).clamp(0.22, 1.0);
      if (!mounted) return;
      setState(() {
        _levels.removeAt(0);
        _levels.add(v);
        _lastDb = double.nan;
      });
    });
  }

  void _stopFallbackWave() {
    _usingFallbackWave = false;
    _fakeWaveTimer?.cancel();
  }

  // ===================== PCM carry (para WAV) =====================

  Uint8List _joinCarry(Uint8List chunk) {
    Uint8List data;
    if (_pcmCarry != null && _pcmCarry!.isNotEmpty) {
      data = Uint8List(_pcmCarry!.length + chunk.length)
        ..setRange(0, _pcmCarry!.length, _pcmCarry!)
        ..setRange(_pcmCarry!.length, _pcmCarry!.length + chunk.length, chunk);
      _pcmCarry = null;
    } else {
      data = chunk;
    }

    if ((data.lengthInBytes & 1) == 1) {
      _pcmCarry = data.sublist(data.lengthInBytes - 1);
      data = data.sublist(0, data.lengthInBytes - 1);
    }
    return data;
  }

  // ===================== START / STOP =====================

  Future<void> _startRecording() async {
    // permiso
    if (!await _recorder.hasPermission()) {
      final req = await Permission.microphone.request();
      if (!req.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesita permiso de micrófono.')),
        );
        return;
      }
    }

    _autoSaveActive = await OfflinePrefs.autoSaveRecordings;

    // prepara WAV
    final path = await _nextWavPath(keep: _autoSaveActive);
    final raf = await File(path).open(mode: FileMode.write);
    await _writeWavHeader(
      raf,
      sampleRate: _sr,
      channels: _ch,
      bitsPerSample: _bits,
      dataLength: 0,
    );
    _wavFile = raf;
    _currentPath = path;
    _wavDataBytes = 0;

    // stream PCM16 SOLO para guardar WAV
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sr,
          numChannels: _ch,
        ),
      );

      _pcmSub?.cancel();
      _pcmSub = stream.listen((bytes) async {
        final safe = _joinCarry(bytes);
        await _wavFile?.writeFrom(safe);
        _wavDataBytes += safe.length;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grabación no soportada en este equipo'),
          ),
        );
      }
      return;
    }

    // timer
    _timer?.cancel();
    _elapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
    });

    // ✅ Onda en tiempo real (como tu primerito)
    _ampSub?.cancel();
    _stopFallbackWave();

    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 70))
        .listen((amp) {
          final db = amp.current.toDouble();
          _lastDb = db;

          // Rango más realista: -60..0 dB
          final raw = ((db + 60) / 60).clamp(0.0, 1.0);

          // Compresión para que no se “infle” con señales altas
          // (más real: el oído/sonidos suelen variar mucho)
          final compressed = math.pow(raw, 1.6).toDouble(); // <-- clave

          // Piso pequeño (casi 0) + escala
          final target = (0.02 + compressed * 0.98).clamp(0.02, 1.0);

          // Peak hold suave: sube rápido, baja lento (más natural)
          final prev = _levels.isNotEmpty ? _levels.last : 0.02;
          final attack = 0.55; // sube rápido
          final release = 0.12; // baja lento
          final next = target > prev
              ? (prev + (target - prev) * attack)
              : (prev + (target - prev) * release);

          setState(() {
            _levels.removeAt(0);
            _levels.add(next.clamp(0.02, 1.0));
          });
        }, onError: (_) => _startFallbackWave());

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecordingAndSearch() async {
    showBlockingLoader(context, message: 'Procesando audio…');
    final started = DateTime.now();

    try {
      await _recorder.stop();
      _timer?.cancel();
      await _ampSub?.cancel();
      await _pcmSub?.cancel();
      _stopFallbackWave();

      await _finalizeWavHeaderIfOpen();
      final pathForSearch = _currentPath;

      setState(() => _isRecording = false);

      final elapsed = DateTime.now().difference(started);
      const minMs = 400;
      if (elapsed.inMilliseconds < minMs) {
        await Future.delayed(
          Duration(milliseconds: minMs - elapsed.inMilliseconds),
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // loader

      Navigator.pushNamed(
        context,
        Routes.searching,
        arguments: pathForSearch,
      ).then((_) async {
        if (!_autoSaveActive && pathForSearch != null) {
          try {
            final f = File(pathForSearch);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al procesar: $e')));
    }
  }

  // ===================== UI helpers =====================

  String _fmtHMS(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$ss';
  }

  double get _identifyProgress =>
      (_elapsed / _minSecondsToIdentify).clamp(0.0, 1.0);

  String get _signalLabel {
    if (!_isRecording) return '—';
    if (_usingFallbackWave) return 'Simulada';
    if (_lastDb.isNaN) return '... dB';
    return '${_lastDb.toStringAsFixed(1)} dB';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final canIdentify = _isRecording && _elapsed >= _minSecondsToIdentify;

    void goBack() {
      if (_isRecording) {
        _stopRecordingAndSearch();
        return;
      }
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
                      const SizedBox(height: 2),
                      const Center(
                        child: Text(
                          'Tiempo real',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                        _isRecording
                            ? 'Mantén el móvil cerca del sonido. En unos segundos podrás identificar.'
                            : 'Pulsa el micrófono para comenzar a captar el sonido del ave.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Column(
                    children: [
                      _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CardTitle(
                                icon: Icons.analytics_rounded,
                                title: 'Estado de captura',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _Chip(
                                    icon: Icons.save_alt_rounded,
                                    label: _autoSaveActive
                                        ? 'Auto-guardado'
                                        : 'Sin guardado',
                                    value: _autoSaveActive ? 'ON' : 'OFF',
                                    ok: _autoSaveActive,
                                  ),
                                  const SizedBox(width: 10),
                                  _Chip(
                                    icon: Icons.graphic_eq_rounded,
                                    label: 'Señal',
                                    value: _signalLabel,
                                    ok: _isRecording,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Habilitación de identificación',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.9),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: _isRecording ? _identifyProgress : 0,
                                  minHeight: 10,
                                  backgroundColor: Colors.white.withOpacity(
                                    .18,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    canIdentify
                                        ? Colors.white
                                        : Colors.white.withOpacity(.75),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isRecording
                                    ? (canIdentify
                                          ? 'Listo para analizar cuando detengas la grabación.'
                                          : 'Espera ${(_minSecondsToIdentify - _elapsed).clamp(0, _minSecondsToIdentify)} s para mejor precisión.')
                                    : 'Inicia una grabación para activar el progreso.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.80),
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ===== Onda =====
                      _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CardTitle(
                                icon: Icons.graphic_eq_rounded,
                                title: 'Onda de sonido',
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 120,
                                width: double.infinity,
                                child: _isRecording
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LayoutBuilder(
                                          builder: (context, c) {
                                            final w = c.maxWidth.isFinite
                                                ? c.maxWidth
                                                : MediaQuery.of(
                                                    context,
                                                  ).size.width;
                                            const h = 120.0;

                                            return RepaintBoundary(
                                              child: CustomPaint(
                                                // ✅ Fuerza tamaño real (si no, a veces queda en 0)
                                                size: Size(w, h),
                                                painter: _WaveformBars(
                                                  levels: List<double>.from(
                                                    _levels,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Center(
                                        child: Image.asset(
                                          'assets/mock/wave_demo.png',
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.graphic_eq,
                                                size: 56,
                                                color: Colors.black54,
                                              ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Center(
                        child: Text(
                          _isRecording ? _fmtHMS(_elapsed) : '00:00:00',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.95),
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _isRecording
                              ? 'Grabando… toca el micrófono para detener\ny analizar el audio'
                              : 'Pulsa para empezar a captar el\nsonido del ave',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.78),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            if (_isRecording) {
                              await _stopRecordingAndSearch();
                            } else {
                              await _startRecording();
                            }
                          },
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? const Color(0xFFE65C5C)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(.22),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: _isRecording ? Colors.white : _brand,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

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

/* ================== UI pieces ================== */

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

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _CardTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ok;

  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final bg = ok
        ? Colors.white.withOpacity(.16)
        : Colors.white.withOpacity(.10);
    final border = ok
        ? Colors.white.withOpacity(.22)
        : Colors.white.withOpacity(.14);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(.92), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.85),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================== Painter onda (VISIBLE en fondo oscuro) ================== */

class _WaveformBars extends CustomPainter {
  final List<double> levels;
  _WaveformBars({required this.levels});

  @override
  void paint(Canvas canvas, Size size) {
    // ✅ Fondo más oscuro para que se note SIEMPRE en el glass
    final bg = Paint()..color = Colors.black.withOpacity(.18);
    canvas.drawRect(Offset.zero & size, bg);

    // Línea central visible
    final midLine = Paint()
      ..color = Colors.white.withOpacity(.22)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      midLine,
    );

    // ✅ Barras blancas (como tu imagen 2)
    final paint = Paint()
      ..color = Colors.white.withOpacity(.95)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (size.width <= 2 || size.height <= 2 || levels.isEmpty) return;

    final n = levels.length;
    final barW = math.max(2.0, size.width / (n * 1.25)); // mínimo 2px
    final gap = barW * 0.35;
    final midY = size.height / 2;

    for (int i = 0; i < n; i++) {
      final x = i * (barW + gap);
      if (x > size.width) break;

      final lv = levels[i].clamp(0.0, 1.0);

      // Piso real (para que nunca sea “invisible”)
      final h = (0.02 + math.pow(lv, 0.85) * 0.98) * (size.height * 0.92);

      final rect = RRect.fromLTRBR(
        x,
        midY - h / 2,
        x + barW,
        midY + h / 2,
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformBars oldDelegate) => true;
}
