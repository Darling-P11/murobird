import 'package:flutter/material.dart';
import '../../core/theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)!.settings.arguments ?? {}) as Map;
    final topBird = (args['topBird'] ?? '—') as String;
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            topBird,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          const Divider(),

          Text(
            'Otras coincidencias',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          if (candidates.isEmpty)
            const Text(
              'No se encontraron más especies.',
              style: TextStyle(color: Colors.black54),
            ),

          for (final c in candidates)
            _BirdRow(
              name: c['name'] as String,
              score: (c['confidence'] as num).toDouble(),
              start: (c['start'] as num).toDouble(),
              end: (c['end'] as num).toDouble(),
            ),
        ],
      ),
    );
  }
}

class _BirdRow extends StatelessWidget {
  const _BirdRow({
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
              value: score.clamp(0.0, 1.0),
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
