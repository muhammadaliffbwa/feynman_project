// lib/services/web_stream_player_web.dart

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// A browser-native radio player modelled on Radiolise's `RadMedia` component.
///
/// Radiolise does not route internet radio through Web Audio or set
/// `crossOrigin`. It assigns the stream URL directly to a media element and,
/// when the browser reports `MEDIA_ERR_SRC_NOT_SUPPORTED`, retries with a `/;`
/// suffix (the Icecast/Shoutcast convention for suppressing ICY metadata,
/// which otherwise breaks MP3 decoding in browsers). HLS URLs are handed to
/// hls.js, with `http:` upgraded to `https:` on secure pages.
///
/// This implementation keeps those behaviours, while exposing the small
/// stream-based API the rest of the app already uses.

@JS('Hls')
extension type _Hls._(JSObject _) implements JSObject {
  external factory _Hls();

  external void loadSource(String url);
  external void attachMedia(web.HTMLMediaElement mediaElement);
  external void on(String event, JSFunction listener);
  external void destroy();
}

@JS('Hls.isSupported')
external bool _hlsIsSupported();

@JS('Hls.Events.ERROR')
external String get _hlsErrorEvent;

class _RetryableMediaError implements Exception {
  const _RetryableMediaError(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'MediaError($code): $message';
}

class _PlaybackStarted {
  const _PlaybackStarted();
}

class _ConnectionTimedOut {
  const _ConnectionTimedOut();
}

class WebStreamPlayer {
  WebStreamPlayer() {
    _element = web.HTMLVideoElement()
      ..style.display = 'none'
      ..playsInline = true
      ..preload = 'auto';
    web.document.body?.appendChild(_element);

    _listen('loadedmetadata', (_) {
      final seconds = _element.duration;
      _durationController.add(
        (seconds.isFinite && seconds > 0)
            ? Duration(milliseconds: (seconds * 1000).round())
            : Duration.zero,
      );
    });
    _listen('timeupdate', (_) {
      final seconds = _element.currentTime;
      if (seconds.isFinite && seconds >= 0) {
        _positionController.add(
          Duration(milliseconds: (seconds * 1000).round()),
        );
      }
    });
    _listen('playing', (_) {
      _playingController.add(true);
      final attempt = _attempt;
      if (attempt != null && !attempt.isCompleted) {
        attempt.complete(const _PlaybackStarted());
      }
    });
    _listen('pause', (_) => _playingController.add(false));
    _listen('ended', (_) {
      _playingController.add(false);
      _completedController.add(null);
    });
    _listen('error', (_) => _handleMediaError());
  }

  late final web.HTMLVideoElement _element;
  final Map<String, JSFunction> _listeners = {};

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();

  Completer<Object>? _attempt;
  _Hls? _hls;
  bool _disposed = false;

  bool get isAvailable => true;

  Stream<Duration> get position => _positionController.stream;
  Stream<Duration> get duration => _durationController.stream;
  Stream<bool> get playingState => _playingController.stream;
  Stream<void> get completed => _completedController.stream;

  void _listen(String type, void Function(web.Event) handler) {
    final listener = handler.toJS;
    _listeners[type] = listener;
    _element.addEventListener(type, listener);
  }

  void _handleMediaError() {
    final error = _element.error;
    final code = error?.code ?? web.MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED;
    final message = (error?.message ?? '').trim();
    _playingController.add(false);

    final attempt = _attempt;
    if (attempt == null || attempt.isCompleted) return;

    if (code == web.MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED) {
      attempt.completeError(_RetryableMediaError(code, message));
    } else if (code == web.MediaError.MEDIA_ERR_NETWORK) {
      attempt.completeError(
        const _RetryableMediaError(
          web.MediaError.MEDIA_ERR_NETWORK,
          'network error',
        ),
      );
    } else {
      attempt.completeError(
        FormatException(
          'The browser could not decode this stream '
          '(media error $code): ${message.isEmpty ? 'unsupported format' : message}.',
        ),
      );
    }
  }

  /// Returns the URL variants Radiolise tries, in order.
  List<String> _candidateUrls(String url) {
    final secure = web.window.location.protocol == 'https:';
    final upgraded = _upgradeToHttps(url, secure);
    final candidates = <String>[upgraded];
    final withSemicolon = _appendIcySeparator(upgraded);
    if (withSemicolon != upgraded) candidates.add(withSemicolon);
    return candidates;
  }

  String _upgradeToHttps(String url, bool secure) {
    if (!secure) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('http')) return url;
    return uri.replace(scheme: 'https').toString();
  }

