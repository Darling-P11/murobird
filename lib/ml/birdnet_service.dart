// lib/ml/birdnet_service.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class BirdnetPrediction {
  final String label;
  final double score;
  final double startSec;
  final double endSec;
  BirdnetPrediction(this.label, this.score, this.startSec, this.endSec);
}

/// ======= Helpers top-level (no clases anidadas) =======

class _WavHeader {
  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int dataOffset;
  final int dataLength;
  _WavHeader(
    this.sampleRate,
    this.channels,
    this.bitsPerSample,
    this.dataOffset,
    this.dataLength,
  );
}

Future<_WavHeader> _readWavHeader(RandomAccessFile raf) async {
  await raf.setPosition(0);
  final head = await raf.read(64 * 1024); // suficiente para headers típicos
  if (head.length < 12) throw 'WAV demasiado corto';

  String tag(int off) =>
      String.fromCharCodes(head.sublist(off, math.min(off + 4, head.length)));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw 'No es WAV RIFF';
  }

  final bd = ByteData.sublistView(Uint8List.fromList(head));
  int cursor = 12;
  int? sr, ch, bits, dataOff, dataLen;

  while (cursor + 8 <= head.length) {
    final id = tag(cursor);
    final size = bd.getUint32(cursor + 4, Endian.little);
    final next = cursor + 8 + size;
    if (id == 'fmt ') {
      if (cursor + 24 > head.length) break;
      final fmt = bd.getUint16(cursor + 8, Endian.little);
      if (fmt != 1) throw 'Se requiere PCM lineal (fmt=$fmt)';
      ch = bd.getUint16(cursor + 10, Endian.little);
      sr = bd.getUint32(cursor + 12, Endian.little);
      bits = bd.getUint16(cursor + 22, Endian.little);
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
    throw 'Header WAV inválido o muy inusual';
  }
  return _WavHeader(sr!, ch!, bits!, dataOff!, dataLen!);
}

class _Wav {
  final List<double> samples;
  final int sampleRate;
  final int channels;
  _Wav(this.samples, this.sampleRate, this.channels);
}

/// =======================================================

class BirdnetService {
  static final BirdnetService I = BirdnetService._();
  BirdnetService._();

  Interpreter? _inter;
  late List<String> _labels;
  late List<int> _inShape; // p.ej.: [1, 144000]

  bool get isLoaded => _inter != null;

  Future<void> load() async {
    if (_inter != null) return;

    // 1) Labels
    final labelsRaw = await rootBundle.loadString(
      'assets/models/birdnet/labels/es.txt',
    );
    _labels = labelsRaw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (_labels.isEmpty) {
      throw 'Labels vacíos: assets/models/birdnet/labels/es.txt';
    }

    // 2) Modelo
    final md = await rootBundle.load(
      'assets/models/birdnet/audio-model-fp16.tflite',
    );
    final modelBytes = md.buffer.asUint8List(
      md.offsetInBytes,
      md.lengthInBytes,
    );
    print('BirdNET model bytes: ${modelBytes.length}');

    try {
      final opt = InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = false; // CPU/XNNPACK primero
      _inter = await Interpreter.fromBuffer(modelBytes, options: opt);
      print('Interpreter created with CPU/XNNPACK');
    } catch (_) {
      final opt = InterpreterOptions()..useNnApiForAndroid = true;
      _inter = await Interpreter.fromBuffer(modelBytes, options: opt);
      print('Interpreter created with NNAPI');
    }

    _inShape = _inter!.getInputTensor(0).shape; // [1, N]
    print('BirdNET loaded. inputShape=$_inShape labels=${_labels.length}');
  }

  /* ======================= WAV helpers (camino pequeño) ======================= */

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

    final raw = data.sublist(dataOff, math.min(dataOff + dataLen, data.length));
    final even = raw.length & ~1;
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

  List<double> _segmentExactLength(List<double> x, int offset, int neededLen) {
    final end = math.min(offset + neededLen, x.length);
    final out = List<double>.filled(neededLen, 0.0);
    final copyLen = math.max(0, end - offset);
    if (copyLen > 0) {
      for (int i = 0; i < copyLen; i++) {
        out[i] = x[offset + i];
      }
    }
    return out;
  }

  /* ======================= Inferencia común ======================= */

  Future<List<double>> _inferOnce(Float32List inVec) async {
    final input = [inVec];
    final outT = _inter!.getOutputTensor(0);
    final numClasses = outT.shape.last;
    final output = List.generate(
      1,
      (_) => List<double>.filled(numClasses, 0.0),
    );
    _inter!.run(input, output);
    return output[0];
  }

