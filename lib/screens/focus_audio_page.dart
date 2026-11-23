// lib/screens/focus_audio_page.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/music_player_service.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class _LocalAudioTrack {
  final String id;
  final String title;
  final String sourceUri;
  final String sizeLabel;

  const _LocalAudioTrack({
    required this.id,
    required this.title,
    required this.sourceUri,
    required this.sizeLabel,
  });
}

class FocusAudioPage extends StatefulWidget {
  const FocusAudioPage({super.key});

  @override
  State<FocusAudioPage> createState() => _FocusAudioPageState();
}

class _FocusAudioPageState extends State<FocusAudioPage> {
  static const Color _accentColor = Color(0xFF6C5CE7);

  final MusicPlayerService _audioService = MusicPlayerService();
  final TextEditingController _urlController = TextEditingController();
  final List<_LocalAudioTrack> _localTracks = [];
  bool _isPickingFiles = false;
  bool _isLoadingStream = false;

  // Reliable CORS-enabled test audio streams
  static const List<Map<String, String>> _presets = [
    {
      'title': 'Lofi Study Stream',
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/9/9c/Study_And_Relax_by_Kevin_MacLeod.ogg?utm_source=commons.wikimedia.org&utm_campaign=index&utm_content=original',
    },
    {
      'title': 'Ambient Chill Wave',
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/9/9b/Chill_Wave_%28ISRC_USUAN1600048%29.mp3?utm_source=commons.wikimedia.org&utm_campaign=index&utm_content=original',
    },
    {
      'title': 'Piano Focus Beats',
      'url':
          'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
    },
  ];

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return 'Local audio';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = (bytes / 1024).round();
    return '$kb KB';
  }

  String _stripExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) return filename;
    return filename.substring(0, dotIndex);
  }

  // file_picker 13.x: FilePicker.pickFiles() is static, supports multi-select
  // by default, and returns List<PlatformFile> directly (empty when canceled).
  // PlatformFile.size and .bytes are removed; use lengthSync()/length() and
  // readAsBytes() instead.
  Future<void> _pickLocalAudioFiles() async {
    if (_isPickingFiles) return;
    setState(() => _isPickingFiles = true);

    try {
      final List<PlatformFile> picked = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (picked.isEmpty) return;

      final List<_LocalAudioTrack> newlyAdded = [];

      for (final PlatformFile file in picked) {
        final int size = file.lengthSync() ?? await file.length() ?? 0;
        final String? uri = await _audioService.registerLocalFile(
          file,
          sizeBytes: size,
        );
        if (uri == null) continue;

        newlyAdded.add(
          _LocalAudioTrack(
            id:
                '${file.name}_${size}_${DateTime.now().microsecondsSinceEpoch}',
            title: _stripExtension(file.name),
            sourceUri: uri,
            sizeLabel: _formatFileSize(size),
          ),
        );
      }

      if (!mounted) return;
      if (newlyAdded.isNotEmpty) {
        setState(() => _localTracks.insertAll(0, newlyAdded));

        if (!_audioService.isPlaying) {
          await _audioService.loadPlaylist(newlyAdded.first.sourceUri);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load audio file: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingFiles = false);
      }
    }
  }

  Future<void> _loadStreamUrl(String rawUrl, {bool clearInput = false}) async {
    final url = rawUrl.trim();
    if (url.isEmpty || _isLoadingStream) return;

    setState(() => _isLoadingStream = true);
    try {
      await _audioService.loadPlaylist(url);
      if (!mounted) return;
      if (clearInput) {
        _urlController.clear();
      }
      if (_audioService.queueLength > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Loaded playlist (${_audioService.queueLength} tracks)',
            ),
          ),
        );
      }
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play stream: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingStream = false);
      }
    }
  }

  void _playOrPause(String url) {
    if (_audioService.currentUrl == url) {
      _audioService.togglePlayPause();
    } else {
      _loadStreamUrl(url);
    }
  }

  void _removeLocalTrack(_LocalAudioTrack track) {
    if (_audioService.currentUrl == track.sourceUri) {
      _audioService.stop();
    }
    _audioService.unregisterLocalFile(track.sourceUri);
    setState(() {
      _localTracks.removeWhere((t) => t.id == track.id);
    });
  }

  void _showQueueBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ListenableBuilder(
          listenable: _audioService,
          builder: (context, _) {
            final queue = _audioService.queue;
            final colorScheme = Theme.of(context).colorScheme;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Playlist Queue (${queue.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final trackUrl = queue[index];
                        final isCurrent =
                            index == _audioService.currentQueueIndex;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            isCurrent
                                ? Icons.equalizer_rounded
                                : Icons.radio_rounded,
                            color: isCurrent
                                ? _accentColor
                                : colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            _audioService.getDisplayName(trackUrl),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            trackUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onTap: () {
                            _audioService.playTrackAt(index);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStudyTechniquesGuide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Text('🎧', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 8),
                      Text(
                        'Focus Audio Tips',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sharpen your deep concentration with these audio techniques!',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Acoustic Masking Technique Card
                  _buildTechniqueCard(
                    emoji: '🎵',
                    title: '1. Acoustic Masking',
                    subtitle: 'Noise Control',
                    accentColor: Colors.purple.shade100,
                    borderColor: Colors.purple.shade400,
                    description:
                        'Steady, lyric-free audio smooths out jarring environmental sounds that would otherwise pull your focus away from your work.',
                    steps: const [
                      "🚫 Step 1: Eliminate Lyrics – Choose purely instrumental tracks, lofi hip-hop, or ambient soundscapes so spoken words never compete with your brain's language centers.",
                      '🔉 Step 2: Keep Volume Low – Set the audio just loud enough to blur background chatter or street noise without becoming the center of your attention.',
                      '🥁 Step 3: Favor Steady Tempos – Pick tracks with consistent rhythms and minimal sudden drops or dramatic builds that could interrupt your train of thought.',
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Habit Conditioning Technique Card
                  _buildTechniqueCard(
                    emoji: '🧠',
                    title: '2. Habit Conditioning',
                    subtitle: 'Mental Triggers',
                    accentColor: Colors.teal.shade100,
                    borderColor: Colors.teal.shade400,
                    description:
                        'While masking blocks external distractions, consistently pairing specific audio with deep work trains your brain to shift into focus mode on command.',
                    steps: const [
                      '🎧 Step 1: Reserve a Dedicated Playlist – Use your focus tracks exclusively while studying or working so your brain associates those exact sounds with concentration.',
                      '▶️ Step 2: Press Play to Start – Put on your headphones right as you sit down to signal the transition from rest to active effort, lowering the friction of starting.',
                      '🔇 Step 3: Mute for Peak Complexity – Pause the audio when tackling unfamiliar, high-difficulty problems that require every ounce of working memory.',
                    ],
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.rocket_launch, size: 18),
                      label: const Text("Got it! Let's Focus"),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTechniqueCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color borderColor,
    required String description,
    required List<String> steps,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          const Divider(height: 20),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                step,
                style: const TextStyle(fontSize: 12.5, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade100,
              Colors.orange.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.shade200.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _showStudyTechniquesGuide,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('💡', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Focus Smarter!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Learn Acoustic Masking & Habit Conditioning',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.amber.shade900,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _audioService,
      builder: (context, _) {
        final presetUrls = _presets.map((p) => p['url']!).toSet();
        final savedStreams = _audioService.favorites
            .where((url) => !presetUrls.contains(url))
            .toList();

        final bool isLiveStream = _audioService.currentUrl != null &&
            _audioService.duration == Duration.zero;
        final double maxSeconds = _audioService.duration.inSeconds > 0
            ? _audioService.duration.inSeconds.toDouble()
            : 1.0;
        final double currentSeconds = _audioService.position.inSeconds
            .toDouble()
            .clamp(0.0, maxSeconds);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Focus Audio'),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      _buildStudyBanner(),

                      // Pick local audio files button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed:
                              _isPickingFiles ? null : _pickLocalAudioFiles,
                          icon: _isPickingFiles
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.folder_open_rounded),
                          label: Text(
                            _isPickingFiles
                                ? 'Opening File Picker...'
                                : 'Play Audio from Device',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Custom Stream / Radio Playlist URL input
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (val) =>
                            _loadStreamUrl(val, clearInput: true),
                        decoration: InputDecoration(
                          labelText: 'Radio Stream or .m3u / .pls URL',
                          hintText: 'https://example.com/radio.m3u',
                          prefixIcon: const Icon(Icons.radio_rounded),
                          suffixIcon: _isLoadingStream
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.play_circle_fill),
                                  tooltip: 'Play stream or playlist',
                                  onPressed: () => _loadStreamUrl(
                                    _urlController.text,
                                    clearInput: true,
                                  ),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supports internet radio playlists (.m3u, .m3u8, .pls) and direct streams (.mp3, .ogg, .aac).',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Saved Radio Stations & Custom URLs
                      if (savedStreams.isNotEmpty) ...[
                        const Text(
                          'Recent Streams & Radio Playlists',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...savedStreams.map((streamUrl) {
                          final isCurrent =
                              _audioService.currentUrl == streamUrl;
                          final isPlaylist = RegExp(
                            r'\.(m3u|m3u8|pls)(\?.*)?$',
                            caseSensitive: false,
                          ).hasMatch(streamUrl);

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              leading: Icon(
                                isCurrent && _audioService.isPlaying
                                    ? Icons.equalizer_rounded
                                    : (isPlaylist
                                        ? Icons.queue_music_rounded
                                        : Icons.radio_rounded),
                                color: _accentColor,
                              ),
                              title: Text(
                                _audioService.getDisplayName(streamUrl),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                streamUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isCurrent && _audioService.isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                      size: 32,
                                      color: _accentColor,
                                    ),
                                    onPressed: () => _playOrPause(streamUrl),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                    tooltip: 'Remove from history',
                                    onPressed: () =>
                                        _audioService.removeFavorite(streamUrl),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],

                      // Imported Local Tracks Section
                      if (_localTracks.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My Device Audio (${_localTracks.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isPickingFiles
                                  ? null
                                  : _pickLocalAudioFiles,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add More'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ..._localTracks.map((track) {
                          final isCurrent =
                              _audioService.currentUrl == track.sourceUri;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              leading: Icon(
                                isCurrent && _audioService.isPlaying
                                    ? Icons.equalizer_rounded
                                    : Icons.audio_file_rounded,
                                color: _accentColor,
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(track.sizeLabel),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isCurrent && _audioService.isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                      size: 32,
                                      color: _accentColor,
                                    ),
                                    onPressed: () =>
                                        _playOrPause(track.sourceUri),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                    tooltip: 'Remove from list',
                                    onPressed: () => _removeLocalTrack(track),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],

                      const Text(
                        'Featured Focus Streams',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // List of Presets
                      ..._presets.map((preset) {
                        final url = preset['url']!;
                        final isCurrent = _audioService.currentUrl == url;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(
                              isCurrent && _audioService.isPlaying
                                  ? Icons.equalizer_rounded
                                  : Icons.music_note_rounded,
                              color: _accentColor,
                            ),
                            title: Text(preset['title']!),
                            subtitle: Text(
                              _audioService.getDisplayName(
                                url,
                                fallback: preset['title'],
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isCurrent && _audioService.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                size: 32,
                                color: _accentColor,
                              ),
                              onPressed: () => _playOrPause(url),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Player Controls Bar
                if (_audioService.currentUrl != null) ...[
                  const Divider(),
                  if (_audioService.queueLength > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _showQueueBottomSheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.queue_music_rounded,
                                size: 16,
                                color: _accentColor,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Track ${_audioService.currentQueueIndex + 1} of ${_audioService.queueLength} • ${_audioService.getDisplayName(_audioService.currentUrl!)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (isLiveStream)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'LIVE STREAM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _audioService.formatDuration(_audioService.position),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          _audioService.formatDuration(_audioService.position),
                        ),
                        Expanded(
                          child: Slider(
                            value: currentSeconds,
                            max: maxSeconds,
                            onChanged: (val) {
                              _audioService
                                  .seek(Duration(seconds: val.toInt()));
                            },
                          ),
                        ),
                        Text(
                          _audioService.formatDuration(_audioService.duration),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Text(_audioService.getRepeatModeIcon()),
                        onPressed: _audioService.cycleRepeatMode,
                      ),
                      if (_audioService.queueLength > 1)
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: _audioService.currentQueueIndex > 0
                              ? _audioService.skipPrevious
                              : null,
                        ),
                      IconButton(
                        iconSize: 48,
                        icon: Icon(
                          _audioService.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: _accentColor,
                        ),
                        onPressed: _audioService.togglePlayPause,
                      ),
                      if (_audioService.queueLength > 1)
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: _audioService.currentQueueIndex <
                                  _audioService.queueLength - 1
                              ? _audioService.skipNext
                              : null,
                        ),
                      IconButton(
                        icon: const Icon(Icons.stop_rounded),
                        onPressed: _audioService.stop,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MiniStopwatchBar(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StopwatchPage(),
                    ),
                  );
                },
              ),
              const MiniAudioPlayer(),
            ],
          ),
        );
      },
    );
  }
}
