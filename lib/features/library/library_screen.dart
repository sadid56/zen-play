import 'package:flutter/material.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/video_card.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    required this.onOpenVideo,
    required this.onOpenChannel,
  });

  final ZenPlayController controller;
  final ValueChanged<VideoItem> onOpenVideo;
  final ValueChanged<ChannelInfo> onOpenChannel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final history = controller.historyVideos;
        final watchLater = controller.watchLaterVideos;

        if (history.isEmpty && watchLater.isEmpty) {
          return const EmptyStateView(
            icon: Icons.video_library_outlined,
            title: 'Your library is empty',
            subtitle: 'Watched and saved videos will appear here.',
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (watchLater.isNotEmpty) ...[
              _SectionTitle('Watch later (${watchLater.length})'),
              for (final video in watchLater)
                VideoCard(
                  video: video,
                  isSaved: true,
                  isDownloaded: controller.isDownloaded(video.id),
                  showDeArrowBadge: controller.deArrowEnabled,
                  showSponsorBlockBadge: controller.sponsorBlockEnabled,
                  onTap: () => onOpenVideo(video),
                  onChannelTap: () => onOpenChannel(video.channel),
                  onSaveTap: () => controller.toggleWatchLater(video.id),
                  onDownloadTap: () => controller.toggleDownload(video.id),
                ),
            ],
            if (history.isNotEmpty) ...[
              _SectionTitle('Recent history (${history.length})'),
              for (final video in history)
                VideoCard(
                  video: video,
                  isSaved: controller.isSaved(video.id),
                  isDownloaded: controller.isDownloaded(video.id),
                  showDeArrowBadge: controller.deArrowEnabled,
                  showSponsorBlockBadge: controller.sponsorBlockEnabled,
                  onTap: () => onOpenVideo(video),
                  onChannelTap: () => onOpenChannel(video.channel),
                  onSaveTap: () => controller.toggleWatchLater(video.id),
                  onDownloadTap: () => controller.toggleDownload(video.id),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
