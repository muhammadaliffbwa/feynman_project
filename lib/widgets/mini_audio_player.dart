// lib/widgets/mini_audio_player.dart

import 'package:flutter/material.dart';
import '../screens/focus_audio_page.dart';
import '../services/music_player_service.dart';

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioService = MusicPlayerService();

    return AnimatedBuilder(
      animation: audioService,
      builder: (context, _) {
        // Hide mini player if no audio is loaded
        if (audioService.currentUrl == null) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Tap to open full Focus Audio page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FocusAudioPage(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      audioService.isPlaying
                          ? Icons.equalizer_rounded
                          : Icons.music_note_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Focus Audio',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            audioService.getDisplayName(audioService.currentUrl!),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        audioService.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                      ),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: audioService.togglePlayPause,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      iconSize: 20,
                      onPressed: audioService.stop,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}