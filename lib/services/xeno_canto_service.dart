import 'dart:convert';
import 'package:http/http.dart' as http;

const _headers = <String, String>{
  'User-Agent':
      'MuroBird/1.0 (https://example.com; contacto: dev@murobird.app)',
  'Accept': 'application/json',
};

/// ✅ Xeno-canto API v3 requiere `key`.
/// flutter run --dart-define=XC_API_KEY=SU_KEY
/// flutter run --dart-define=XC_API_KEY=SU_KEY

const String _xcApiKey = String.fromEnvironment('XC_API_KEY', defaultValue: '');

class XCRecording {
  final String id;
  final String title;
  final String fileUrl;

  /// URL del sonograma (puede ser SVG/PNG/JPG)
  final String? sonogramUrl;

  /// True si la URL parece SVG
  final bool sonogramIsSvg;

  final String? locality;
  final String? length;
  final String? quality;

  XCRecording({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.sonogramUrl,
    this.sonogramIsSvg = false,
    this.locality,
    this.length,
    this.quality,
  });

  @override
  String toString() =>
      'XCRecording(id=$id, title=$title, fileUrl=$fileUrl, sonogramUrl=$sonogramUrl, svg=$sonogramIsSvg)';
}

class XCImage {
  final String url;
  final bool isSvg;
  XCImage(this.url, this.isSvg);

  @override
  String toString() => 'XCImage(url=$url, isSvg=$isSvg)';
}

class XenoCantoService {
  // ======================= URL HELPERS =======================

