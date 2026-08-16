import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

enum NoiseType { off, white, pink, brown }

class NoisePlayer {
  // Dual players for seamless crossfading
  final AudioPlayer _playerA = AudioPlayer();
  final AudioPlayer _playerB = AudioPlayer();
  
  bool _usePlayerA = true;
  StreamSubscription? _subA;
  StreamSubscription? _subB;
  
  NoiseType _currentType = NoiseType.off;

  // Track duration minus crossfade duration (adjust if your clips are longer/shorter)
  // E.g., for a 30-second audio file, trigger next loop at ~29 seconds
  static const Duration _trackDuration = Duration(seconds: 30);
  static const Duration _crossfadeWindow = Duration(seconds: 1);

  Future<void> play(NoiseType type) async {
    if (type == NoiseType.off) {
      await stop();
      return;
    }

    if (_currentType == type) return;
    _currentType = type;

    await stop();

    final assetPath = _getAssetPath(type);

    // Set loop behavior to handle gapless handoff
    await _playerA.setReleaseMode(ReleaseMode.stop);
    await _playerB.setReleaseMode(ReleaseMode.stop);

    // Initial start on Player A
    _usePlayerA = true;
    await _playerA.play(AssetSource(assetPath), volume: 0.5);

    _listenAndScheduleNext(assetPath);
  }

  void _listenAndScheduleNext(String assetPath) {
    _cancelSubscriptions();

    // Monitor position of Player A
    _subA = _playerA.onPositionChanged.listen((position) {
      if (_usePlayerA && position >= (_trackDuration - _crossfadeWindow)) {
        _usePlayerA = false;
        _playerB.play(AssetSource(assetPath), volume: 0.5);
      }
    });

    // Monitor position of Player B
    _subB = _playerB.onPositionChanged.listen((position) {
      if (!_usePlayerA && position >= (_trackDuration - _crossfadeWindow)) {
        _usePlayerA = true;
        _playerA.play(AssetSource(assetPath), volume: 0.5);
      }
    });
  }

  String _getAssetPath(NoiseType type) {
    switch (type) {
      case NoiseType.white:
        return 'audio/white_noise.mp3';
      case NoiseType.pink:
        return 'audio/pink_noise.mp3';
      case NoiseType.brown:
        return 'audio/brown_noise.mp3';
      case NoiseType.off:
        return '';
    }
  }

  void _cancelSubscriptions() {
    _subA?.cancel();
    _subB?.cancel();
  }

  Future<void> stop() async {
    _currentType = NoiseType.off;
    _cancelSubscriptions();
    await _playerA.stop();
    await _playerB.stop();
  }

  Future<void> dispose() async {
    _cancelSubscriptions();
    await _playerA.dispose();
    await _playerB.dispose();
  }
}