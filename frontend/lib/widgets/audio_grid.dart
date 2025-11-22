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

  double _aspectForWidth(double screenWidth, int cols) {
    const double gridPadding = 4.0;
    const double spacing = 8.0;

    final double totalHorizontalPadding =
        gridPadding * 2 + spacing * (cols - 1);
    final double usableWidth = screenWidth - totalHorizontalPadding;
    final double tileWidth = usableWidth / cols;

    // target content height we design for
    const double minTileHeight = 145.0; // slightly taller to avoid overflow

    double ratio = tileWidth / minTileHeight; // width / height

    // keep a reasonable range, but prefer flatter tiles
    if (ratio < 1.3) ratio = 1.3;
    if (ratio > 2.4) ratio = 2.4;

    return ratio;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = _columnsForWidth(width);
    final aspect = _aspectForWidth(width, cols);

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: files.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: aspect,
      ),
      itemBuilder: (context, index) {
        return AudioTile(file: files[index]);
      },
    );
  }
}
