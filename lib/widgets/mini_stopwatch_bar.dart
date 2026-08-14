import 'package:flutter/material.dart';
import '../controllers/stopwatch_controller.dart';

class MiniStopwatchBar extends StatelessWidget {
  final VoidCallback? onTap;

  const MiniStopwatchBar({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final controller = StopwatchController.instance;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isRunning) return const SizedBox.shrink();

        final textColor = Theme.of(context).colorScheme.onSurface;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.timer, color: controller.barColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        controller.currentSubject,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Studying in progress...',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  controller.formatDuration(controller.stopwatch.elapsed),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: controller.barColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}