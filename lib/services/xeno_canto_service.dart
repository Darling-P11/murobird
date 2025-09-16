import 'dart:convert';
import 'package:http/http.dart' as http;

const _headers = {
  // Identifica el cliente para evitar filtros raros en XC
  'User-Agent':
      'MuroBird/1.0 (https://example.com; contacto: dev@murobird.app)',
};

class XCRecording {
  final String id; // XC num (si viene)
  final String title; // Nombre legible
  final String fileUrl; // URL reproducible directa
  final String? locality;
  final String? length;
  final String? quality;

  XCRecording({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.locality,
    this.length,
    this.quality,
  });
}

class XenoCantoService {
  static Future<List<XCRecording>> fetchBySpecies(
    String label, {
    int limit = 6,
    bool debug = false,
  }) async {
    final latin =
        _extractBinomial(label) ??
        _stripHtml(label).replaceAll('_', ' ').trim();

    Future<List<XCRecording>> _query(String q) async {
      final url = Uri.parse(
        'https://xeno-canto.org/api/2/recordings?query=${Uri.encodeQueryComponent(q)}',
      );
      if (debug) print('[XC] $url');
      final r = await http.get(url, headers: _headers);
      if (r.statusCode != 200) return [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final recs = (j['recordings'] ?? []) as List;

      final out = <XCRecording>[];
      for (final it in recs.take(limit)) {
        final m = it as Map<String, dynamic>;
        final file = (m['file'] as String?)?.trim();
        if (file == null || file.isEmpty) continue;

        // XC suele devolver "//..." o "/12345/download"
        final resolved = file.startsWith('http')
            ? file
            : 'https:${file.startsWith('//') ? file : '//xeno-canto.org/$file'}';

        final title = [
          (m['gen'] ?? '').toString().trim(),
          (m['sp'] ?? '').toString().trim(),
          if ((m['ssp'] ?? '').toString().trim().isNotEmpty)
            (m['ssp'] ?? '').toString().trim(),
        ].where((s) => s.isNotEmpty).join(' ');

        out.add(
          XCRecording(
            id: (m['id'] ?? '').toString(),
            title: title.isEmpty ? latin : title,
            fileUrl: resolved,
            locality: m['loc'] as String?,
            length: m['length'] as String?,
            quality: m['q'] as String?,
          ),
        );
      }
      if (debug) print('[XC] ${out.length} resultados');
      return out;
    }

    // gen/sp primero, luego fallbacks
    final p = latin.split(RegExp(r'\s+'));
    if (p.length >= 2) {
      final gen = p[0], sp = p[1];
      final r1 = await _query('gen:$gen sp:$sp');
      if (r1.isNotEmpty) return r1;

      final r2 = await _query(
        'gen:$gen sp:$sp q:A,B',
      ); // prioriza calidades buenas
      if (r2.isNotEmpty) return r2;

      final r3 = await _query('$gen $sp');
      if (r3.isNotEmpty) return r3;
    }

    // fallback final
    return _query(latin);
  }

  static String? _extractBinomial(String text) {
    final t = _stripHtml(text).replaceAll('_', ' ');
    final m = RegExp(
      r'\b([A-Z][a-zA-Z\-]+)\s+([a-z\-]+)\b',
    ).firstMatch(_capFirst(t));
    return m?.group(0);
  }

  static String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

  static String _capFirst(String s) {
    if (s.isEmpty) return s;
    final p = s.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return s;
    p[0] = p[0][0].toUpperCase() + p[0].substring(1);
    return p.join(' ');
  }
}