  String _appendIcySeparator(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url.endsWith('/;') ? url : '$url/;';
    }
    if (uri.path.endsWith('/;')) return url;
    final path = uri.path.endsWith('/') ? '${uri.path};' : '${uri.path}/;';
    return uri.replace(path: path).toString();
  }

  bool _isHls(String url) {
    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    return path.endsWith('.m3u8');
  }

  static Future<void>? _hlsScriptFuture;

  Future<void> _ensureHlsScript() {
    return _hlsScriptFuture ??= _loadHlsScript();
  }

  Future<void> _loadHlsScript() async {
    final completer = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src = 'https://cdn.jsdelivr.net/npm/hls.js@1.5.17/dist/hls.min.js'
      ..async = true;
    script.addEventListener(
      'load',
      ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS,
    );
    script.addEventListener(
      'error',
      ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            const FormatException('Could not load the HLS playback library.'),
          );
        }
      }).toJS,
    );
    web.document.head?.appendChild(script);
    await completer.future;
  }

  Future<void> _startHls(String url, Completer<Object> attempt) async {
    try {
      await _ensureHlsScript();
      if (!_hlsIsSupported()) {
        throw const FormatException('HLS is not supported by this browser.');
      }

      _detachHls();
      final hls = _Hls();
      _hls = hls;
      hls.on(
        _hlsErrorEvent,
        ((JSAny? _) {
          if (!attempt.isCompleted) {
            attempt.completeError(
              const _RetryableMediaError(0, 'HLS playback error'),
            );
          }
        }).toJS,
      );
      hls.loadSource(url);
      hls.attachMedia(_element);
    } catch (_) {
      // If hls.js cannot be loaded, fall back to the media element's native
      // HLS support (Safari) so the retry chain can still report a clear error.
      _detachHls();
      _element.src = url;
      _element.load();
    }
  }

  Future<void> _startCandidate(String url, Completer<Object> attempt) async {
    _detachHls();
    _element.pause();
    _element.removeAttribute('src');
    _element.load();

    if (_isHls(url)) {
      await _startHls(url, attempt);
    } else {
      // Crucially: no `crossOrigin` and no Web Audio node. Radiolise uses a
      // plain media element because ICY radio streams frequently fail when
      // fetched in CORS mode or routed through Web Audio.
      _element.src = url;
      _element.load();
    }

    late final Future<Object?> playResult;
    try {
      playResult = _element.play().toDart.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
    } catch (error) {
      throw _RetryableMediaError(0, error.toString());
    }

    final outcome = await Future.any<Object?>([
      attempt.future,
      playResult,
      Future<Object>.delayed(
        const Duration(seconds: 12),
        () => const _ConnectionTimedOut(),
      ),
    ]);

    if (outcome is _PlaybackStarted) return;

    if (outcome is _ConnectionTimedOut) {
      throw TimeoutException('No playback started within 12 seconds.');
    }

    if (outcome != null) {
      // `play()` rejected (e.g. NotAllowedError). Keep it as a retryable
      // failure so the alternate ICY URL is still attempted once.
      throw _RetryableMediaError(0, outcome.toString());
    }

    // `play()` resolved before the `playing` event fired. Give the element a
    // short grace period to actually start rendering audio.
    try {
      await attempt.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw TimeoutException('The stream did not start playing.');
    }
  }

  void _detachHls() {
    _hls?.destroy();
    _hls = null;
  }

  Future<void> play(String url) async {
    if (_disposed) return;
    await stop();

    Object? lastFailure;
    for (final candidate in _candidateUrls(url)) {
      final attempt = Completer<Object>();
      _attempt = attempt;
      try {
        await _startCandidate(candidate, attempt);
        return;
      } on FormatException {
        rethrow;
      } catch (error) {
        if (error is _RetryableMediaError || error is TimeoutException) {
          lastFailure = error;
          // Try the next URL variant (for example the `/;` ICY form).
          continue;
        }
        rethrow;
      } finally {
        if (identical(_attempt, attempt)) _attempt = null;
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }

    throw _friendlyFailure(lastFailure, url);
  }

  FormatException _friendlyFailure(Object? failure, String url) {
    if (failure is FormatException) return failure;
    final text = failure?.toString() ?? '';
    if (failure is TimeoutException || text.contains('TimeoutException')) {
      return const FormatException(
        'Timed out while connecting to that station. It may be offline or '
        'blocking browser playback. Try another station or a direct MP3 URL.',
      );
    }
    if (text.contains('NotAllowedError') || text.contains('permission')) {
      return const FormatException(
        'The browser blocked autoplay. Tap play again to allow audio.',
      );
    }
    return FormatException(
      'This browser could not play that stream'
      '${text.isEmpty ? '' : ' ($text)'}. '
      'Try the station\'s MP3 stream, a .pls playlist, or another radio.',
    );
  }

  Future<void> pause() async {
    _element.pause();
    _playingController.add(false);
  }

  Future<void> resume() async {
    if (_element.src.isEmpty) return;
    try {
      await _element.play().toDart;
      _playingController.add(true);
    } catch (error) {
      _playingController.add(false);
      throw FormatException('Could not resume this stream: $error');
    }
  }

  Future<void> stop() async {
    _attempt = null;
    _detachHls();
    _element.pause();
    _element.removeAttribute('src');
    _element.load();

    _playingController.add(false);
    _positionController.add(Duration.zero);
    _durationController.add(Duration.zero);
  }

  void setVolume(double volume) {
    _element.volume = volume.clamp(0.0, 1.0);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _listeners.entries) {
      _element.removeEventListener(entry.key, entry.value);
    }
    _listeners.clear();
    _detachHls();
    _element.pause();
    _element.removeAttribute('src');
    _element.load();
    _element.remove();

    _positionController.close();
    _durationController.close();
    _playingController.close();
    _completedController.close();
  }
}