  /* ======================= API principal ======================= */

  Future<List<BirdnetPrediction>> predictFromWav(
    String wavPath, {
    int segmentSeconds = 3,
    int hopSeconds = 1,
    double scoreThreshold = 0.35,
    int topK = 3,
  }) async {
    if (_inter == null) await load();

    // Grande -> streaming (evita OOM)
    final f = File(wavPath);
    final fileBytes = await f.length();
    if (fileBytes > 50 * 1024 * 1024) {
      return _predictFromWavStreamed(
        wavPath,
        segmentSeconds: segmentSeconds,
        hopSeconds: hopSeconds,
        scoreThreshold: scoreThreshold,
        topK: topK,
      );
    }

    // Pequeños: carga completa
    final data = await f.readAsBytes();
    final wav = _parseWav(data);

    var mono = wav.samples;
    var sr = wav.sampleRate;
    if (sr != 48000) mono = _resampleLinear(mono, sr, 48000);
    sr = 48000;

    if (_inShape.length != 2 || _inShape.first != 1) {
      throw 'Modelo inesperado: inputShape=$_inShape (se esperaba [1,N])';
    }
    final neededLen = _inShape.last;
    final hop = hopSeconds * sr;
    final realSeg = neededLen;

    final out = <BirdnetPrediction>[];
    for (int i = 0; i + 1 <= mono.length; i += hop) {
      final window = _segmentExactLength(mono, i, realSeg);
      final Float32List inVec = Float32List.fromList(window);
      final probs = await _inferOnce(inVec);

      final idxs = List<int>.generate(probs.length, (k) => k)
        ..sort((a, b) => probs[b].compareTo(probs[a]));
      int added = 0;
      for (final idx in idxs) {
        final p = probs[idx];
        if (p < scoreThreshold) break;
        final name = idx < _labels.length ? _labels[idx] : 'Clase $idx';
        final start = i / sr;
        final end = (i + realSeg) / sr;
        out.add(BirdnetPrediction(name, p, start, end));
        if (++added >= topK) break;
      }

      if (i + hop >= mono.length && i > 0) break;
    }

    final Map<String, BirdnetPrediction> best = {};
    for (final p in out) {
      final ex = best[p.label];
      if (ex == null || p.score > ex.score) best[p.label] = p;
    }
    final list = best.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list.take(topK).toList();
  }

  /* ======================= Streaming (archivos grandes) ======================= */

