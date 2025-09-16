import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/wiki_bird_service.dart';
import '../../services/gbif_service.dart';
import '../../widgets/distribution_map.dart';
import '../../widgets/reference_audios.dart'; // usa audioplayers integrado

// ---------------------- Helpers ----------------------
String _cleanLabel(String raw) {
  final noTags = raw.replaceAll(RegExp(r'<[^>]+>'), '');
  final norm = noTags
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final m = RegExp(r'([A-Z][a-zA-Z\-]+)\s+([a-z\-]+)').firstMatch(norm);
  return (m != null) ? '${m.group(1)} ${m.group(2)}' : norm;
}

bool _isSupportedImage(String url) {
  final u = url.toLowerCase();
  if (u.startsWith('data:')) return false;
  if (u.endsWith('.svg') || u.contains('format=svg')) return false;
  return u.startsWith('http');
}
// ----------------------------------------------------

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)!.settings.arguments ?? {}) as Map;
    final rawTopBird = (args['topBird'] ?? '') as String;
    final topBird = _cleanLabel(rawTopBird);
    final List candidates = (args['candidates'] ?? []) as List;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Resultados',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<BirdDetails?>(
        future: topBird.isNotEmpty
            ? WikiBirdService.fetch(topBird)
            : Future.value(null),
        builder: (context, snapWiki) {
          if (snapWiki.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kBrand),
            );
          }

          final data = snapWiki.data;
          final sciName = _cleanLabel((data?.scientificName ?? topBird).trim());
          final displayTitle = _cleanLabel((data?.displayTitle ?? topBird));

          final hero =
              (data?.mainImage != null && _isSupportedImage(data!.mainImage!))
              ? data!.mainImage!
              : null;

          final gallery = (data?.gallery ?? [])
              .whereType<String>()
              .where(_isSupportedImage)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ===== Cabecera =====
              Text(
                'Ave principal',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                displayTitle,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (sciName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  sciName,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (hero != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    hero,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: const Color(0xFFEFEFEF),
                      alignment: Alignment.center,
                      child: const Text(
                        'Imagen no disponible',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(),

              // ===== Descripción =====
              const _Section('Descripción', Icons.menu_book_rounded),
              const SizedBox(height: 8),
              Text(
                (data?.summary ??
                        'No encontramos una descripción para esta especie. Intenta con otro nombre o revisa tu grabación.')
                    .trim(),
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 22),

              // ===== Audios de referencia =====
              const _Section('Audios de referencia', Icons.podcasts_rounded),
              const SizedBox(height: 8),
              if (sciName.isNotEmpty)
                ReferenceAudios(scientificName: sciName)
              else
                const Text(
                  'No hay audios de referencia disponibles.',
                  style: TextStyle(color: Colors.black54),
                ),

              const SizedBox(height: 24),

              // ===== Mapa de distribución =====
              const _Section('Mapa de distribución', Icons.public_rounded),
              const SizedBox(height: 10),
              FutureBuilder<int?>(
                future: sciName.isNotEmpty
                    ? GbifService.fetchSpeciesKey(sciName)
                    : Future.value(null),
                builder: (context, snapGbif) {
                  if (snapGbif.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: LinearProgressIndicator(color: kBrand),
                    );
                  }
                  final speciesKey = snapGbif.data;
                  if (speciesKey == null) {
                    return const Text(
                      'No encontramos el taxón en GBIF.',
                      style: TextStyle(color: Colors.black54),
                    );
                  }
                  return DistributionMap(
                    taxonKey: speciesKey.toString(),
                    showPoints: true,
                  );
                },
              ),

              const SizedBox(height: 24),

              // ===== Galería =====
              const _Section('Galería', Icons.photo_camera_back_rounded),
              const SizedBox(height: 10),
              if (gallery.isNotEmpty)
                GridView.builder(
                  itemCount: gallery.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      gallery[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFEFEFEF),
                        alignment: Alignment.center,
                        child: const Text(
                          'Imagen no disponible',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Text(
                  'Sin imágenes disponibles.',
                  style: TextStyle(color: Colors.black54),
                ),

              const SizedBox(height: 24),

              // ===== Otras coincidencias =====
              const _Section('Otras coincidencias', Icons.pets_rounded),
              const SizedBox(height: 8),
              if (candidates.isEmpty)
                const Text(
                  'No se encontraron más especies.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                ...candidates.map(
                  (c) => _CandidateTile(
                    name: _cleanLabel(c['name'] as String),
                    score: (c['confidence'] as num).toDouble(),
                    start: (c['start'] as num).toDouble(),
                    end: (c['end'] as num).toDouble(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.name,
    required this.score,
    required this.start,
    required this.end,
  });
  final String name;
  final double score;
  final double start;
  final double end;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).clamp(0, 100).toStringAsFixed(0);
    return Card(
      elevation: 0.5,
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: score.clamp(0, 1),
              color: kBrand,
              backgroundColor: Colors.black12,
            ),
            const SizedBox(height: 6),
            Text(
              'Confianza: $pct%  •  ${start.toStringAsFixed(1)}s – ${end.toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
