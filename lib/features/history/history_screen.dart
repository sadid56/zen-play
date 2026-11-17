import 'package:material_ui/material_ui.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/video_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
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

        if (history.isEmpty) {
          return const EmptyStateView(
            icon: Icons.history_rounded,
            title: 'No watch history yet',
            subtitle: 'Your 10 most recently watched videos will appear here.',
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent History (${history.length}/10)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  TextButton.icon(
                    onPressed: controller.clearHistory,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: history.length,
                itemBuilder: (_, index) {
                  final video = history[index];
                  return VideoCard(
                    video: video,
                    isSaved: controller.isSaved(video.id),
                    isDownloaded: controller.isDownloaded(video.id),
                    showDeArrowBadge: controller.deArrowEnabled,
                    showSponsorBlockBadge: controller.sponsorBlockEnabled,
                    onTap: () => onOpenVideo(video),
                    onChannelTap: () => onOpenChannel(video.channel),
                    onSaveTap: () => controller.toggleWatchLater(video.id),
                    onDownloadTap: () => controller.toggleDownload(video.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
