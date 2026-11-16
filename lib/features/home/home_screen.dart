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
            Expanded(
              child: widget.controller.isLoadingFeed
                  ? const VideoFeedSkeleton()
                  : videos.isEmpty
                      ? const EmptyStateView(
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
