// lib/screens/history/history_screen.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/routes.dart';
import '../../widgets/bottom_nav_scaffold.dart';
import 'history_store.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  static const Color _brand = Color(0xFF001225);

  List<CollectionItem> _items = [];
  bool _loading = true;

  final Map<String, String?> _thumbCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final col = await HistoryStore.buildCollection();
    setState(() {
      _items = col;
      _loading = false;
    });
  }

  Future<String?> _fetchThumb(String title) async {
    if (_thumbCache.containsKey(title)) return _thumbCache[title];

    Future<String?> tryLang(String lang, String q) async {
      final url =
          'https://$lang.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(q)}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;

      final m = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      String? pick(Map<String, dynamic> x, String k) =>
          (x[k] is Map) ? (x[k]['source'] as String?) : null;

      final original = pick(m, 'originalimage');
      final thumb = pick(m, 'thumbnail');
      String? best = original ?? thumb;

      if (best == null) return null;
      final u = best.toLowerCase();
      if (u.startsWith('data:')) return null;
      if (u.endsWith('.svg') || u.contains('format=svg')) return null;
      return best;
    }

    final q = title.trim();
    final img = await tryLang('es', q) ?? await tryLang('en', q);

    _thumbCache[title] = img;
    return img;
  }

  Future<String?> _thumbFor(CollectionItem e) async {
    return await _fetchThumb(e.scientificName) ??
        await _fetchThumb(e.commonName);
  }

  Future<bool> _handleBack(BuildContext context) async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed(Routes.home);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return WillPopScope(
      onWillPop: () => _handleBack(context),
      child: BottomNavScaffold(
        child: Stack(
          children: [
            // ===== Fondo (igual Home) =====
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
                // ===== HERO HEADER =====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, top + 10, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar
                        Row(
                          children: [
                            Builder(
                              builder: (context) => _HeaderIconButton(
                                icon: Icons.grid_view_rounded,
                                onTap: () => Scaffold.of(context).openDrawer(),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Título + subtítulo centrados
                        const SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Mi colección',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                  letterSpacing: .2,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Aquí verás las aves que has guardado con su información e imagen.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color.fromRGBO(255, 255, 255, .82),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Chips + Refresh
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              const _StatusChip(
                                icon: Icons.collections_bookmark_rounded,
                                label: 'Guardadas',
                              ),
                              _StatusChip(
                                icon: Icons.layers_rounded,
                                label: '${_items.length} aves',
                              ),
                              _StatusChip(
                                icon: Icons.refresh_rounded,
                                label: 'Actualizar',
                                onTap: _load,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== CONTENIDO =====
                if (_loading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Center(
                        child: _GlassCard(
                          child: SizedBox(
                            height: 110,
                            child: Row(
                              children: [
                                const SizedBox(width: 18),
                                const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.8,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Cargando colección…',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.92),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 44),
                      child: _EmptyStateModern(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 3 / 3.25,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _BirdCardModern(
                          brand: _brand,
                          item: _items[i],
                          thumbFuture: _thumbFor(_items[i]),
                        ),
                        childCount: _items.length,
                      ),
                    ),
                  ),

                // ===== Footer Orbix =====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    child: Center(
                      child: Opacity(
                        opacity: 0.55,
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo_orbix.png',
                              width: 70,
                              height: 70,
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
                  ),
                ),

                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================ UI helpers ============================= */

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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _StatusChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(.92)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(.92),
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(.16),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/* ============================ Cards modern ============================= */

class _BirdCardModern extends StatelessWidget {
  const _BirdCardModern({
    required this.brand,
    required this.item,
    required this.thumbFuture,
  });

  final Color brand;
  final CollectionItem item;
  final Future<String?> thumbFuture;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(.06), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 2,
                child: FutureBuilder<String?>(
                  future: thumbFuture,
                  builder: (context, snap) {
                    final waiting =
                        snap.connectionState == ConnectionState.waiting;
                    final url = snap.data;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Color(0xFFEFEFEF)),
                        if (url != null && url.isNotEmpty)
                          Image.network(
                            url,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            loadingBuilder: (c, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.6,
                                      ),
                                    ),
                                  ),
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 36,
                                color: Colors.black26,
                              ),
                            ),
                          )
                        else if (waiting)
                          const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                              ),
                            ),
                          )
                        else
                          const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.black26,
                              size: 36,
                            ),
                          ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: IconButton(
                              iconSize: 20,
                              tooltip: 'Más',
                              onPressed: () => _showInfo(context, item, brand),
                              icon: Icon(Icons.more_horiz, color: brand),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  item.commonName.isNotEmpty
                      ? item.commonName
                      : item.scientificName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: .2,
                    color: Color(0xFF2F3B39),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, CollectionItem e, Color brand) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        String fmtDate(DateTime? d) {
          if (d == null) return '—';
          String two(int x) => x.toString().padLeft(2, '0');
          return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: brand),
                  const SizedBox(width: 8),
                  const Text(
                    'Información breve',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _kv('Ave', e.commonName.isNotEmpty ? e.commonName : '—'),
              _kv(
                'Nombre científico',
                e.scientificName.isNotEmpty ? e.scientificName : '—',
              ),
              _kv('Vistas', e.views.toString()),
              _kv(
                'Mejor confianza',
                e.bestConfidence != null
                    ? '${e.bestConfidence!.toStringAsFixed(0)} %'
                    : '—',
              ),
              _kv('Última vez', fmtDate(e.lastSeen)),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _kv(String key, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 140,
        child: Text(
          key,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(value, softWrap: true)),
    ],
  ),
);

class _EmptyStateModern extends StatelessWidget {
  const _EmptyStateModern();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: _GlassCard(
        child: SizedBox(
          height: 160,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.collections_bookmark_outlined,
                  size: 58,
                  color: Colors.white.withOpacity(.85),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sin aves guardadas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(.95),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tu colección mostrará el nombre y una foto de Internet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.80),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
