import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:fftea/fftea.dart';

class BirdnetPrediction {
  final String label;
  final double score;
  final double startSec;
  final double endSec;
  BirdnetPrediction(this.label, this.score, this.startSec, this.endSec);
}

class BirdnetService {
  static final BirdnetService I = BirdnetService._();
  BirdnetService._();

  Interpreter? _inter;
  List<String> _labels = [];
  List<int>? _inShape;

  bool get isLoaded => _inter != null;

  Future<void> load() async {
    if (_inter != null) return;
    final opt = InterpreterOptions()..threads = 2;
    if (Platform.isAndroid) opt.useNnApiForAndroid = true;

    _inter = await Interpreter.fromAsset(
      'assets/models/birdnet/audio-model-fp16.tflite',
      options: opt,
    );

    _labels = (await rootBundle.loadString(
      'assets/models/birdnet/labels/es.txt',
    )).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    _inShape = _inter!.getInputTensor(0).shape; // p.ej. [1, 96, 431, 1]
  }

  /* ===== WAV PCM 16-bit mono/estéreo ===== */
  _Wav _parseWav(Uint8List data) {
    if (data.lengthInBytes < 44) throw 'WAV muy corto';
    final bd = ByteData.sublistView(data);
    String tag(int off) => String.fromCharCodes(data.sublist(off, off + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') throw 'No es RIFF/WAVE';

    int cursor = 12;
    int? sr, ch, bits, dataOff, dataLen;
    while (cursor + 8 <= data.lengthInBytes) {
      final id = tag(cursor);
      final size = bd.getUint32(cursor + 4, Endian.little);
      final next = cursor + 8 + size;
      if (id == 'fmt ') {
        final fmt = bd.getUint16(cursor + 8, Endian.little);
        ch = bd.getUint16(cursor + 10, Endian.little);
        sr = bd.getUint32(cursor + 12, Endian.little);
        bits = bd.getUint16(cursor + 22, Endian.little);
        if (fmt != 1) throw 'WAV no PCM';
      } else if (id == 'data') {
        dataOff = cursor + 8;
        dataLen = size;
        break;
      }
      cursor = next;
    }
    if (sr == null ||
        ch == null ||
        bits == null ||
        dataOff == null ||
        dataLen == null) {
      throw 'Chunks WAV incompletos';
    }
    if (bits != 16) throw 'Solo PCM 16-bit';

    final raw = data.sublist(
      dataOff,
      math.min(dataOff + dataLen, data.lengthInBytes),
    );
    final even = raw.lengthInBytes & ~1;
    final bdData = ByteData.sublistView(raw.sublist(0, even));

    final s16 = <double>[];
    for (int i = 0; i < even; i += 2) {
      s16.add(bdData.getInt16(i, Endian.little) / 32768.0);
    }

    if (ch! == 2) {
      final mono = <double>[];
      for (int i = 0; i < s16.length; i += 2) {
        final r = (i + 1 < s16.length) ? s16[i + 1] : 0.0;
        mono.add((s16[i] + r) * 0.5);
      }
      return _Wav(mono, sr!, 1);
    }
    return _Wav(s16, sr!, ch!);
  }

  /* ===== Resample lineal simple a 48k ===== */
  List<double> _resampleLinear(List<double> x, int srFrom, int srTo) {
    if (srFrom == srTo) return x;
    final ratio = srTo / srFrom;
    final outLen = (x.length * ratio).floor();
    final y = List<double>.filled(outLen, 0);
    for (int i = 0; i < outLen; i++) {
      final pos = i / ratio;
      final p0 = pos.floor();
      final p1 = math.min(p0 + 1, x.length - 1);
      final t = pos - p0;
      y[i] = x[p0] * (1 - t) + x[p1] * t;
    }
    return y;
  }

  /* ===== Mel spectrogram (log) ===== */
  static const int _nFft = 1024;
  static const int _hop = 512;
  static const int _nMels = 96;

  double _hz2mel(double f) => 2595.0 * math.log(1 + f / 700.0) / math.ln10;
  double _mel2hz(double m) => 700.0 * (math.pow(10.0, m / 2595.0) - 1.0);

  List<List<double>> _melFilterBank(
    int sr,
    int nFft,
    int nMels,
    double fMin,
    double fMax,
  ) {
    final fMinMel = _hz2mel(fMin);
    final fMaxMel = _hz2mel(fMax);
    final mels = List<double>.generate(
      nMels + 2,
      (i) => fMinMel + (fMaxMel - fMinMel) * i / (nMels + 1),
    );
    final hz = mels.map(_mel2hz).toList();
    final bins = hz.map((f) => (f * (nFft ~/ 2 + 1) / sr).floor()).toList();
    final fb = List.generate(
      nMels,
      (_) => List<double>.filled(nFft ~/ 2 + 1, 0.0),
    );
    for (int m = 1; m <= nMels; m++) {
      final a = bins[m - 1], b = bins[m], c = bins[m + 1];
      for (int k = a; k < b; k++) fb[m - 1][k] = (k - a) / (b - a + 1e-9);
      for (int k = b; k < c; k++) fb[m - 1][k] = (c - k) / (c - b + 1e-9);
    }
    return fb;
  }

  List<List<double>> _logMelSpectrogram(List<double> mono, {required int sr}) {
    final fft = FFT(_nFft);

    // Hann manual
    final hann = Float64List.fromList(
      List<double>.generate(
        _nFft,
        (n) => 0.5 - 0.5 * math.cos(2 * math.pi * n / (_nFft - 1)),
      ),
    );

    final fb = _melFilterBank(sr, _nFft, _nMels, 60.0, sr / 2.0);

    final cols = <List<double>>[];

    for (int i = 0; i + _nFft <= mono.length; i += _hop) {
      // Frame → Float64List
      final frame = Float64List.fromList(mono.sublist(i, i + _nFft));

      // Aplica ventana
      for (int n = 0; n < _nFft; n++) {
        frame[n] *= hann[n];
      }

      // FFT real (fftea devuelve Float64x2List con .x/.y)
      final spec = fft.realFft(frame);

      // Magnitud hasta Nyquist
      final mag = List<double>.generate(_nFft ~/ 2 + 1, (k) {
        final re = spec[k].x;
        final im = spec[k].y;
        return math.sqrt(re * re + im * im);
      });

      // Banco mel + log
      final mel = List<double>.filled(_nMels, 0.0);
      for (int m = 0; m < _nMels; m++) {
        double s = 0;
        final filt = fb[m];
        for (int k = 0; k < filt.length; k++) {
          s += filt[k] * mag[k];
        }
        mel[m] = math.log(s + 1e-6);
      }

      cols.add(mel); // [time][mel]
    }

    return cols;
  }

  List _fitToInput(List<List<double>> melT, List<int> inShape) {
    // melT: [time][mel] → [mel][time]
    final time = melT.length;
    final mels = melT.isEmpty ? _nMels : melT[0].length;
    final trans = List.generate(
      mels,
      (m) => List<double>.generate(time, (t) => melT[t][m]),
    );

    // Suponemos 4D: [1, A, B, 1] (A=mels, B=time) y adaptamos con resize bilinear.
    final A = inShape[1], B = inShape[2];
    final resized = _resize2D(trans, newRows: A, newCols: B);
    // [1, A, B, 1]
    return [
      List.generate(A, (i) => List.generate(B, (j) => [resized[i][j]])),
    ];
  }

  List<List<double>> _resize2D(
    List<List<double>> x, {
    required int newRows,
    required int newCols,
  }) {
    final r0 = x.length, c0 = x.isEmpty ? 0 : x[0].length;
    if (r0 == 0 || c0 == 0)
      return List.generate(newRows, (_) => List<double>.filled(newCols, 0));
    final y = List.generate(newRows, (_) => List<double>.filled(newCols, 0));
    for (int i = 0; i < newRows; i++) {
      final si = (i * (r0 - 1) / math.max(1, newRows - 1));
      final i0 = si.floor(), i1 = math.min(i0 + 1, r0 - 1);
      final ti = si - i0;
      for (int j = 0; j < newCols; j++) {
        final sj = (j * (c0 - 1) / math.max(1, newCols - 1));
        final j0 = sj.floor(), j1 = math.min(j0 + 1, c0 - 1);
        final tj = sj - j0;
        final v00 = x[i0][j0],
            v01 = x[i0][j1],
            v10 = x[i1][j0],
            v11 = x[i1][j1];
        y[i][j] =
            (1 - ti) * (1 - tj) * v00 +
            (1 - ti) * tj * v01 +
            ti * (1 - tj) * v10 +
            ti * tj * v11;
      }
    }
    return y;
  }

  Future<List<BirdnetPrediction>> predictFromWav(
    String wavPath, {
    int segmentSeconds = 3,
    int hopSeconds = 1,
    double scoreThreshold = 0.35,
    int topK = 3,
  }) async {
    if (_inter == null) await load();

    final data = await File(wavPath).readAsBytes();
    final wav = _parseWav(data);
    var mono = wav.samples;
    var sr = wav.sampleRate;
    if (sr != 48000) mono = _resampleLinear(mono, sr, 48000);
    sr = 48000;

    final seg = sr * segmentSeconds;
    final hop = sr * hopSeconds;
    final out = <BirdnetPrediction>[];

    for (int i = 0; i + seg <= mono.length; i += hop) {
      final slice = mono.sublist(i, i + seg);
      final melTime = _logMelSpectrogram(slice, sr: sr); // [time][mel]
      final input = _fitToInput(melTime, _inShape!);

      final outT = _inter!.getOutputTensor(0);
      final n = outT.shape.last; // num clases
      final output = List.generate(1, (_) => List<double>.filled(n, 0.0));

      _inter!.run(input, output);
      final probs = output[0];

      final idxs = List<int>.generate(probs.length, (i) => i)
        ..sort((a, b) => probs[b].compareTo(probs[a]));

      int added = 0;
      for (final idx in idxs) {
        final p = probs[idx];
        if (p < scoreThreshold) break;
        final name = idx < _labels.length ? _labels[idx] : 'Clase $idx';
        out.add(BirdnetPrediction(name, p, i / sr, (i + seg) / sr));
        if (++added >= topK) break;
      }
    }

    // Agrega por especie (conserva el máximo score)
    final Map<String, BirdnetPrediction> agg = {};
    for (final p in out) {
      final ex = agg[p.label];
      if (ex == null || p.score > ex.score) agg[p.label] = p;
    }
    final list = agg.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list.take(topK).toList();
  }
}

class _Wav {
  final List<double> samples;
  final int sampleRate;
  final int channels;
  _Wav(this.samples, this.sampleRate, this.channels);
}
