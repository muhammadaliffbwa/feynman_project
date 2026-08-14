// lib/screens/focus_audio_page.dart

import 'package:flutter/material.dart';
import '../services/music_player_service.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class FocusAudioPage extends StatefulWidget {
  const FocusAudioPage({super.key});

  @override
  State<FocusAudioPage> createState() => _FocusAudioPageState();
}

class _FocusAudioPageState extends State<FocusAudioPage> {
  final MusicPlayerService _audioService = MusicPlayerService();
  final TextEditingController _urlController = TextEditingController();

  // Reliable CORS-enabled test audio streams
  final List<Map<String, String>> _presets = [
    {
      'title': 'Lofi Study Stream',
      'url': 'https://upload.wikimedia.org/wikipedia/commons/9/9c/Study_And_Relax_by_Kevin_MacLeod.ogg?utm_source=commons.wikimedia.org&utm_campaign=index&utm_content=original',
    },
    {
      'title': 'Ambient Chill Wave',
      'url': 'https://upload.wikimedia.org/wikipedia/commons/9/9b/Chill_Wave_%28ISRC_USUAN1600048%29.mp3?utm_source=commons.wikimedia.org&utm_campaign=index&utm_content=original',
    },
    {
      'title': 'Piano Focus Beats',
      'url': 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
    },
  ];

  @override
  void dispose() {
    // Only dispose the text controller. Do NOT dispose _audioService!
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _audioService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Focus Audio'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom Stream URL input
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'Stream Audio URL',
                    hintText: 'https://...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.play_circle_fill),
                      onPressed: () {
                        if (_urlController.text.isNotEmpty) {
                          _audioService.loadPlaylist(_urlController.text);
                        }
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Featured Focus Streams',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // List of Presets
                Expanded(
                  child: ListView.builder(
                    itemCount: _presets.length,
                    itemBuilder: (context, index) {
                      final preset = _presets[index];
                      final isCurrent = _audioService.currentUrl == preset['url'];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(
                            isCurrent && _audioService.isPlaying
                                ? Icons.equalizer_rounded
                                : Icons.music_note_rounded,
                            color: const Color(0xFF6C5CE7),
                          ),
                          title: Text(preset['title']!),
                          subtitle: Text(
                            _audioService.getDisplayName(preset['url']!),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isCurrent && _audioService.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              size: 32,
                              color: const Color(0xFF6C5CE7),
                            ),
                            onPressed: () {
                              if (isCurrent) {
                                _audioService.togglePlayPause();
                              } else {
                                _audioService.loadPlaylist(preset['url']!);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Player Controls Bar
                if (_audioService.currentUrl != null) ...[
                  const Divider(),
                  Row(
                    children: [
                      Text(_audioService.formatDuration(_audioService.position)),
                      Expanded(
                        child: Slider(
                          value: _audioService.position.inSeconds
                              .toDouble()
                              .clamp(0.0, _audioService.duration.inSeconds.toDouble()),
                          max: _audioService.duration.inSeconds > 0
                              ? _audioService.duration.inSeconds.toDouble()
                              : 1.0,
                          onChanged: (val) {
                            _audioService.seek(Duration(seconds: val.toInt()));
                          },
                        ),
                      ),
                      Text(_audioService.formatDuration(_audioService.duration)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Text(_audioService.getRepeatModeIcon()),
                        onPressed: _audioService.cycleRepeatMode,
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop_rounded),
                        onPressed: _audioService.stop,
                      ),
                      IconButton(
                        iconSize: 48,
                        icon: Icon(
                          _audioService.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: const Color(0xFF6C5CE7),
                        ),
                        onPressed: _audioService.togglePlayPause,
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
                MaterialPageRoute(builder: (_) => const StopwatchPage()),
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