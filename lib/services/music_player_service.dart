// lib/services/music_player_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import 'playlist_fetcher.dart';
import 'web_stream_player.dart';

enum RepeatMode { off, one, all }

enum ShuffleMode { off, on }

class MusicPlayerService extends ChangeNotifier {
  // Singleton implementation
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  factory MusicPlayerService() => _instance;

  MusicPlayerService._internal() {
    // We catch and translate playback failures into friendly FormatExceptions;
    // audioplayers' raw console logging is noisy for unsupported web streams.
    AudioLogger.logLevel = AudioLogLevel.none;
    _setupAudioSession();
    _setupListeners();
    _loadFavorites();
    _loadPlaylists();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final WebStreamPlayer _webStreamPlayer = WebStreamPlayer();
  bool _usingWebStream = false;

  // Current playback
  String? _currentUrl;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;

  // Queue & Playlist management
  List<String> _queue = [];
  int _currentQueueIndex = -1;
  RepeatMode _repeatMode = RepeatMode.off;
  ShuffleMode _shuffleMode = ShuffleMode.off;
  List<String> _originalQueue = [];

  // Storage & session-scoped metadata (lazy getters keep Hot Reload safe)
  List<String> _favorites = [];
  Map<String, Playlist> _playlists = {};
  Map<String, Source>? _localSourcesMap;
  Map<String, String>? _localTitlesMap;
  Map<String, String>? _streamTitlesMap;

  Map<String, Source> get _localSources => _localSourcesMap ??= {};
  Map<String, String> get _localTitles => _localTitlesMap ??= {};
  Map<String, String> get _streamTitles => _streamTitlesMap ??= {};

  // Getters
  String? get currentUrl => _currentUrl;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  double get volume => _volume;
  List<String> get favorites => List.unmodifiable(_favorites);
  List<String> get queue => List.unmodifiable(_queue);
  int get currentQueueIndex => _currentQueueIndex;
  RepeatMode get repeatMode => _repeatMode;
  ShuffleMode get shuffleMode => _shuffleMode;
  Map<String, Playlist> get playlists => Map.unmodifiable(_playlists);

  bool get isShuffleOn => _shuffleMode == ShuffleMode.on;
  int get queueLength => _queue.length;
  bool get isLiveStream => _currentUrl != null && _duration == Duration.zero;

  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.audibilityEnforced,
            usage: AndroidAudioUsage.media,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );
      debugPrint('Audio session configured for background playback');
    } catch (e) {
      debugPrint('Error configuring audio session: $e');
    }
  }

  void _setupListeners() {
    _audioPlayer.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!_usingWebStream) _handleTrackComplete();
    });

    // Browser-native fallback used only when audioplayers cannot load a web
    // radio stream. Events are forwarded to the same shared player state.
    _webStreamPlayer.position.listen((position) {
      if (!_usingWebStream) return;
      _position = position;
      notifyListeners();
    });
    _webStreamPlayer.duration.listen((duration) {
      if (!_usingWebStream) return;
      _duration = duration;
      notifyListeners();
    });
    _webStreamPlayer.playingState.listen((playing) {
      if (!_usingWebStream) return;
      _isPlaying = playing;
      notifyListeners();
    });
    _webStreamPlayer.completed.listen((_) {
      if (_usingWebStream) _handleTrackComplete();
    });
  }

  // ==================== Local Device Audio ====================

  String _stripExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) return filename;
    return filename.substring(0, dotIndex);
  }

  String? _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.flac')) return 'audio/flac';
    return null;
  }

  String? _guessStreamMimeType(String url) {
    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    if (path.endsWith('.mp3') ||
        path.endsWith('-mp3') ||
        path.endsWith('_mp3') ||
        path.endsWith('/mp3')) {
      return 'audio/mpeg';
    }
    if (path.endsWith('.aac') ||
        path.endsWith('-aac') ||
        path.endsWith('_aac') ||
        path.endsWith('/aac')) {
      return 'audio/aac';
    }
    if (path.endsWith('.ogg') ||
        path.endsWith('.oga') ||
        path.endsWith('-ogg') ||
        path.endsWith('_ogg') ||
        path.endsWith('/ogg')) {
      return 'audio/ogg';
    }
    if (path.endsWith('.opus')) return 'audio/opus';
    if (path.endsWith('.m4a') || path.endsWith('.mp4')) return 'audio/mp4';
    if (path.endsWith('.wav')) return 'audio/wav';
    if (path.endsWith('.flac')) return 'audio/flac';
    return null;
  }

  bool _isLocalUri(String url) => url.startsWith('local://');

  Future<String?> registerLocalFile(
    PlatformFile file, {
    int? sizeBytes,
  }) async {
    final size = sizeBytes ?? file.lengthSync() ?? await file.length() ?? 0;
    final id =
        'local://${DateTime.now().microsecondsSinceEpoch}_${size}_${Uri.encodeComponent(file.name)}';
    final cleanName = _stripExtension(file.name);
    final mimeType = _guessMimeType(file.name);

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      _localSources[id] = BytesSource(bytes, mimeType: mimeType);
      _localTitles[id] = cleanName;
      return id;
    }

    final path = file.path;
    if (path != null && path.isNotEmpty) {
      _localSources[id] = DeviceFileSource(path, mimeType: mimeType);
      _localTitles[id] = cleanName;
      return id;
    }

    final uri = file.uri.toString();
    if (uri.isEmpty || uri == 'file://') return null;
    _localSources[id] = UrlSource(uri, mimeType: mimeType);
    _localTitles[id] = cleanName;
    return id;
  }

  void unregisterLocalFile(String uri) {
    _localSources.remove(uri);
    _localTitles.remove(uri);
  }

  Source _resolveSource(String url) {
    return _localSources[url] ??
        UrlSource(url, mimeType: _guessStreamMimeType(url));
  }

  // ==================== Internet Radio & .m3u / .pls Parsing ====================

  bool _isPlaylistFileUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.m3u') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.pls');
  }

  bool _isUnsupportedWebPageUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('open.spotify.com') ||
        host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('music.apple.com');
  }

  String _resolveStreamTarget(Uri basePlaylistUri, String rawTarget) {
    var resolved = basePlaylistUri.resolve(rawTarget);
    if (kIsWeb &&
        resolved.isScheme('http') &&
        (basePlaylistUri.isScheme('https') || Uri.base.scheme == 'https')) {
      resolved = resolved.replace(scheme: 'https');
    }
    return resolved.toString();
  }

  Future<List<String>> _parsePlaylistFromUrl(String playlistUrl) async {
    final uri = Uri.parse(playlistUrl);
    final rawText = await fetchUrlText(uri);

    final lines = const LineSplitter().convert(rawText);
    final tracks = <String>[];

    // Check for INI-style .pls format (File1=..., Title1=...)
    final Map<int, String> plsFiles = {};
    final Map<int, String> plsTitles = {};

    for (final rawLine in lines) {
      final line = rawLine.trim();
      final fileMatch =
          RegExp(r'^File(\d+)=(.+)$', caseSensitive: false).firstMatch(line);
      if (fileMatch != null) {
        final idx = int.parse(fileMatch.group(1)!);
        final rawTarget = fileMatch.group(2)!.trim();
        plsFiles[idx] = _resolveStreamTarget(uri, rawTarget);
        continue;
      }

      final titleMatch =
          RegExp(r'^Title(\d+)=(.+)$', caseSensitive: false).firstMatch(line);
      if (titleMatch != null) {
        final idx = int.parse(titleMatch.group(1)!);
        plsTitles[idx] = titleMatch.group(2)!.trim();
      }
    }

    if (plsFiles.isNotEmpty) {
      final sortedKeys = plsFiles.keys.toList()..sort();
      for (final idx in sortedKeys) {
        final trackUrl = plsFiles[idx]!;
        tracks.add(trackUrl);
        final title = plsTitles[idx];
        if (title != null && title.isNotEmpty) {
          _streamTitles[trackUrl] = title;
        }
      }
      return tracks;
    }

    // Parse standard .m3u / .m3u8 format (#EXTINF:-1,Station Title)
    String? pendingTitle;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final commaIdx = line.indexOf(',');
        if (commaIdx != -1 && commaIdx + 1 < line.length) {
          final parsedTitle = line.substring(commaIdx + 1).trim();
          if (parsedTitle.isNotEmpty) {
            pendingTitle = parsedTitle;
          }
        }
        continue;
      }

      if (line.startsWith('#')) continue;

      final resolvedUrl = _resolveStreamTarget(uri, line);
      tracks.add(resolvedUrl);
      if (pendingTitle != null) {
        _streamTitles[resolvedUrl] = pendingTitle;
        pendingTitle = null;
      }
    }

    return tracks;
  }

  // ==================== Playback & Queue ====================

  void _handleTrackComplete() {
    final url = _currentUrl;
    if (url == null) return;

    if (_repeatMode == RepeatMode.one) {
      _playUrl(url);
    } else if (_currentQueueIndex < _queue.length - 1) {
      skipNext();
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      _currentQueueIndex = 0;
      _playCurrentTrack();
    }
  }

  void _resetPlaybackState() {
    if (_usingWebStream) {
      unawaited(_webStreamPlayer.stop());
      _usingWebStream = false;
    }
    _queue.clear();
    _originalQueue.clear();
    _currentQueueIndex = -1;
    _currentUrl = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  bool _isWebMediaError(Object error) {
    if (!kIsWeb) return false;
    final message = error.toString();
    return message.contains('WebAudioError') ||
        message.contains('MEDIA_ELEMENT_ERROR') ||
        (message.contains('Format error') && message.contains('Code: 4'));
  }

  Never _throwPlaybackError(Object error, String failedUrl) {
    final message = error.toString();
    final isAacStream = _guessStreamMimeType(failedUrl) == 'audio/aac';
    if (kIsWeb &&
        isAacStream &&
        (message.contains('MEDIA_ELEMENT_ERROR') ||
            message.contains('Format error'))) {
      throw const FormatException(
        'Your browser cannot decode raw AAC streams. Use the station\'s MP3 stream or .pls MP3 playlist instead.',
      );
    }
    if (_isWebMediaError(error)) {
      throw const FormatException(
        'This browser could not play that stream. Try another station, a '
        'direct .mp3 URL, or open the stream in a browser tab to confirm it '
        'works there.',
      );
    }
    throw error;
  }

  /// Starts [url].
  ///
  /// On web, remote streams go straight to [WebStreamPlayer]. This follows
  /// Radiolise's approach: a plain browser media element with no CORS mode and
  /// no Web Audio node. Sending these URLs through `audioplayers` first is
  /// unreliable because its web `play()` resolves before the media is ready,
  /// so the old reactive fallback rarely ever ran.
  Future<void> _playUrl(String url) async {
    if (kIsWeb && !_isLocalUri(url)) {
      await _webStreamPlayer.play(url);
      _usingWebStream = true;
      return;
    }

    await _audioPlayer.play(_resolveSource(url));
    _usingWebStream = false;
  }

  Future<void> loadPlaylist(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    try {
      if (!_isLocalUri(trimmed)) {
        final parsedUri = Uri.tryParse(trimmed);
        if (parsedUri == null ||
            (!parsedUri.isScheme('http') && !parsedUri.isScheme('https'))) {
          throw const FormatException(
            'Enter a valid http:// or https:// audio stream or .m3u/.pls URL.',
          );
        }

        if (_isUnsupportedWebPageUrl(trimmed)) {
          throw const FormatException(
            'Web player links (Spotify/YouTube) cannot be streamed directly. Use a direct audio URL (.mp3/.ogg/.aac) or .m3u/.pls radio link.',
          );
        }
      }

      _duration = Duration.zero;
      _position = Duration.zero;

      if (!_isLocalUri(trimmed) && _isPlaylistFileUrl(trimmed)) {
        final extractedTracks = await _parsePlaylistFromUrl(trimmed);
        if (extractedTracks.isEmpty) {
          throw const FormatException(
            'No playable stream URLs were found inside that playlist file.',
          );
        }

        _queue = List.from(extractedTracks);
        _originalQueue = List.from(extractedTracks);
        _currentQueueIndex = 0;

        // Try entries sequentially in case the first .pls/.m3u entry is an offline mirror
        Object? lastError;
        String? lastFailedUrl;
        bool started = false;
        for (int i = 0; i < _queue.length; i++) {
          final candidateUrl = _queue[i];
          try {
            _currentQueueIndex = i;
            _currentUrl = candidateUrl;
            await _playUrl(candidateUrl);
            _isPlaying = true;
            started = true;
            break;
          } catch (e) {
            lastError = e;
            lastFailedUrl = candidateUrl;
          }
        }

        if (!started) {
          _resetPlaybackState();
          if (lastError != null && lastFailedUrl != null) {
            _throwPlaybackError(lastError, lastFailedUrl);
          }
          throw const FormatException(
            'Unable to connect to any stream in playlist.',
          );
        }

        notifyListeners();
        _saveFavorite(trimmed);
        return;
      }

      _queue = [trimmed];
      _currentQueueIndex = 0;
      _originalQueue = [trimmed];
      _currentUrl = trimmed;
      try {
        await _playUrl(trimmed);
      } catch (e) {
        _resetPlaybackState();
        _throwPlaybackError(e, trimmed);
      }
      _isPlaying = true;
      notifyListeners();
      if (!_isLocalUri(trimmed)) _saveFavorite(trimmed);
    } catch (e) {
      debugPrint(
        'Error loading playlist: ${e is FormatException ? e.message : e.runtimeType}',
      );
      rethrow;
    }
  }

  Future<void> loadCustomPlaylist(Playlist playlist) async {
    try {
      _queue = List.from(playlist.tracks);
      _originalQueue = List.from(playlist.tracks);
      _currentQueueIndex = 0;
      _duration = Duration.zero;
      _position = Duration.zero;
      if (_queue.isNotEmpty) {
        _currentUrl = _queue[0];
        await _playUrl(_currentUrl!);
        _isPlaying = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading custom playlist: $e');
      rethrow;
    }
  }

  void addToQueue(List<String> tracks) {
    _queue.addAll(tracks);
    if (_shuffleMode == ShuffleMode.on) {
      _originalQueue = List.from(_queue);
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (_currentQueueIndex == index) {
        if (_queue.isNotEmpty) {
          _currentQueueIndex = _currentQueueIndex.clamp(0, _queue.length - 1);
          _playCurrentTrack();
        }
      } else if (_currentQueueIndex > index) {
        _currentQueueIndex--;
      }
      notifyListeners();
    }
  }

  void clearQueue() {
    if (_usingWebStream) {
      unawaited(_webStreamPlayer.stop());
      _usingWebStream = false;
    }
    _queue.clear();
    _originalQueue.clear();
    _currentQueueIndex = -1;
    _currentUrl = null;
    unawaited(_audioPlayer.stop());
    _isPlaying = false;
    notifyListeners();
  }

  void skipNext() {
    if (_currentQueueIndex < _queue.length - 1) {
      _currentQueueIndex++;
      _playCurrentTrack();
    }
  }

  void skipPrevious() {
    if (_currentQueueIndex > 0) {
      _currentQueueIndex--;
      _playCurrentTrack();
    }
  }

  void playTrackAt(int index) {
    if (index >= 0 && index < _queue.length) {
      _currentQueueIndex = index;
      _playCurrentTrack();
    }
  }

  Future<void> _playCurrentTrack() async {
    if (_currentQueueIndex >= 0 && _currentQueueIndex < _queue.length) {
      _currentUrl = _queue[_currentQueueIndex];
      _duration = Duration.zero;
      _position = Duration.zero;
      try {
        await _playUrl(_currentUrl!);
        _isPlaying = true;
      } catch (e) {
        debugPrint('Error playing track: $e');
      }
      notifyListeners();
    }
  }

  void toggleShuffle() {
    if (_shuffleMode == ShuffleMode.off) {
      _shuffleMode = ShuffleMode.on;
      _originalQueue = List.from(_queue);
      _queue.shuffle();
    } else {
      _shuffleMode = ShuffleMode.off;
      _queue = _originalQueue;
      _originalQueue = [];
    }
    notifyListeners();
  }

  void cycleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.off;
        break;
    }
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    try {
      if (_usingWebStream) {
        if (_isPlaying) {
          await _webStreamPlayer.pause();
          _isPlaying = false;
        } else {
          await _webStreamPlayer.resume();
          _isPlaying = true;
        }
      } else if (_isPlaying) {
        await _audioPlayer.pause();
        _isPlaying = false;
      } else if (_currentUrl != null) {
        if (_audioPlayer.state == PlayerState.paused) {
          await _audioPlayer.resume();
        } else {
          await _playUrl(_currentUrl!);
        }
        _isPlaying = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling play: $e');
    }
  }

  Future<void> stop() async {
    try {
      if (_usingWebStream) {
        await _webStreamPlayer.stop();
        _usingWebStream = false;
      }
      await _audioPlayer.stop();
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _currentUrl = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      // Live radio has no seekable timeline; the browser fallback ignores it.
      if (!_usingWebStream) {
        await _audioPlayer.seek(position);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
      _webStreamPlayer.setVolume(_volume);
      await _audioPlayer.setVolume(_volume);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  // ==================== Playlist Management ====================

  Future<void> createPlaylist(String name, List<String> tracks) async {
    final playlist = Playlist(name: name, tracks: tracks);
    _playlists[playlist.id] = playlist;
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> updatePlaylist(
      String id, String name, List<String> tracks) async {
    if (_playlists.containsKey(id)) {
      _playlists[id] = _playlists[id]!.copyWith(name: name, tracks: tracks);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.remove(id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackUrl) async {
    if (_playlists.containsKey(playlistId)) {
      _playlists[playlistId]!.addTrack(trackUrl);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> removeTrackFromPlaylist(
      String playlistId, String trackUrl) async {
    if (_playlists.containsKey(playlistId)) {
      _playlists[playlistId]!.removeTrack(trackUrl);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson =
          _playlists.values.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList('music_playlists', playlistsJson);
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = prefs.getStringList('music_playlists') ?? [];
      _playlists = {};
      for (final json in playlistsJson) {
        final playlist = Playlist.fromJson(jsonDecode(json));
        _playlists[playlist.id] = playlist;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading playlists: $e');
    }
  }

  // ==================== Favorites Management ====================

  Future<void> _saveFavorite(String url) async {
    if (url.isEmpty ||
        _isLocalUri(url) ||
        _favorites.contains(url)) {
      return;
    }

    _favorites.insert(0, url);
    if (_favorites.length > 20) {
      _favorites.removeLast();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('music_favorites', _favorites);
    notifyListeners();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _favorites = (prefs.getStringList('music_favorites') ?? [])
          .where((url) => !_isLocalUri(url))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> removeFavorite(String url) async {
    _favorites.remove(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('music_favorites', _favorites);
    notifyListeners();
  }

  Future<void> addFavorite(String url) async {
    await _saveFavorite(url);
  }

  bool isFavorite(String url) => _favorites.contains(url);

  // ==================== Utility Methods ====================

  String getDisplayName(String url, {String? fallback}) {
    try {
      final localTitle = _localTitles[url];
      if (localTitle != null && localTitle.isNotEmpty) {
        return '🎵 $localTitle';
      }

      final streamTitle = _streamTitles[url];
      if (streamTitle != null && streamTitle.isNotEmpty) {
        return '📻 $streamTitle';
      }

      if (url.contains('spotify')) return '🎵 Spotify Playlist';
      if (url.contains('youtube')) return '▶️ YouTube Audio';
      if (url.contains('soundcloud')) return '☁️ SoundCloud';
      if (url.contains('apple')) return '🍎 Apple Music';
      if (url.contains('deezer')) return '🎧 Deezer';
      if (url.contains('tidal')) return '🌊 Tidal';
      if (url.contains('pandora')) return '📻 Pandora';

      final uri = Uri.tryParse(url);
      final fileName = (uri?.pathSegments.isNotEmpty ?? false)
          ? uri!.pathSegments.last
          : '';
      if (fileName.isNotEmpty) {
        final decoded = Uri.decodeComponent(fileName);
        final isPlaylist = RegExp(
          r'\.(m3u|m3u8|pls)$',
          caseSensitive: false,
        ).hasMatch(decoded);
        final name = decoded
            .replaceAll(
              RegExp(
                r'\.(mp3|ogg|wav|m4a|aac|flac|m3u|m3u8|pls)$',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(RegExp(r'[_\\-]+'), ' ');
        if (name.trim().isNotEmpty) {
          return isPlaylist ? '📻 ${name.trim()}' : '🎵 ${name.trim()}';
        }
      }
      if (fallback != null && fallback.trim().isNotEmpty) return fallback;
      return '🎵 Music Playlist';
    } catch (_) {
      return fallback ?? '🎵 Music Playlist';
    }
  }

  String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String getRepeatModeIcon() {
    switch (_repeatMode) {
      case RepeatMode.off:
        return '🚫';
      case RepeatMode.one:
        return '🔂';
      case RepeatMode.all:
        return '🔁';
    }
  }

  @override
  void dispose() {
    _webStreamPlayer.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}