  static String? _fixUrl(String? u) {
    if (u == null) return null;
    final s = u.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('//')) return 'https:$s';
    if (s.startsWith('/')) return 'https://xeno-canto.org$s';
    return 'https://xeno-canto.org/$s';
  }

  static bool _looksLikeSvgUrl(String? u) {
    if (u == null) return false;
    final s = u.toLowerCase();
    return s.contains('.svg') || s.contains('image/svg');
  }

  /// Extrae URL de sonograma desde `sono` (normalmente Map con {small, med, large, full})
  static String? _sonogramFrom(dynamic sono) {
    if (sono == null) return null;

    if (sono is Map) {
      final full = _fixUrl(sono['full']?.toString());
      final large = _fixUrl(sono['large']?.toString());
      final med = _fixUrl(sono['med']?.toString());
      final small = _fixUrl(sono['small']?.toString());
      return full ?? large ?? med ?? small;
    }

    if (sono is String) return _fixUrl(sono);

    return null;
  }

  /// 🔥 El campo "file" a veces puede venir como String o como Map.
  /// Esta función lo resuelve.
  static String? _extractAudioUrl(dynamic fileField) {
    if (fileField == null) return null;

    // Caso común: String
    if (fileField is String) return _fixUrl(fileField);

    // Caso: Map (ej. {mp3: "...", wav: "..."} o similar)
    if (fileField is Map) {
      // Intente opciones comunes en orden:
      final candidates = <String?>[
        fileField['mp3']?.toString(),
        fileField['wav']?.toString(),
        fileField['ogg']?.toString(),
        fileField['url']?.toString(),
        fileField['download']?.toString(),
      ].where((e) => e != null && e!.trim().isNotEmpty).toList();

      if (candidates.isEmpty) return null;
      return _fixUrl(candidates.first);
    }

    return _fixUrl(fileField.toString());
  }

  static Future<Map<String, dynamic>?> _getJson(
    Uri url, {
    bool debug = false,
  }) async {
    try {
      if (debug) print('[XC] GET $url');

      final res = await http.get(url, headers: _headers);

      if (debug) {
        print('[XC] status=${res.statusCode}');
        if (res.statusCode != 200) {
          print('[XC] body=${res.body}');
        }
      }

      if (res.statusCode != 200) return null;

      final decoded = json.decode(res.body);
      if (decoded is! Map<String, dynamic>) return null;

      if (decoded.containsKey('error')) {
        if (debug) print('[XC] API error payload: ${decoded['error']}');
        return null;
      }

      return decoded;
    } catch (e) {
      if (debug) print('[XC] error=$e');
      return null;
    }
  }

  // ======================= SONOGRAMAS =======================

  /// Devuelve info del sonograma (URL + si es SVG) de la primera grabación
  /// para el [scientificName] dado.
  static Future<XCImage?> fetchSpectrogram(
    String scientificName, {
    bool debug = false,
  }) async {
    final raw = scientificName.trim();
    if (raw.isEmpty) return null;

    final bin = _extractBinomial(raw);
    if (bin == null) {
      if (debug) print('[XC] fetchSpectrogram: binomial inválido para "$raw"');
      return null;
    }

    final p = bin.split(RegExp(r'\s+'));
    final gen = p[0], sp = p[1];
    final query = 'gen:$gen sp:$sp grp:birds';

    final url = Uri.parse(
      'https://xeno-canto.org/api/3/recordings?key=$_xcApiKey&query=${Uri.encodeQueryComponent(query)}',
    );

    // ✅ PRINT URL de extracción (API)
    print('[XC] URL fetchSpectrogram => $url');

    final data = await _getJson(url, debug: debug);
    if (data == null) return null;

    final recs = (data['recordings'] as List?) ?? const [];
    if (recs.isEmpty) {
      if (debug) print('[XC] fetchSpectrogram: sin recordings');
      return null;
    }

    final first = recs.first as Map<String, dynamic>;

    final sonoUrl =
        _sonogramFrom(first['sono']) ??
        _fixUrl(first['sonogram']?.toString()) ??
        _fixUrl(first['sono_large']?.toString()) ??
        _fixUrl(first['sono_med']?.toString()) ??
        _fixUrl(first['sono_small']?.toString());

    // ✅ PRINT de la URL REAL extraída del sonograma
    print('[XC] Sonogram extraído => $sonoUrl');

    if (sonoUrl == null) return null;

    return XCImage(sonoUrl, _looksLikeSvgUrl(sonoUrl));
  }

  // ======================= AUDIOS =======================

  static Future<List<XCRecording>> fetchBySpecies(
    String label, {
    int limit = 5,
    bool debug = false,
  }) async {
    if (debug) print('[XC] label="$label"');

    // Intentar extraer binomio; si no, intentar GBIF
    String? binomial = _extractBinomial(label);
    if (binomial == null) {
      if (debug) print('[XC] no parece binomial, resolviendo vía GBIF…');
      binomial = await _resolveToBinomialViaGbif(label, debug: debug);
    }

    final latin = (binomial ?? _stripHtml(label).replaceAll('_', ' ').trim())
        .trim();

    if (latin.isEmpty) return const [];

    if (debug) print('[XC] usando binomial="$latin"');

    Future<List<Map<String, dynamic>>> _queryRaw(String q) async {
      final url = Uri.parse(
        'https://xeno-canto.org/api/3/recordings?key=$_xcApiKey&query=${Uri.encodeQueryComponent(q)}',
      );

      // ✅ PRINT URL de extracción (API)
      print('[XC] URL fetchBySpecies/_queryRaw => $url');

      try {
        final r = await http.get(url, headers: _headers);

        if (debug) {
          print('[XC] status=${r.statusCode}');
          if (r.statusCode != 200) {
            print('[XC] body=${r.body}');
          }
        }

        if (r.statusCode != 200) return const [];

        final j = json.decode(r.body);
        if (j is! Map<String, dynamic>) return const [];

        if (j.containsKey('error')) {
          if (debug) print('[XC] API error payload: ${j['error']}');
          return const [];
        }

        final list = (j['recordings'] ?? []) as List;
        if (debug) print('[XC] recordings encontrados=${list.length}');
        return list.cast<Map<String, dynamic>>();
      } catch (e) {
        if (debug) print('[XC] error parse=$e');
        return const [];
      }
    }

    Future<List<Map<String, dynamic>>> _search(String latin) async {
      final out = <Map<String, dynamic>>[];
      final p = latin.split(RegExp(r'\s+'));

      if (p.length >= 2 && _isValidGenus(p[0]) && _isValidSpecies(p[1])) {
        final gen = p[0], sp = p[1];

        out.addAll(await _queryRaw('gen:$gen sp:$sp grp:birds'));

        // Filtro por calidad como fallback
        if (out.isEmpty) {
          out.addAll(await _queryRaw('gen:$gen sp:$sp grp:birds q:A'));
        }
      } else {
        if (debug) {
          print('[XC] "$latin" no pasa validación binomial; no consulto v3.');
        }
      }

      return out;
    }

    final raw = await _search(latin);
    if (raw.isEmpty) {
      if (debug) print('[XC] No hubo resultados para "$latin"');
      return const [];
    }

    final scored = <_Scored>[];
    for (final m in raw) {
      final audioUrl = _extractAudioUrl(
        m['file'] ?? m['fileUrl'] ?? m['url'] ?? m['download'],
      );
      if (audioUrl == null) continue;

      final sonoUrl =
          _sonogramFrom(m['sono']) ??
          _fixUrl(m['sonogram']?.toString()) ??
          _fixUrl(m['sono_large']?.toString()) ??
          _fixUrl(m['sono_med']?.toString()) ??
          _fixUrl(m['sono_small']?.toString());

      final isSvg = _looksLikeSvgUrl(sonoUrl);

      // ✅ PRINT para confirmar lo que realmente se extrajo
      if (debug) {
        print('[XC] AUDIO extraído => $audioUrl');
        print('[XC] SONO  extraído => $sonoUrl (svg=$isSvg)');
      }

      final title = [
        (m['gen'] ?? '').toString().trim(),
        (m['sp'] ?? '').toString().trim(),
        if ((m['ssp'] ?? '').toString().trim().isNotEmpty)
          (m['ssp'] ?? '').toString().trim(),
      ].where((s) => s.isNotEmpty).join(' ');

      final lenStr = (m['length'] as String?) ?? '';
      final lenSecs = _parseLengthSeconds(lenStr);
      final q = (m['q'] as String?)?.toUpperCase() ?? '';
      final qualityScore = (q == 'A')
          ? 2
          : (q == 'B')
          ? 1
          : 0;

      final dateStr = (m['date'] as String?) ?? '';
      final uploadedStr = (m['uploaded'] as String?) ?? '';
      final recency =
          DateTime.tryParse(uploadedStr) ??
          DateTime.tryParse(dateStr) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      scored.add(
        _Scored(
          XCRecording(
            id: (m['id'] ?? '').toString(),
            title: title.isEmpty ? latin : title,
            fileUrl: audioUrl,
            sonogramUrl: sonoUrl,
            sonogramIsSvg: isSvg,
            locality: m['loc'] as String?,
            length: lenStr,
            quality: (m['q'] as String?),
          ),
          qualityScore * 1000000 -
              lenSecs * 100 +
              recency.millisecondsSinceEpoch ~/ 1000000,
        ),
      );
    }

    // Dedup y top-N
    final seen = <String>{};
    final dedup = <_Scored>[];
    for (final s in scored) {
      if (seen.add(s.item.fileUrl)) dedup.add(s);
    }

    dedup.sort((a, b) => b.score.compareTo(a.score));
    final result = dedup.take(limit).map((e) => e.item).toList();

    if (debug) {
      print('[XC] RESULT FINAL => ${result.length} audios');
      if (result.isNotEmpty) print('[XC] EJEMPLO => ${result.first}');
    }

    return result;
  }

  // ------------------------- helpers -------------------------

  static const _articles = <String>{
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'unos',
    'unas',
    'del',
    'de',
    'al',
    'the',
    'a',
    'an',
    'of',
  };

  static String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

  static String _normalizeAccents(String input) {
    const map = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'ñ': 'n',
      'Ñ': 'N',
    };
    final sb = StringBuffer();
    for (final ch in input.runes) {
      final s = String.fromCharCode(ch);
      sb.write(map[s] ?? s);
    }
    return sb.toString();
  }

  static String? _extractBinomial(String text) {
    var t = _stripHtml(text).replaceAll('_', ' ').trim();
    t = _normalizeAccents(t);
    final words = t
        .split(RegExp(r'\s+'))
        .where((w) => !_articles.contains(w.toLowerCase()))
        .toList();
    if (words.length < 2) return null;
    final cand = '${words[0]} ${words[1]}';
    return (_isValidGenus(words[0]) && _isValidSpecies(words[1])) ? cand : null;
  }

  static bool _isValidGenus(String w) =>
      RegExp(r'^[A-Z][a-zA-Z\-]{2,}$').hasMatch(w) &&
      !_articles.contains(w.toLowerCase());

  static bool _isValidSpecies(String w) => RegExp(r'^[a-z\-]{2,}$').hasMatch(w);

  static Future<String?> _resolveToBinomialViaGbif(
    String text, {
    bool debug = false,
  }) async {
    final q = _stripHtml(text).replaceAll('_', ' ').trim();
    if (q.isEmpty) return null;

    try {
      final mr = await http.get(
        Uri.parse(
          'https://api.gbif.org/v1/species/match',
        ).replace(queryParameters: {'name': q}),
        headers: _headers,
      );
      if (mr.statusCode == 200) {
        final mj = json.decode(mr.body) as Map<String, dynamic>;
        final scn =
            (mj['scientificName'] ?? mj['canonicalName'] ?? '') as String;
        final parts = scn.split(' ');
        if (parts.length >= 2 &&
            _isValidGenus(parts.first) &&
            _isValidSpecies(parts[1])) {
          if (debug) print('[XC] GBIF/match -> $scn');
          return '${parts.first} ${parts[1]}';
        }
      }
    } catch (_) {}

    try {
      final sr = await http.get(
        Uri.parse(
          'https://api.gbif.org/v1/species/search',
        ).replace(queryParameters: {'q': q, 'limit': '1'}),
        headers: _headers,
      );
      if (sr.statusCode == 200) {
        final sj = json.decode(sr.body) as Map<String, dynamic>;
        final results = (sj['results'] ?? []) as List;
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final scn =
              (first['scientificName'] ?? first['canonicalName'] ?? '')
                  as String;
          final parts = scn.split(' ');
          if (parts.length >= 2 &&
              _isValidGenus(parts.first) &&
              _isValidSpecies(parts[1])) {
            if (debug) print('[XC] GBIF/search -> $scn');
            return '${parts.first} ${parts[1]}';
          }
        }
      }
    } catch (_) {}

    if (debug) print('[XC] GBIF no resolvió "$q"');
    return null;
  }

  static int _parseLengthSeconds(String len) {
    if (len.isEmpty) return 9999;
    final parts = len.split(':');
    if (parts.length == 1) return int.tryParse(parts[0]) ?? 9999;
    final m = int.tryParse(parts[0]) ?? 0;
    final s = int.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }
}

class _Scored {
  final XCRecording item;
  final int score;
  _Scored(this.item, this.score);
}
