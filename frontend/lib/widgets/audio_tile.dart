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

/// Global controller so only one soundscape plays at a time.
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
          debugPrint(
              '[GlobalAudioController] onPlayerStateChanged => playing=$playingNow');
          notifyListeners();
        }
      });

      _player.onDurationChanged.listen((d) {
        if (d.inMilliseconds <= 0) return;
        _duration = d;
        // debugPrint('[GlobalAudioController] duration=$d');
        notifyListeners();
      });

      _player.onPositionChanged.listen((p) {
        _position = p;
        // debugPrint('[GlobalAudioController] position=$p');
        notifyListeners();
      });

      _player.onPlayerComplete.listen((_) {
        _position = _duration;
        _isPlaying = false;
        debugPrint('[GlobalAudioController] onPlayerComplete');
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[GlobalAudioController] init error: $e');
    }
  }

  /// Compare with normalized URL so UI stays in sync even when we rewrite URLs.
  bool isCurrent(String url) => _currentUrl == _normalizeUrl(url);

  String _normalizeUrl(String url) {
    try {
      final uri = Uri.parse(url);

      if (kIsWeb) {
        final loc = html.window.location;

        // If backend ever sends relative paths, make them absolute.
        if (!uri.hasScheme) {
          final origin = loc.origin; // e.g. https://ermine.at
          final path = url.startsWith('/') ? url : '/$url';
          final out = origin + path;
          // debugPrint('[GlobalAudioController] normalized relative => $out');
          return out;
        }

        // Local dev convenience: if the app is running over plain http (flutter run -d chrome)
        // and the sound URL is https to soundscapes.ermine.at:8083, downgrade to http so it
        // can actually connect (that port normally speaks plain http).
        if (loc.protocol == 'http:' &&
            uri.scheme == 'https' &&
            uri.host == 'soundscapes.ermine.at' &&
            uri.port == 8083) {
          final out = uri.replace(scheme: 'http').toString();
          debugPrint(
              '[GlobalAudioController] downgrade https->http for local dev: $out');
          return out;
        }

        // If the app itself is https and the backend asset is same-host http, avoid mixed content
        // by upgrading http -> https on that host.
        if (loc.protocol == 'https:' &&
            uri.scheme == 'http' &&
            uri.host == loc.host) {
          final out = uri.replace(scheme: 'https').toString();
          debugPrint(
              '[GlobalAudioController] upgrade http->https for same host: $out');
          return out;
        }
      }

      return url;
    } catch (e) {
      debugPrint('[GlobalAudioController] _normalizeUrl("$url") failed: $e');
      return url;
    }
  }

  /// Toggle play/pause for a given URL.
  ///
  /// Behaviour:
  /// - If this tile is the current track and playing -> pause.
  /// - If this tile is the current track and paused -> resume from last position.
  /// - If this is a different track -> stop previous and play this from start.
  Future<void> togglePlay(String url) async {
    final normalizedUrl = _normalizeUrl(url);
    final sameTrack = _currentUrl == normalizedUrl;

    debugPrint(
        '[GlobalAudioController] togglePlay: url="$url" normalized="$normalizedUrl" sameTrack=$sameTrack '
        'isPlaying=$_isPlaying position=$_position duration=$_duration');

    // CASE 1: same track & currently playing -> PAUSE
    if (sameTrack && _isPlaying) {
      try {
        debugPrint(
            '[GlobalAudioController] pause current track "$normalizedUrl"');
        await _player.pause();
      } catch (e) {
        debugPrint('[GlobalAudioController] pause error: $e');
      }
      _isPlaying = false;
      notifyListeners();
      return;
    }

    // Determine resume position if we are resuming the same track.
    Duration resumeFrom = Duration.zero;
    if (sameTrack && !_isPlaying && _duration.inMilliseconds > 0) {
      if (_position > Duration.zero && _position < _duration) {
        resumeFrom = _position;
      }
    }

    // If we are switching tracks, ensure the previous is stopped first.
    if (!sameTrack && _currentUrl != null) {
      try {
        debugPrint(
            '[GlobalAudioController] stop previous track "$_currentUrl" before playing new one');
        await _player.stop();
      } catch (e) {
        debugPrint('[GlobalAudioController] stop error: $e');
      }
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();
    }

    _currentUrl = normalizedUrl;

    try {
      if (resumeFrom > Duration.zero) {
        debugPrint(
            '[GlobalAudioController] resume track via play(position) from $resumeFrom');
        await _player.play(
          UrlSource(normalizedUrl),
          mode: PlayerMode.mediaPlayer,
          position: resumeFrom,
        );
      } else {
        debugPrint(
            '[GlobalAudioController] play track from start "$normalizedUrl"');
        await _player.play(
          UrlSource(normalizedUrl),
          mode: PlayerMode.mediaPlayer,
        );
      }
      // _isPlaying will be updated by onPlayerStateChanged.
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
      debugPrint('[GlobalAudioController] seek to $target');
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
    final bool isCurrent = _controller.isCurrent(widget.file.url);
    final bool isPlaying = isCurrent && _controller.isPlaying;

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

            // Play / stop button (thin, rounded, kOk vs kDanger)
            SizedBox(
              height: 24,
              child: ElevatedButton.icon(
                onPressed: () {
                  _controller.togglePlay(widget.file.url);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPlaying ? kDanger : kOk,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 1,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  isPlaying ? Icons.stop : Icons.play_arrow,
                  size: 14,
                ),
                label: Text(
                  isPlaying ? 'Stop' : 'Play',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
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
