import 'package:flutter/material.dart';
import '../services/xeno_canto_service.dart' show XenoCantoService, XCRecording;
import 'xc_audio_list.dart';

class ReferenceAudios extends StatelessWidget {
  const ReferenceAudios({super.key, required this.scientificName});
  final String scientificName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XCRecording>>(
      future: XenoCantoService.fetchBySpecies(scientificName, limit: 6),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(color: Color(0xFF10A37F)),
          );
        }
        final items = snap.data ?? const <XCRecording>[];
        return XCAudioList(items: items);
      },
    );
  }
}
