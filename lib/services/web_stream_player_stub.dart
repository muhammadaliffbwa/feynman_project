// lib/services/web_stream_player_stub.dart

import 'dart:async';

/// No-op fallback for native platforms. Radio streams there keep using
/// `audioplayers`, so this class is never started outside the web.
class WebStreamPlayer {
  bool get isAvailable => false;

  Stream<Duration> get position => Stream<Duration>.empty();
  Stream<Duration> get duration => Stream<Duration>.empty();
  Stream<bool> get playingState => Stream<bool>.empty();
  Stream<void> get completed => Stream<void>.empty();

  Future<void> play(String url) async {
    throw UnsupportedError(
      'The native HTML audio fallback is only available on web.',
    );
  }

  Future<void> pause() async {}

  Future<void> resume() async {}

  Future<void> stop() async {}

  void setVolume(double volume) {}

  void dispose() {}
}
