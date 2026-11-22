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

  void _showStudyTechniquesGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
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
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    // The page padding already insets this row, so only a gap underneath is needed.
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                _buildStudyBanner(),

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