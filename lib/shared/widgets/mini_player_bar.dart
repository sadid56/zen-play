import 'package:flutter/material.dart';
import 'package:zenplay/core/models/video_item.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    required this.video,
    required this.isPlaying,
    required this.progress,
    required this.onTap,
    required this.onTogglePlay,
    required this.onClose,
  });

  final VideoItem video;
  final bool isPlaying;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onTogglePlay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thumbUrl = video.thumbnailUrl;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2.5,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 56,
                      height: 36,
                      color: Color(video.accentColorValue),
                      child: thumbUrl != null && thumbUrl.isNotEmpty
                          ? Image.network(
                              thumbUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                          : const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          video.channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onTogglePlay,
                    icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    tooltip: isPlaying ? 'Pause' : 'Play',
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close player',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
