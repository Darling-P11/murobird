import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class UploadAudioScreen extends StatelessWidget {
  const UploadAudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // Header con marca y bordes redondeados
          SliverAppBar(
            backgroundColor: kBrand,
            pinned: true,
            toolbarHeight: 96,
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_birby.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.podcasts_rounded, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MuroBird',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '¿Tienes un audio de algún ave?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '¡Súbelo aquí!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Botón de selección de archivo
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Seleccionar archivo de audio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () {
                        // TODO: file picker
                      },
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ===== TABLA SIN "FORMATO" - RESPONSIVA Y SIN OVERFLOW =====
                  const _FilesTable(
                    rows: [
                      _FileRow('10:15', '001_AudioGrabado'),
                      _FileRow('20:11', '002_AudioGrabado'),
                      _FileRow('01:23', '003_AudioGrabado'),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Requisitos
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Requisitos a seguir para el análisis:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '* Formato: .mp3, .wav, .m4a\n'
                      '* Tiempo (máx): 30 minutos\n'
                      '* Tiempo (mín): 30 segundos\n'
                      '* Máximo de audio por análisis: 3',
                      style: TextStyle(fontSize: 16, height: 1.35),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, Routes.searching),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Analizar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kBrand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 22,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* =======================  WIDGETS DE LA TABLA  ======================= */

class _FilesTable extends StatelessWidget {
  const _FilesTable({required this.rows});
  final List<_FileRow> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final compact = width < 380; // teléfonos angostos
        return _TableCore(rows: rows, compact: compact);
      },
    );
  }
}

class _TableCore extends StatelessWidget {
  const _TableCore({required this.rows, required this.compact});
  final List<_FileRow> rows;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: compact ? 12 : 14,
    );

    // SIN columna de Formato
    final timeFlex = 24;
    final nameFlex = 52;
    final actFlex = 24; // más ancho para iconos

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBrand, width: 3),
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias, // evita que algo pinte fuera
      child: Column(
        children: [
          // Header verde
          Container(
            decoration: const BoxDecoration(
              color: kBrand,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            padding: EdgeInsets.symmetric(
              vertical: compact ? 10 : 14,
              horizontal: compact ? 10 : 12,
            ),
            child: Row(
              children: [
                _HeaderCell(
                  'Hora',
                  flex: timeFlex,
                  style: headerStyle,
                  center: true,
                ),
                const _VSep(),
                _HeaderCell(
                  'Nombre del archivo',
                  flex: nameFlex,
                  style: headerStyle,
                  center: true,
                ),
                const _VSep(),
                _HeaderCell(
                  'Acciones',
                  flex: actFlex,
                  style: headerStyle,
                  center: true,
                ),
              ],
            ),
          ),

          // Filas
          for (int i = 0; i < rows.length; i++) ...[
            _DataRow(
              row: rows[i],
              compact: compact,
              timeFlex: timeFlex,
              nameFlex: nameFlex,
              actFlex: actFlex,
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.text, {
    required this.flex,
    required this.style,
    this.center = false,
  });

  final String text;
  final int flex;
  final TextStyle style;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: style,
        ),
      ),
    );
  }
}

class _VSep extends StatelessWidget {
  const _VSep();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 22, color: Colors.white);
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.row,
    required this.compact,
    required this.timeFlex,
    required this.nameFlex,
    required this.actFlex,
  });

  final _FileRow row;
  final bool compact;
  final int timeFlex;
  final int nameFlex;
  final int actFlex;

  @override
  Widget build(BuildContext context) {
    final textStyleBold = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 13 : 14,
    );
    final textStyle = TextStyle(fontSize: compact ? 13 : 14);

    // Botones realmente compactos (para que siempre quepan)
    final iconSize = compact ? 18.0 : 20.0;
    final constraints = BoxConstraints.tightFor(
      width: compact ? 32 : 34,
      height: compact ? 32 : 34,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 8 : 10,
        horizontal: compact ? 8 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: timeFlex,
            child: Text(row.time, style: textStyleBold),
          ),
          Expanded(
            flex: nameFlex,
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          Expanded(
            flex: actFlex,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown, // si aún falta ancho, reduce suavemente
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: constraints,
                      iconSize: iconSize,
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow_rounded, color: kBrand),
                      splashRadius: 18,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: constraints,
                      iconSize: iconSize,
                      onPressed: () {},
                      icon: const Icon(Icons.delete_outline, color: kBrand),
                      splashRadius: 18,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: constraints,
                      iconSize: iconSize,
                      onPressed: () {},
                      icon: const Icon(Icons.sync, color: kBrand),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow {
  final String time;
  final String name;
  const _FileRow(this.time, this.name);
}
