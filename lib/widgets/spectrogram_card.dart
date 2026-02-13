import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/xeno_canto_service.dart';
import '../core/theme.dart';

class SpectrogramCard extends StatelessWidget {
  const SpectrogramCard({super.key, required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context) {
    if (scientificName.trim().isEmpty) {
      return const Text(
        'Sin nombre científico para mostrar el espectrograma.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return FutureBuilder<XCImage?>(
      future: XenoCantoService.fetchSpectrogram(scientificName, debug: true),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(color: kBrand),
          );
        }

        if (snap.hasError) {
          return Text(
            'No se pudo obtener el espectrograma.\n${snap.error}',
            style: const TextStyle(color: Colors.black54),
          );
        }

        final img = snap.data;
        if (img == null || img.url.trim().isEmpty) {
          return const Text(
            'No se encontró un espectrograma para esta especie.',
            style: TextStyle(color: Colors.black54),
          );
        }

        // ✅ Print final por si quiere verificar qué llega a UI
        print('[UI] Sonograma a mostrar => ${img.url} (svg=${img.isSvg})');

        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: img.isSvg
                  ? SvgPicture.network(
                      img.url,
                      headers: const {
                        'User-Agent': 'Mozilla/5.0',
                        'Accept': 'image/svg+xml,image/*',
                      },
                      fit: BoxFit.cover,
                      placeholderBuilder: (_) => Container(
                        height: 160,
                        color: const Color(0xFFEFEFEF),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: kBrand),
                        ),
                      ),
                    )
                  : Image.network(
                      img.url,
                      headers: const {
                        'User-Agent': 'Mozilla/5.0',
                        'Accept': 'image/*',
                      },
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFEFEFEF),
                        alignment: Alignment.center,
                        child: const Text(
                          'No fue posible cargar el espectrograma',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
