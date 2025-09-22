import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../api_service.dart';

class _AudioCoordinator {
  static final _AudioCoordinator _instance = _AudioCoordinator._internal();
  factory _AudioCoordinator() => _instance;
  _AudioCoordinator._internal();

  AudioPlayer? _current;

  Future<void> setCurrent(AudioPlayer p) async {
    if (_current != null && _current != p) {
      await _current!.stop();
    }
    _current = p;
  }
}

class AudioTile extends StatefulWidget {
  final SoundFile file;
  const AudioTile({super.key, required this.file});

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((s) {
      setState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((p) {
      setState(() => _pos = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    await _AudioCoordinator().setCurrent(_player);
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.file.url));
    }
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    if (hh > 0) {
      return "${hh.toString().padLeft(2, '0')}:$mm:$ss";
    }
    return "$mm:$ss";
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.file.name;

    return Card(
      color: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _pos.inMilliseconds.clamp(0, _dur.inMilliseconds).toDouble(),
              min: 0,
              max: (_dur.inMilliseconds == 0 ? 1 : _dur.inMilliseconds).toDouble(),
              onChanged: (v) async {
                final to = Duration(milliseconds: v.round());
                await _player.seek(to);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(_pos), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                Text(_fmt(_dur), style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? "Pause" : "Play"),
                onPressed: _toggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
