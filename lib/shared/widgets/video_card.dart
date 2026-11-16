import 'package:flutter/material.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/shared/widgets/channel_avatar.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.onChannelTap,
    this.onSaveTap,
    this.onDownloadTap,
    this.isSaved = false,
    this.isDownloaded = false,
    this.showDeArrowBadge = false,
    this.showSponsorBlockBadge = false,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback? onChannelTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onDownloadTap;
  final bool isSaved;
  final bool isDownloaded;
  final bool showDeArrowBadge;
  final bool showSponsorBlockBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ThumbnailHeader(
              video: video,
              showDeArrowBadge: showDeArrowBadge && video.hasDeArrowTitle,
              showSponsorBlockBadge: showSponsorBlockBadge && video.hasSponsorBlock,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChannelAvatar(
                    channel: video.channel,
                    radius: 20,
                    onTap: onChannelTap,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${video.channel.name} • ${video.viewsText} • ${video.publishedAgo}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                    onSelected: (value) {
                      if (value == 'save') onSaveTap?.call();
                      if (value == 'download') onDownloadTap?.call();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'save',
                        child: Row(
                          children: [
                            Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
                            const SizedBox(width: 12),
                            Text(isSaved ? 'Remove from Watch later' : 'Save to Watch later'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(isDownloaded ? Icons.download_done : Icons.download_outlined),
                            const SizedBox(width: 12),
                            Text(isDownloaded ? 'Remove download' : 'Save for offline'),
                          ],
                        ),
                      ),
                    ],
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

class _ThumbnailHeader extends StatelessWidget {
  const _ThumbnailHeader({
    required this.video,
    required this.showDeArrowBadge,
    required this.showSponsorBlockBadge,
  });

  final VideoItem video;
  final bool showDeArrowBadge;
  final bool showSponsorBlockBadge;

  @override
  Widget build(BuildContext context) {
    final accent = Color(video.accentColorValue);
    final thumbUrl = video.thumbnailUrl;

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.9),
            accent.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 56,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbUrl != null && thumbUrl.isNotEmpty)
            Image.network(
              thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            )
          else
            fallback,
          if (showDeArrowBadge || showSponsorBlockBadge)
            Positioned(
              left: 10,
              top: 10,
              child: Wrap(
                spacing: 6,
                children: [
                  if (showSponsorBlockBadge)
                    const _OverlayPill(label: 'SponsorBlock'),
                  if (showDeArrowBadge)
                    const _OverlayPill(label: 'DeArrow'),
                ],
              ),
            ),
          Positioned(
            right: 10,
            bottom: 10,
            child: _OverlayPill(label: video.duration),
          ),
        ],
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
