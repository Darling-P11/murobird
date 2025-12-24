// lib/screens/result/result_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../core/theme.dart';
import '../../services/wiki_bird_service.dart';
import '../../services/gbif_service.dart';
import '../../widgets/distribution_map.dart';
import '../../widgets/reference_audios.dart';
import '../../widgets/species_gallery_grid.dart';
import '../../widgets/spectrogram_card.dart';

// OFFLINE
import 'dart:io';
import '../../offline/offline_prefs.dart';
import '../../offline/offline_manager.dart';
import '../../offline/offline_models.dart';
import '../../widgets/distribution_map_offline.dart';
import 'package:flutter/painting.dart' show PaintingBinding;

/// ---------------- helpers binomiales / limpieza ----------------
String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');
String? _asLatin(String text) {
  final t = _stripHtml(text).replaceAll('*', ' ').trim();
  final m = RegExp(r'\b([A-Z][a-zA-Z-]+)\s+([a-z-]+)\b').firstMatch(t);
  if (m == null) return null;
  return '${m.group(1)!} ${m.group(2)!}';
}

String _cleanLabel(String raw) {
  final noTags = _stripHtml(raw);
  final norm = noTags
      .replaceAll('*', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final latin = _asLatin(norm);
  return latin ?? norm;
}

/// Acepta URL http(s) o ruta local; si no, placeholder.
ImageProvider _imgProvider(String? src) {
  if (src == null || src.isEmpty) {
    return const AssetImage('assets/mock/placeholder.jpg');
  }
  final s = src.toLowerCase();
  if (s.startsWith('http')) {
    if (s.startsWith('data:')) {
      return const AssetImage('assets/mock/placeholder.jpg');
    }
    if (s.endsWith('.svg') || s.contains('format=svg')) {
      return const AssetImage('assets/mock/placeholder.jpg');
    }
    return NetworkImage(src);
  }
  final f = File(src);
  if (f.existsSync()) return FileImage(f);
  return const AssetImage('assets/mock/placeholder.jpg');
}

bool _isSupportedNetImage(String url) {
  final u = url.toLowerCase();
  if (u.startsWith('data:')) return false;
  if (u.endsWith('.svg') || u.contains('format=svg')) return false;
  return u.startsWith('http');
}

/// normaliza para comparar duplicados
String _norm(String s) => _cleanLabel(
  s,
).replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

bool _already(List<_Candidate> xs, String name) =>
    xs.any((e) => _norm(e.name) == _norm(name));

/// ---------------------------------------------------------------

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // Paleta base (Orbix / OrBird)
  static const Color _brand = Color(0xFF001225);
  static const Color _glassFill = Color(
    0xFF0B2438,
  ); // << más oscuro para contraste

  late final List<_Candidate> _views; // máx 3
  int _current = 0;

  Future<dynamic> _loadDetails(String currentName) async {
    final offline = await OfflinePrefs.enabled;
    final ready = await OfflineManager.isReady();
    if (offline && ready) {
      final m = await OfflineManager.findByScientificName(currentName);
      if (m == null) return null;
      final adapted = await OfflineManager.adaptAssets(m);
      return OfflineBirdDetails.fromDb(adapted);
    } else {
      return await WikiBirdService.fetch(currentName);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = (ModalRoute.of(context)!.settings.arguments ?? {}) as Map;
    final rawTopBird = (args['topBird'] ?? '') as String;
    final topBird = _cleanLabel(rawTopBird);
    final List raw = (args['candidates'] ?? []) as List;

    final List<_Candidate> tmp = [];
    if (topBird.isNotEmpty && !_already(tmp, topBird)) {
      tmp.add(_Candidate(name: topBird, score: 1.0));
    }
    for (final c in raw) {
      final nm = _cleanLabel((c['name'] as String?) ?? '');
      if (nm.isEmpty) continue;
      if (_already(tmp, nm)) continue;
      tmp.add(
        _Candidate(
          name: nm,
          score: (c['confidence'] as num?)?.toDouble() ?? 0.0,
          start: (c['start'] as num?)?.toDouble(),
          end: (c['end'] as num?)?.toDouble(),
        ),
      );
      if (tmp.length >= 3) break;
    }
    _views = tmp.where((e) => e.name.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentName = _views[_current].name;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fondo global (con blanco abajo), pero cards ahora ya no pierden contraste
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _brand,
                  _brand.withOpacity(.94),
                  const Color(0xFFF4F7FA), // blanco suave (no puro)
                ],
                stops: const [0, .50, 1],
              ),
            ),
          ),

          FutureBuilder<dynamic>(
            key: ValueKey('fb-$currentName'),
            future: _loadDetails(currentName),
            builder: (context, snap) {
              final waiting =
                  snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData;
              final data = snap.data;

              final bool isOffline = data is OfflineBirdDetails;
              final OfflineBirdDetails? off = isOffline
                  ? data as OfflineBirdDetails
                  : null;
              final BirdDetails? onl = !isOffline ? data as BirdDetails? : null;

              final sciName = isOffline
                  ? off!.scientificName
                  : (_asLatin(onl?.displayTitle ?? '') ??
                            _asLatin(onl?.scientificName ?? '') ??
                            _asLatin(currentName) ??
                            '')
                        .trim();

              final displayTitle = isOffline
                  ? (off!.displayTitle.isNotEmpty
                        ? off.displayTitle
                        : currentName)
                  : (_cleanLabel(onl?.displayTitle ?? currentName));

              final heroSrc = isOffline
                  ? (off!.coverImage ?? '')
                  : (onl?.mainImage ?? '');
              final hero = (heroSrc.isNotEmpty) ? heroSrc : null;

              final List<String> galNet = (onl?.gallery ?? [])
                  .whereType<String>()
                  .where(_isSupportedNetImage)
                  .toList();

              final thumbUrl =
                  hero ??
                  (isOffline
                      ? (off!.gallery.isNotEmpty ? off.gallery.first : null)
                      : (galNet.isNotEmpty ? galNet.first : null));

              if (thumbUrl != null && _views[_current].lastMainImage == null) {
                _views[_current].lastMainImage = thumbUrl;
              }

              final leftIndex = (_current - 1) >= 0 ? _current - 1 : null;
              final rightIndex = (_current + 1) < _views.length
                  ? _current + 1
                  : null;

              return SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Header(
                        key: ValueKey('head-$sciName'),
                        index: _current,
                        total: _views.length,
                        onBack: () => Navigator.pop(context),
                        onPickIndex: (i) {
                          setState(() => _current = i);
                          PaintingBinding.instance.imageCache.clear();
                          PaintingBinding.instance.imageCache.clearLiveImages();
                        },
                        onShare: () {
                          final uri = Uri.parse(
                            'https://www.google.com/search?q=$currentName ave',
                          );
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        mainImage: hero,
                        sideLeftImage: leftIndex != null
                            ? _views[leftIndex].lastMainImage
                            : null,
                        sideRightImage: rightIndex != null
                            ? _views[rightIndex].lastMainImage
                            : null,
                        displayTitle: displayTitle,
                        alsoKnown: '—',
                        scientific: sciName,
                        familyTitle: (sciName.isNotEmpty
                            ? sciName.split(' ').first
                            : (_asLatin(currentName)?.split(' ').first ?? '')),
                        familySci: '',
                      ),
                    ),

                    if (waiting)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: LinearProgressIndicator(color: Colors.white),
                        ),
                      ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _GlassCard(
                              fill: _glassFill,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionRow(
                                      icon: Icons.menu_book_rounded,
                                      title: 'Descripción',
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      isOffline
                                          ? ((off!.descriptionEs ??
                                                    off.descriptionEn ??
                                                    'Sin descripción.')
                                                .trim())
                                          : ((onl?.summary ??
                                                    'No encontramos una descripción para esta especie. Intenta con otro nombre o revisa tu grabación.')
                                                .trim()),
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        height: 1.35,
                                        color: Colors.white.withOpacity(.92),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            _GlassCard(
                              fill: _glassFill,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionRow(
                                      icon: Icons.podcasts_rounded,
                                      title: 'Audios de referencia',
                                    ),
                                    const SizedBox(height: 8),
                                    if (isOffline && (off!.audios.isNotEmpty))
                                      _LocalAudioList(
                                        key: ValueKey(
                                          'aud-off-${off.audios.join("|")}',
                                        ),
                                        files: off.audios,
                                      )
                                    else if (sciName.isNotEmpty)
                                      // ✅ Forzamos tema oscuro para que no salgan textos negros
                                      _OnDark(
                                        child: ReferenceAudios(
                                          key: ValueKey('aud-$sciName'),
                                          scientificName: sciName,
                                          limit: 6,
                                        ),
                                      )
                                    else
                                      Text(
                                        'No hay audios de referencia disponibles.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.86),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            _GlassCard(
                              fill: _glassFill,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionRow(
                                      icon: Icons.show_chart,
                                      title: 'Espectrograma',
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: SizedBox(
                                        height: 170,
                                        width: double.infinity,
                                        child:
                                            (isOffline &&
                                                off!.spectrograms.isNotEmpty)
                                            ? Image.file(
                                                File(off.spectrograms.first),
                                                key: ValueKey(
                                                  'spec-off-${off.spectrograms.first}',
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : _OnDark(
                                                // ✅ para que el placeholder se lea (si el widget usa estilos por defecto)
                                                child: SpectrogramCard(
                                                  key: ValueKey(
                                                    'spec-$sciName',
                                                  ),
                                                  scientificName: sciName,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            _GlassCard(
                              fill: _glassFill,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionRow(
                                      icon: Icons.public_rounded,
                                      title: 'Mapa de distribución',
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child:
                                          (isOffline &&
                                              (off!
                                                      .distributionGeoJson
                                                      ?.isNotEmpty ??
                                                  false))
                                          ? DistributionMapOffline(
                                              key: ValueKey(
                                                'map-off-${off.distributionGeoJson}',
                                              ),
                                              geoJsonPath:
                                                  off.distributionGeoJson!,
                                            )
                                          : FutureBuilder<int?>(
                                              key: ValueKey('map-$sciName'),
                                              future: sciName.isNotEmpty
                                                  ? GbifService.fetchSpeciesKey(
                                                      sciName,
                                                    )
                                                  : Future.value(null),
                                              builder: (context, snapGbif) {
                                                if (snapGbif.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: 10,
                                                        ),
                                                    child:
                                                        LinearProgressIndicator(
                                                          color: Colors.white,
                                                        ),
                                                  );
                                                }
                                                final speciesKey =
                                                    snapGbif.data;
                                                if (speciesKey == null) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 6,
                                                        ),
                                                    child: Text(
                                                      'No encontramos el taxón en GBIF.',
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withOpacity(.82),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return DistributionMap(
                                                  key: ValueKey(
                                                    'dist-$speciesKey',
                                                  ),
                                                  taxonKey: speciesKey
                                                      .toString(),
                                                  showPoints: true,
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            _GlassCard(
                              fill: _glassFill,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionRow(
                                      icon: Icons.photo_camera_back_rounded,
                                      title: 'Galería',
                                    ),
                                    const SizedBox(height: 10),

                                    if (isOffline) ...[
                                      (() {
                                        final imgs = <String>[];
                                        if (off!.coverImage != null &&
                                            off.coverImage!.isNotEmpty) {
                                          imgs.add(off.coverImage!);
                                        }
                                        imgs.addAll(
                                          off.gallery.where(
                                            (e) => e.isNotEmpty,
                                          ),
                                        );

                                        final seen = <String>{};
                                        final finalList = <String>[];
                                        for (final p in imgs) {
                                          if (seen.add(p)) finalList.add(p);
                                        }

                                        if (finalList.isEmpty) {
                                          return Text(
                                            'Sin imágenes disponibles.',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                .82,
                                              ),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          );
                                        }

                                        return GridView.builder(
                                          key: ValueKey(
                                            'gal-off-${finalList.join("|")}',
                                          ),
                                          itemCount: finalList.length,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 2,
                                                mainAxisSpacing: 12,
                                                crossAxisSpacing: 12,
                                              ),
                                          itemBuilder: (_, i) => ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Image(
                                              image: _imgProvider(finalList[i]),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        );
                                      })(),
                                    ] else ...[
                                      SpeciesGalleryGrid(
                                        key: ValueKey('gal-$sciName'),
                                        scientificName: sciName,
                                        initialUrls: galNet,
                                        limit: 12,
                                        debug: false,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            _GlassCard(
                              fill: _glassFill,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionRow(
                                      icon: Icons.pets_rounded,
                                      title: 'Otras coincidencias',
                                    ),
                                    const SizedBox(height: 10),
                                    if (_views.length <= 1)
                                      Text(
                                        'No se encontraron más especies.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.82),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    else
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: List.generate(_views.length, (
                                          i,
                                        ) {
                                          final v = _views[i];
                                          final selected = i == _current;
                                          return ChoiceChip(
                                            selected: selected,
                                            label: Text(
                                              v.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            labelStyle: TextStyle(
                                              color: selected
                                                  ? const Color(0xFF001225)
                                                  : Colors.white.withOpacity(
                                                      .92,
                                                    ),
                                              fontWeight: FontWeight.w900,
                                            ),
                                            backgroundColor: Colors.white
                                                .withOpacity(.12),
                                            selectedColor: Colors.white
                                                .withOpacity(.92),
                                            side: BorderSide(
                                              color: Colors.white.withOpacity(
                                                .18,
                                              ),
                                            ),
                                            onSelected: (_) {
                                              setState(() => _current = i);
                                              PaintingBinding
                                                  .instance
                                                  .imageCache
                                                  .clear();
                                              PaintingBinding
                                                  .instance
                                                  .imageCache
                                                  .clearLiveImages();
                                            },
                                          );
                                        }),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ===== Header (estilo Orbix / OrBird) =====
class _Header extends StatelessWidget {
  const _Header({
    super.key,
    required this.index,
    required this.total,
    required this.onBack,
    required this.onPickIndex,
    required this.onShare,
    required this.mainImage,
    required this.sideLeftImage,
    required this.sideRightImage,
    required this.displayTitle,
    required this.alsoKnown,
    required this.scientific,
    required this.familyTitle,
    required this.familySci,
  });

  final int index, total;
  final VoidCallback onBack, onShare;
  final ValueChanged<int> onPickIndex;
  final String? mainImage, sideLeftImage, sideRightImage;

  final String displayTitle;
  final String alsoKnown;
  final String scientific;
  final String familyTitle;
  final String familySci;

  static const Color _brand = Color(0xFF001225);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_brand, _brand.withOpacity(.92), Colors.transparent],
                stops: const [0, .82, 1],
              ),
            ),
          ),

          Positioned(
            top: 10,
            left: 12,
            child: _HeaderIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
          ),

          Positioned(
            top: 10,
            right: 12,
            child: _HeaderIconButton(
              icon: Icons.share_outlined,
              onTap: onShare,
            ),
          ),

          if (sideLeftImage != null)
            Positioned(
              left: -20,
              top: 82,
              child: _SideAvatar(imageSrc: sideLeftImage!),
            ),
          if (sideRightImage != null)
            Positioned(
              right: -20,
              top: 82,
              child: _SideAvatar(imageSrc: sideRightImage!),
            ),

          Positioned(
            top: 44,
            left: 0,
            right: 0,
            child: Center(child: _MainAvatar(imageSrc: mainImage)),
          ),

          Positioned(
            top: 232,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                total,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _IndexDot(
                    label: '${i + 1}',
                    selected: i == index,
                    onTap: () => onPickIndex(i),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            top: 268,
            child: _TitlePill(
              titleLeading: displayTitle,
              titleFamily: familyTitle.isNotEmpty ? familyTitle : '—',
              familySci: familySci,
              alsoKnown: alsoKnown.isNotEmpty ? alsoKnown : '—',
              scientific: scientific.isNotEmpty ? scientific : '—',
            ),
          ),
        ],
      ),
    );
  }
}

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

class _SideAvatar extends StatelessWidget {
  const _SideAvatar({super.key, required this.imageSrc});
  final String imageSrc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(.10),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: ClipOval(
        child: Image(
          key: ValueKey('side-$imageSrc'),
          image: _imgProvider(imageSrc),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _MainAvatar extends StatelessWidget {
  const _MainAvatar({super.key, this.imageSrc});
  final String? imageSrc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(.10),
        border: Border.all(color: Colors.white.withOpacity(.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image(
          key: ValueKey('main-${imageSrc ?? "none"}'),
          image: _imgProvider(imageSrc),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _IndexDot extends StatelessWidget {
  const _IndexDot({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(.18)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected
                ? const Color(0xFF001225)
                : Colors.white.withOpacity(.92),
          ),
        ),
      ),
    );
  }
}

class _TitlePill extends StatelessWidget {
  const _TitlePill({
    required this.titleLeading,
    required this.titleFamily,
    required this.familySci,
    required this.alsoKnown,
    required this.scientific,
  });

  final String titleLeading, titleFamily, familySci, alsoKnown, scientific;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      fill: const Color(0xFF0B2438),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleLeading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Grupo: $titleFamily${familySci.isNotEmpty ? ' ($familySci)' : ''}',
              style: TextStyle(
                color: Colors.white.withOpacity(.86),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'También conocido como: $alsoKnown',
              style: TextStyle(
                color: Colors.white.withOpacity(.82),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nombre científico: $scientific',
              style: TextStyle(
                color: Colors.white.withOpacity(.92),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card glass reutilizable (ahora con fill configurable y más contraste)
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color fill;
  const _GlassCard({required this.child, this.fill = const Color(0xFF0B2438)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fill.withOpacity(.78), // ✅ importante: más sólido
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.18), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Forza estilo oscuro para widgets que internamente pintan textos negros/grises
class _OnDark extends StatelessWidget {
  final Widget child;
  const _OnDark({required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    // Un "dark theme" fuerte para anular textos grises/oscuros dentro de widgets externos
    final dark = base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,

      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Color(0xFF001225),
        surface: Color(0xFF0B2438),
        onSurface: Colors.white,
        background: Color(0xFF0B2438),
        onBackground: Colors.white,
      ),

      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),

      iconTheme: const IconThemeData(color: Colors.white),

      listTileTheme: ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
        tileColor: Colors.transparent,
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(.14),
        thickness: 1,
      ),
    );

    return Theme(
      data: dark,
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}

/// Título de sección (fila con ícono)
class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(.92)),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(.96),
          ),
        ),
      ],
    );
  }
}

/// Modelo simple para las vistas 1..3
class _Candidate {
  _Candidate({required this.name, required this.score, this.start, this.end});
  final String name;
  final double score;
  final double? start, end;
  String? lastMainImage;
}

/// ================= Audios locales =================
class _LocalAudioList extends StatefulWidget {
  const _LocalAudioList({super.key, required this.files});
  final List<String> files;

  @override
  State<_LocalAudioList> createState() => _LocalAudioListState();
}

class _LocalAudioListState extends State<_LocalAudioList> {
  final _player = AudioPlayer();
  String? _current;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  PlayerState _state = PlayerState.stopped;

  @override
  void didUpdateWidget(covariant _LocalAudioList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.files.join('|') != widget.files.join('|')) {
      _player.stop();
      _current = null;
      _pos = Duration.zero;
      _dur = Duration.zero;
      _state = PlayerState.stopped;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(String path) async {
    if (_current == path && _state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_current != path) {
      _current = path;
      _pos = Duration.zero;
      _dur = Duration.zero;
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } else {
      await _player.resume();
    }
    setState(() {});
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    return hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return Text(
        'No hay audios de referencia disponibles.',
        style: TextStyle(
          color: Colors.white.withOpacity(.86),
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Column(
      children: widget.files.map((path) {
        final selected = _current == path;
        final playing = selected && _state == PlayerState.playing;
        final name = path.split('/').last;

        final pos = selected ? _pos : Duration.zero;
        final dur = selected
            ? (_dur == Duration.zero ? const Duration(seconds: 1) : _dur)
            : const Duration(seconds: 1);

        final value =
            pos.inMilliseconds.clamp(0, dur.inMilliseconds) /
            dur.inMilliseconds;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(.16)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _toggle(path),
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(.16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    inactiveTrackColor: Colors.white.withOpacity(.20),
                    activeTrackColor: Colors.white.withOpacity(.88),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
                    onChanged: selected && _dur > Duration.zero
                        ? (v) async {
                            final target = Duration(
                              milliseconds: (v * _dur.inMilliseconds).round(),
                            );
                            await _player.seek(target);
                          }
                        : null,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(pos),
                      style: TextStyle(
                        color: Colors.white.withOpacity(.80),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _fmt(selected ? _dur : Duration.zero),
                      style: TextStyle(
                        color: Colors.white.withOpacity(.80),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
