import 'package:flutter/material.dart';
import 'package:zenplay/core/data/video_repository.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/channel_avatar.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/save_to_folder_sheet.dart';
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
  late Future<ChannelProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.controller.fetchChannelProfile(widget.channel);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return FutureBuilder<ChannelProfileData>(
          future: _profileFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final profile = snapshot.data;
            final displayChannel = widget.channel.copyWith(
              subscriberCount:
                  profile?.subscriberCount ?? widget.channel.subscriberCount,
              avatarUrl: profile?.avatarUrl ?? widget.channel.avatarUrl,
            );
            final uploads = profile?.uploads ?? const [];

            return DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(title: Text(displayChannel.name)),
                body: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          ChannelAvatar(channel: displayChannel, radius: 30),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayChannel.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (displayChannel.isVerified) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (isLoading &&
                                    displayChannel.subscriberCount ==
                                        'YouTube channel')
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: SkeletonBox(width: 130, height: 12),
                                  )
                                else
                                  Text(
                                    '${displayChannel.handle} • ${displayChannel.subscriberCount}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
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
                          if (isLoading)
                            const VideoFeedSkeleton(itemCount: 2)
                          else if (uploads.isEmpty)
                            const EmptyStateView(
                              icon: Icons.video_library_outlined,
                              title: 'No videos found',
                              subtitle:
                                  'Uploads from this channel will appear here.',
                            )
                          else
                            ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: uploads.length,
                              itemBuilder: (_, index) {
                                final video = uploads[index];
                                return VideoCard(
                                  video: video,
                                  isSaved:
                                      widget.controller.isSaved(video.id),
                                  isDownloaded:
                                      widget.controller.isDownloaded(video.id),
                                  showDeArrowBadge:
                                      widget.controller.deArrowEnabled,
                                  showSponsorBlockBadge:
                                      widget.controller.sponsorBlockEnabled,
                                  onTap: () => widget.onOpenVideo(video),
                                  onSaveTap: () => showSaveToFolderSheet(
                                    context,
                                    widget.controller,
                                    video.id,
                                  ),
                                  onDownloadTap: () =>
                                      widget.controller.toggleDownload(video.id),
                                );
                              },
                            ),
                          _ChannelAboutTab(
                            isLoading: isLoading,
                            channel: displayChannel,
                            profile: profile,
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
      },
    );
  }
}

class _ChannelAboutTab extends StatelessWidget {
  const _ChannelAboutTab({
    required this.isLoading,
    required this.channel,
    required this.profile,
  });

  final bool isLoading;
  final ChannelInfo channel;
  final ChannelProfileData? profile;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 120, height: 16),
            SizedBox(height: 12),
            SkeletonBox(height: 14),
            SizedBox(height: 8),
            SkeletonBox(width: 240, height: 14),
            SizedBox(height: 24),
            SkeletonBox(width: 180, height: 14),
            SizedBox(height: 12),
            SkeletonBox(width: 160, height: 14),
          ],
        ),
      );
    }

    final description = profile?.description;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Description',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          description != null && description.trim().isNotEmpty
              ? description
              : 'No channel description available.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text(
          'More info',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alternate_email_rounded),
          title: Text(channel.handle),
          subtitle: const Text('Handle'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.people_outline_rounded),
          title: Text(channel.subscriberCount),
          subtitle: const Text('Subscribers'),
        ),
        if (profile?.videoCountText != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.video_library_outlined),
            title: Text(profile!.videoCountText!),
            subtitle: const Text('Videos'),
          ),
        if (profile?.viewCountText != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.trending_up_rounded),
            title: Text(profile!.viewCountText!),
            subtitle: const Text('Total views'),
          ),
        if (profile?.joinedDateText != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(profile!.joinedDateText!),
            subtitle: const Text('Joined'),
          ),
        if (profile?.country != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.public_rounded),
            title: Text(profile!.country!),
            subtitle: const Text('Location'),
          ),
      ],
    );
  }
}
