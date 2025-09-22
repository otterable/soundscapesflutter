import 'package:flutter/material.dart';
import '../api_service.dart';
import 'audio_tile.dart';

class AudioGrid extends StatelessWidget {
  final List<SoundFile> files;
  const AudioGrid({super.key, required this.files});

  int _columnsForWidth(double w) {
    if (w >= 1400) return 6;
    if (w >= 1100) return 5;
    if (w >= 900) return 4;
    if (w >= 700) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = _columnsForWidth(width);

    return GridView.builder(
      itemCount: files.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        return AudioTile(file: files[index]);
      },
    );
  }
}
