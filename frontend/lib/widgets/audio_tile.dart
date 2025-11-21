// lib/widgets/audio_tile.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../api_service.dart';

// brand palette
const Color kNavy = Color(0xFF003056);
const Color kNavySoft = Color(0xFF00213C);
const Color kAccent = Color(0xFFFF5C00);
const Color kDanger = Color(0xFF9A031E);
const Color kFieldBorder = Color(0xFF1E3C57);
const Color kOk = Color(0xFF1C5434);

/// global controller so only one soundscape plays at a time
class GlobalAudioController extends ChangeNotifier {
  static final GlobalAudioController _instance =
      GlobalAudioController._internal();
  factory GlobalAudioController() => _instance;

  GlobalAudioController._internal() {
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.stop);

    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      if (state == PlayerState.stopped) {
        _position = Duration.zero;
      }
      notifyListeners();
    });

    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });

    _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
    });
  }

  late final AudioPlayer _player;

  SoundFile? _currentFile;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  SoundFile? get currentFile => _currentFile;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;

  bool isCurrent(SoundFile file) => _currentFile?.url == file.url;

  Future<void> toggle(SoundFile file) async {
    // same file: toggle pause/resume
    if (isCurrent(file)) {
      if (_isPlaying) {
        await _player.pause();
      } else {
        // if we never really started (duration still zero), start fresh
        if (_duration == Duration.zero && _position == Duration.zero) {
          await _player.play(
            UrlSource(file.url),
            mode: PlayerMode.mediaPlayer,
          );
        } else {
          await _player.resume();
        }
      }
      return;
    }

    // new file: stop current and start this one from the beginning
    try {
      await _player.stop();
    } catch (_) {}

    _currentFile = file;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    await _player.play(
      UrlSource(file.url),
      mode: PlayerMode.mediaPlayer,
    );
  }

  Future<void> seek(Duration d) async {
    try {
      await _player.seek(d);
    } catch (_) {}
  }
}

class AudioTile extends StatelessWidget {
  final SoundFile file;
  const AudioTile({super.key, required this.file});

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
    final controller = GlobalAudioController();
    final title = file.name;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final bool isCurrent = controller.isCurrent(file);
        final bool isPlaying = isCurrent && controller.isPlaying;

        final Duration pos = isCurrent ? controller.position : Duration.zero;
        final Duration dur = isCurrent ? controller.duration : Duration.zero;

        final int maxMs = dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds;
        final double value =
            pos.inMilliseconds.clamp(0, maxMs).toDouble();

        return Card(
          margin: EdgeInsets.zero,
          color: kNavy.withOpacity(0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Column(
              // fill the full tile height so the button can sit at the bottom
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // top content: title + slider + times
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2),

                      // progress bar
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.0,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                        ),
                        child: Slider(
                          value: value,
                          min: 0,
                          max: maxMs.toDouble(),
                          activeColor: kAccent,
                          inactiveColor: Colors.white24,
                          onChanged: isCurrent
                              ? (v) => controller.seek(
                                    Duration(milliseconds: v.round()),
                                  )
                              : null,
                        ),
                      ),

                      const SizedBox(height: 2),

                      // time labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(pos),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _fmt(dur),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // tiny gap between content and button
                const SizedBox(height: 3),

                // play / pause button, now anchored to the bottom of the tile
                SizedBox(
                  height: 26,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPlaying ? kDanger : kOk,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        vertical: 1,
                        horizontal: 6,
                      ),
                    ),
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      isPlaying ? "Pause" : "Play",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () => controller.toggle(file),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
