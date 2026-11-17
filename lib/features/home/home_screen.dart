import 'package:flutter/material.dart';
import 'package:zenplay/core/data/video_repository.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/filter_chip_bar.dart';
import 'package:zenplay/shared/widgets/save_to_folder_sheet.dart';
import 'package:zenplay/shared/widgets/video_card.dart';
import 'package:zenplay/shared/widgets/video_skeleton.dart';

class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      widget.controller.loadMoreFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final videos = widget.controller.feedVideos;
        final isLoadingMore = widget.controller.isLoadingMoreFeed;

        return Column(
          children: [
            FilterChipBar(
              items: VideoRepository.categories,
              selected: widget.controller.selectedCategory,
              onSelected: widget.controller.setCategory,
            ),
            if (widget.controller.isOfflineMode && videos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.controller.downloadedVideos.isNotEmpty
                                ? 'Offline mode • Showing downloaded videos'
                                : 'Offline mode • Download videos to watch offline',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              widget.controller.loadFeed(isRefresh: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: widget.controller.isLoadingFeed
                  ? const VideoFeedSkeleton()
                  : videos.isEmpty
                      ? widget.controller.isOfflineMode
                          ? EmptyStateView(
                              icon: Icons.cloud_off_rounded,
                              title: 'You\'re offline',
                              subtitle:
                                  'No downloaded videos yet. Connect to the internet to browse and download videos.',
                              action: FilledButton.icon(
                                onPressed: () =>
                                    widget.controller.loadFeed(isRefresh: true),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            )
                          : const EmptyStateView(
                              icon: Icons.video_collection_outlined,
                              title: 'No videos in this category',
                              subtitle: 'Try selecting another topic above.',
                            )
                      : RefreshIndicator(
                          onRefresh: () =>
                              widget.controller.loadFeed(isRefresh: true),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: videos.length + (isLoadingMore ? 1 : 0),
                            itemBuilder: (_, index) {
                              if (index >= videos.length) {
                                return const VideoCardSkeleton();
                              }
                              final video = videos[index];
                              return VideoCard(
                                video: video,
                                isSaved: widget.controller.isSaved(video.id),
                                isDownloaded:
                                    widget.controller.isDownloaded(video.id),
                                showDeArrowBadge:
                                    widget.controller.deArrowEnabled,
                                showSponsorBlockBadge:
                                    widget.controller.sponsorBlockEnabled,
                                onTap: () => widget.onOpenVideo(video),
                                onPrefetch: () =>
                                    widget.controller.prefetchVideo(video.id),
                                onChannelTap: () =>
                                    widget.onOpenChannel(video.channel),
                                onSaveTap: () => showSaveToFolderSheet(
                                  context,
                                  widget.controller,
                                  video.id,
                                ),
                                onDownloadTap: () =>
                                    widget.controller.toggleDownload(video.id),
                                onQueueTap: () {
                                  widget.controller.addToQueue(video);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Added to Up Next queue'),
                                    ),
                                  );
                                },
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
