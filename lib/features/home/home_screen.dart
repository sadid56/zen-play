import 'package:flutter/material.dart';
import 'package:zenplay/core/data/video_repository.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/filter_chip_bar.dart';
import 'package:zenplay/shared/widgets/video_card.dart';
import 'package:zenplay/shared/widgets/video_skeleton.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
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
        final videos = controller.feedVideos;

        return Column(
          children: [
            FilterChipBar(
              items: VideoRepository.categories,
              selected: controller.selectedCategory,
              onSelected: controller.setCategory,
            ),
            Expanded(
              child: controller.isLoadingFeed
                  ? const VideoFeedSkeleton()
                  : videos.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.video_collection_outlined,
                          title: 'No videos in this category',
                          subtitle: 'Try selecting another topic above.',
                        )
                      : RefreshIndicator(
                          onRefresh: () => controller.loadFeed(),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: videos.length,
                            itemBuilder: (_, index) {
                              final video = videos[index];
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
            ),
          ],
        );
      },
    );
  }
}