  Future<List<BirdnetPrediction>> _predictFromWavStreamed(
    String wavPath, {
    required int segmentSeconds,
    required int hopSeconds,
    required double scoreThreshold,
    required int topK,
  }) async {
    final raf = await File(wavPath).open();
    try {
      final header = await _readWavHeader(raf);
      if (header.bitsPerSample != 16) throw 'WAV debe ser PCM 16-bit';
      if (_inShape.length != 2 || _inShape.first != 1) {
        throw 'Modelo inesperado: inputShape=$_inShape (se esperaba [1,N])';
      }

      final srSrc = header.sampleRate;
      final srDst = 48000;

      final neededLen = _inShape.last; // p.ej., 144000 (=3s)
      final seg = segmentSeconds * srDst; // trabajamos en 48 kHz
      final hop = hopSeconds * srDst;

      print(
        '[BirdNET] STREAMING: srcSR=$srSrc ch=${header.channels} bits=${header.bitsPerSample}',
      );
      print(
        '[BirdNET] dataOffset=${header.dataOffset} dataLength=${header.dataLength} bytes',
      );
      print('[BirdNET] neededLen=$neededLen seg=$seg hop=$hop');

      // Ring buffer a 48 kHz
      final ring = Float32List(neededLen);
      int ringFill = 0;
      int ringW = 0;

      int totalSamples48 = 0; // contado a 48 kHz
      int lastInferAt = -0x3fffffff;

      final Map<String, BirdnetPrediction> best = {};

      await raf.setPosition(header.dataOffset);
      int remaining = header.dataLength;
      const chunkBytes = 8192;

      // Buffer fuente para re-muestreo por bloques (cuando no sea 48k)
      final List<double> srcBuf = [];
      final int blockSrc = srSrc * 2; // ~2s por bloque para resample

      void push(double v) {
        ring[ringW] = v;
        ringW = (ringW + 1) % neededLen;
        if (ringFill < neededLen) ringFill++;
        totalSamples48++;
      }

      Future<void> maybeInfer() async {
        if (ringFill < seg) return;
        if (totalSamples48 - lastInferAt < hop) return;

        final Float32List input = Float32List(neededLen);
        if (ringFill == neededLen) {
          final tail = neededLen - ringW;
          input.setRange(0, tail, ring, ringW);
          if (ringW > 0) input.setRange(tail, tail + ringW, ring, 0);
        } else {
          input.setRange(0, ringFill, ring, 0);
          for (int i = ringFill; i < neededLen; i++) input[i] = 0.0;
        }

        final probs = await _inferOnce(input);
        final idxs = List<int>.generate(probs.length, (i) => i)
          ..sort((a, b) => probs[b].compareTo(probs[a]));
        int added = 0;
        for (final idx in idxs) {
          final p = probs[idx];
          if (p < scoreThreshold) break;
          final name = idx < _labels.length ? _labels[idx] : 'Clase $idx';
          final endS = totalSamples48 / srDst;
          final startS = math.max(0, totalSamples48 - neededLen) / srDst;
          final prev = best[name];
          if (prev == null || p > prev.score) {
            best[name] = BirdnetPrediction(name, p, startS, endS);
          }
          if (++added >= topK) break;
        }
        lastInferAt = totalSamples48;
      }

      // —— LECTURA RÁPIDA + resample opcional
      while (remaining > 0) {
        final toRead = remaining > chunkBytes ? chunkBytes : remaining;
        final raw = await raf.read(toRead);
        if (raw.isEmpty) break;
        remaining -= raw.length;

        // LOG cada ~10 MB
        if ((header.dataLength - remaining) % (10 * 1024 * 1024) < chunkBytes) {
          final mb = ((header.dataLength - remaining) / (1024 * 1024))
              .toStringAsFixed(0);
          final totalMb = (header.dataLength / (1024 * 1024)).toStringAsFixed(
            0,
          );
          print('[BirdNET] Leyendo… $mb MB / $totalMb MB');
        }

        // Convertir el trozo a Int16List de una sola vez
        final u8 = Uint8List.fromList(raw);
        final evenLen = u8.length & ~1;
        final i16 = Int16List.view(u8.buffer, 0, evenLen >> 1);

        // A MONO en SR de origen
        if (header.channels == 1) {
          for (int i = 0; i < i16.length; i++) {
            final s = i16[i] / 32768.0;
            if (srSrc == srDst) {
              push(s);
              if (ringFill >= seg && (totalSamples48 - lastInferAt) >= hop) {
                await maybeInfer();
              }
            } else {
              srcBuf.add(s);
              // Resample por bloques
              while (srcBuf.length >= blockSrc) {
                final block = srcBuf.sublist(0, blockSrc);
                final out48 = _resampleLinear(block, srSrc, srDst);
                for (final v in out48) {
                  push(v);
                  if (ringFill >= seg &&
                      (totalSamples48 - lastInferAt) >= hop) {
                    await maybeInfer();
                  }
                }
                // deja 1 muestra de solape para continuidad
                srcBuf.removeRange(0, blockSrc - 1);
              }
            }
          }
        } else {
          for (int i = 0; i + 1 < i16.length; i += 2) {
            final l = i16[i] / 32768.0;
            final r = i16[i + 1] / 32768.0;
            final s = (l + r) * 0.5;
            if (srSrc == srDst) {
              push(s);
              if (ringFill >= seg && (totalSamples48 - lastInferAt) >= hop) {
                await maybeInfer();
              }
            } else {
              srcBuf.add(s);
              while (srcBuf.length >= blockSrc) {
                final block = srcBuf.sublist(0, blockSrc);
                final out48 = _resampleLinear(block, srSrc, srDst);
                for (final v in out48) {
                  push(v);
                  if (ringFill >= seg &&
                      (totalSamples48 - lastInferAt) >= hop) {
                    await maybeInfer();
                  }
                }
                srcBuf.removeRange(0, blockSrc - 1);
              }
            }
          }
        }
      }

      // Resamplea lo que quedó en el buffer
      if (srSrc != srDst && srcBuf.isNotEmpty) {
        final out48 = _resampleLinear(srcBuf, srSrc, srDst);
        for (final v in out48) {
          push(v);
          if (ringFill >= seg && (totalSamples48 - lastInferAt) >= hop) {
            await maybeInfer();
          }
        }
      }

      await maybeInfer();

      final list = best.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      return list.take(topK).toList();
    } finally {
      await raf.close();
    }
  }
}
