// lib/services/music_player_service.dart

import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

enum RepeatMode { off, one, all }
enum ShuffleMode { off, on }

class MusicPlayerService extends ChangeNotifier {
  // Singleton implementation
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  factory MusicPlayerService() => _instance;

  MusicPlayerService._internal() {
    _setupAudioSession();
    _setupListeners();
    _loadFavorites();
    _loadPlaylists();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  
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
  
  // Storage
  List<String> _favorites = [];
  Map<String, Playlist> _playlists = {};

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
      _handleTrackComplete();
    });
  }

  void _handleTrackComplete() {
    if (_repeatMode == RepeatMode.one) {
      _audioPlayer.play(UrlSource(_currentUrl!));
    } else if (_currentQueueIndex < _queue.length - 1) {
      skipNext();
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      _currentQueueIndex = 0;
      _playCurrentTrack();
    }
  }

  Future<void> loadPlaylist(String url) async {
    try {
      _queue = [url];
      _currentQueueIndex = 0;
      _originalQueue = [url];
      _currentUrl = url;
      await _audioPlayer.play(UrlSource(url));
      _isPlaying = true;
      notifyListeners();
      _saveFavorite(url);
    } catch (e) {
      debugPrint('Error loading playlist: $e');
      rethrow;
    }
  }

  Future<void> loadCustomPlaylist(Playlist playlist) async {
    try {
      _queue = List.from(playlist.tracks);
      _originalQueue = List.from(playlist.tracks);
      _currentQueueIndex = 0;
      if (_queue.isNotEmpty) {
        _currentUrl = _queue[0];
        await _audioPlayer.play(UrlSource(_currentUrl!));
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
    _queue.clear();
    _originalQueue.clear();
    _currentQueueIndex = -1;
    _currentUrl = null;
    _audioPlayer.stop();
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
      try {
        await _audioPlayer.play(UrlSource(_currentUrl!));
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
      if (_isPlaying) {
        await _audioPlayer.pause();
        _isPlaying = false;
      } else {
        if (_currentUrl != null) {
          await _audioPlayer.resume();
          _isPlaying = true;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling play: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      notifyListeners();
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      _volume = volume.clamp(0.0, 1.0);
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

  Future<void> updatePlaylist(String id, String name, List<String> tracks) async {
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

  Future<void> removeTrackFromPlaylist(String playlistId, String trackUrl) async {
    if (_playlists.containsKey(playlistId)) {
      _playlists[playlistId]!.removeTrack(trackUrl);
      await _savePlaylists();
      notifyListeners();
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = _playlists.values
          .map((p) => jsonEncode(p.toJson()))
          .toList();
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
    if (url.isEmpty || _favorites.contains(url)) return;
    
    _favorites.insert(0, url);
    if (_favorites.length > 20) {
      _favorites.removeLast();
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('music_favorites', _favorites);
    notifyListeners();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = prefs.getStringList('music_favorites') ?? [];
    notifyListeners();
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

  String getDisplayName(String url) {
    try {
      if (url.contains('spotify')) return '🎵 Spotify Playlist';
      if (url.contains('youtube')) return '▶️ YouTube Audio';
      if (url.contains('soundcloud')) return '☁️ SoundCloud';
      if (url.contains('apple')) return '🍎 Apple Music';
      if (url.contains('deezer')) return '🎧 Deezer';
      if (url.contains('tidal')) return '🌊 Tidal';
      if (url.contains('pandora')) return '📻 Pandora';
      return '🎵 Music Playlist';
    } catch (_) {
      return '🎵 Music Playlist';
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
        return '🔁';
      case RepeatMode.one:
        return '🔂';
      case RepeatMode.all:
        return '🔁';
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}