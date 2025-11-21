// lib/widgets/audio_tile.dart

import 'dart:html' as html show window;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';

import '../api_service.dart';

// brand palette (same as dashboard)
const Color kNavy = Color(0xFF003056);
const Color kNavySoft = Color(0xFF00213C);
const Color kAccent = Color(0xFFFF5C00);
const Color kDanger = Color(0xFF9A031E);
const Color kFieldBorder = Color(0xFF1E3C57);
const Color kOk = Color(0xFF1C5434);
const Color kRulesBeige = Color(0xFFF5E9DA);

class GlobalAudioController extends ChangeNotifier {
  static final GlobalAudioController _instance =
      GlobalAudioController._internal();

  factory GlobalAudioController() => _instance;

  GlobalAudioController._internal() {
    _initPlayer();
  }

  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? get currentUrl => _currentUrl;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;

  Future<void> _initPlayer() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);

      _player.onPlayerStateChanged.listen((PlayerState state) {
        final playingNow = state == PlayerState.playing;
        if (_isPlaying != playingNow) {
          _isPlaying = playingNow;
          notifyListeners();
        }
      });

      _player.onDurationChanged.listen((d) {
        if (d.inMilliseconds <= 0) return;
        _duration = d;
        notifyListeners();
      });

      _player.onPositionChanged.listen((p) {
        _position = p;
        notifyListeners();
      });

      _player.onPlayerComplete.listen((_) {
        _position = _duration;
        _isPlaying = false;
        notifyListeners();
      });
      // audioplayers ^6.0.0 no longer exposes onPlayerError,
      // so we just rely on try/catch around play/pause/seek.
    } catch (e) {
      debugPrint('[GlobalAudioController] init error: $e');
    }
  }

  bool isCurrent(String url) => _currentUrl == url;

  String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);

      if (kIsWeb) {
        // If backend returns a relative path, prepend the current origin.
        if (!uri.hasScheme) {
          final origin = html.window.location.origin;
          if (url.startsWith('/')) {
            return origin + url;
          }
          return '$origin/$url';
        }

        // Avoid mixed-content errors: upgrade http -> https on the same host
        // when the app itself runs on https.
        if (uri.scheme == 'http' &&
            html.window.location.protocol == 'https:' &&
            uri.host == html.window.location.host) {
          return uri.replace(scheme: 'https').toString();
        }
      }

      return url;
    } catch (e) {
      debugPrint('[GlobalAudioController] _normalizeUrl("$url") failed: $e');
      return url;
    }
  }

  Future<void> togglePlay(String url) async {
    final normalizedUrl = _normalizeUrl(url);

    // Same track: toggle pause / resume
    if (_currentUrl == normalizedUrl) {
      if (_isPlaying) {
        try {
          await _player.pause();
        } catch (e) {
          debugPrint('[GlobalAudioController] pause error: $e');
        }
        _isPlaying = false;
        notifyListeners();
        return;
      } else {
        try {
          await _player.resume();
        } catch (e) {
          debugPrint('[GlobalAudioController] resume error: $e');
        }
        return;
      }
    }

    // New track: stop previous and start the new one
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[GlobalAudioController] stop error: $e');
    }

    _currentUrl = normalizedUrl;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    try {
      await _player.play(
        UrlSource(normalizedUrl),
        mode: PlayerMode.mediaPlayer,
      );
    } catch (e) {
      debugPrint('[GlobalAudioController] play error for "$normalizedUrl": $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> seek(double ratio) async {
    if (_duration.inMilliseconds <= 0) return;
    final int targetMillis =
        (ratio.clamp(0.0, 1.0) * _duration.inMilliseconds).round();
    final target = Duration(milliseconds: targetMillis);
    try {
      await _player.seek(target);
    } catch (e) {
      debugPrint('[GlobalAudioController] seek error: $e');
    }
  }
}

class AudioTile extends StatefulWidget {
  final SoundFile file;

  const AudioTile({
    super.key,
    required this.file,
  });

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  final GlobalAudioController _controller = GlobalAudioController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String _formatTime(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = _controller.isCurrent(widget.file.url);
    final isPlaying = isCurrent && _controller.isPlaying;

    final Duration duration =
        isCurrent && _controller.duration.inMilliseconds > 0
            ? _controller.duration
            : Duration.zero;

    final Duration position =
        isCurrent && _controller.position <= duration
            ? _controller.position
            : Duration.zero;

    final double sliderValue;
    if (duration.inMilliseconds <= 0) {
      sliderValue = 0.0;
    } else {
      sliderValue = (position.inMilliseconds / duration.inMilliseconds)
          .clamp(0.0, 1.0);
    }

    final String posLabel = _formatTime(position);
    final String durLabel =
        duration.inMilliseconds > 0 ? _formatTime(duration) : '00:00';

    return Card(
      color: kNavySoft.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kFieldBorder, width: 1),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              widget.file.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),

            // Time labels row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  posLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                Text(
                  durLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Progress bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: kAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: kAccent,
                overlayColor: kAccent.withOpacity(0.2),
              ),
              child: Slider(
                value: sliderValue,
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  if (!isCurrent) return;
                  _controller.seek(value);
                },
              ),
            ),

            const SizedBox(height: 4),

            // Play / stop button
            SizedBox(
              height: 30,
              child: ElevatedButton.icon(
                onPressed: () {
                  _controller.togglePlay(widget.file.url);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPlaying ? kDanger : kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
                icon: Icon(
                  isPlaying ? Icons.stop : Icons.play_arrow,
                  size: 16,
                ),
                label: Text(
                  isPlaying ? 'Stop' : 'Play',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
