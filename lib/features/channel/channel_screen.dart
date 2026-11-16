import 'package:flutter/material.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/channel_avatar.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/video_card.dart';
import 'package:zenplay/shared/widgets/video_skeleton.dart';

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({
    super.key,
    required this.channel,
    required this.controller,
    required this.onOpenVideo,
  });

  final ChannelInfo channel;
  final ZenPlayController controller;
  final ValueChanged<VideoItem> onOpenVideo;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  late Future<List<VideoItem>> _uploadsFuture;
  String? _subscriberCount;
  bool _isLoadingSubscribers = true;

  @override
  void initState() {
    super.initState();
    _subscriberCount = widget.channel.subscriberCount;
    _uploadsFuture = widget.controller.fetchChannelUploads(widget.channel.id);
    _loadSubscribers();
  }

  Future<void> _loadSubscribers() async {
    final subs = await widget.controller.fetchChannelSubscribers(widget.channel.id);
    if (mounted) {
      setState(() {
        if (subs != null) _subscriberCount = subs;
        _isLoadingSubscribers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(title: Text(widget.channel.name)),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      ChannelAvatar(channel: widget.channel, radius: 30),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.channel.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.channel.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, size: 18),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (_isLoadingSubscribers &&
                                (_subscriberCount == null ||
                                    _subscriberCount == 'YouTube channel'))
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: SkeletonBox(width: 130, height: 12),
                              )
                            else
                              Text(
                                '${widget.channel.handle} • ${_subscriberCount ?? widget.channel.subscriberCount}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Videos'),
                    Tab(text: 'About'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      FutureBuilder<List<VideoItem>>(
                        future: _uploadsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const VideoFeedSkeleton(itemCount: 2);
                          }
                          final videos = snapshot.data ?? const [];
                          if (videos.isEmpty) {
                            return const EmptyStateView(
                              icon: Icons.video_library_outlined,
                              title: 'No videos found',
                              subtitle: 'Uploads from this channel will appear here.',
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: videos.length,
                            itemBuilder: (_, index) {
                              final video = videos[index];
                              return VideoCard(
                                video: video,
                                isSaved: widget.controller.isSaved(video.id),
                                isDownloaded: widget.controller.isDownloaded(video.id),
                                showDeArrowBadge: widget.controller.deArrowEnabled,
                                showSponsorBlockBadge: widget.controller.sponsorBlockEnabled,
                                onTap: () => widget.onOpenVideo(video),
                                onSaveTap: () =>
                                    widget.controller.toggleWatchLater(video.id),
                                onDownloadTap: () =>
                                    widget.controller.toggleDownload(video.id),
                              );
                            },
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Channel details',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('${widget.channel.name} (${widget.channel.handle})'),
                            const SizedBox(height: 4),
                            Text(widget.channel.subscriberCount),
                          ],
                        ),
                      ),
                    ],
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
