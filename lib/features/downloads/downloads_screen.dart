import 'package:material_ui/material_ui.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/video_card.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({
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
        final downloads = controller.downloadedVideos;

        if (downloads.isEmpty) {
          return const EmptyStateView(
            icon: Icons.download_for_offline_outlined,
            title: 'No offline videos',
            subtitle: 'Save any video from its menu or watch page to play offline.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: downloads.length,
          itemBuilder: (_, index) {
            final video = downloads[index];
            final quality = controller.downloadedQualityFor(video.id);
            final progress = controller.downloadProgressFor(video.id);
            final isDownloading = progress != null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (quality != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDownloading
                              ? 'Downloading ($quality) • ${(progress * 100).round()}%'
                              : 'Downloaded locally • $quality',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (isDownloading) ...[
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: progress),
                        ],
                      ],
                    ),
                  ),
                VideoCard(
                  video: video,
                  isSaved: controller.isSaved(video.id),
                  isDownloaded: true,
                  showDeArrowBadge: controller.deArrowEnabled,
                  showSponsorBlockBadge: controller.sponsorBlockEnabled,
                  onTap: () => onOpenVideo(video),
                  onChannelTap: () => onOpenChannel(video.channel),
                  onSaveTap: () => controller.toggleWatchLater(video.id),
                  onDownloadTap: () => controller.removeDownload(video.id),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
