// lib/services/web_stream_player.dart

// A tiny browser-native audio wrapper used as a fallback for radio streams
// that audioplayers cannot load on web (it forces CORS + Web Audio mode).
export 'web_stream_player_stub.dart'
    if (dart.library.js_interop) 'web_stream_player_web.dart';
