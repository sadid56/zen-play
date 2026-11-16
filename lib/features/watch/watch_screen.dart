import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/channel_avatar.dart';
import 'package:zenplay/shared/widgets/save_to_folder_sheet.dart';
import 'package:zenplay/shared/widgets/video_card.dart';
import 'package:zenplay/shared/widgets/video_skeleton.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    required this.controller,
    required this.onOpenChannel,
  });

  final ZenPlayController controller;
  final ValueChanged<ChannelInfo> onOpenChannel;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  static const MethodChannel _pipChannel = MethodChannel('com.zenplay.app/pip');

  bool _descriptionExpanded = false;
  bool _isInPipMode = false;
  YoutubePlayerController? _ytController;
  StreamSubscription<YoutubeVideoState>? _videoStateSub;
  String? _loadedVideoId;
  String? _skippedNotice;

  @override
  void initState() {
    super.initState();
    _pipChannel.setMethodCallHandler(_handlePipCall);
    widget.controller.addListener(_syncPlayerWithState);
    _syncPlayerWithState();
  }

  @override
  void dispose() {
    _setNativePipEnabled(false);
    _pipChannel.setMethodCallHandler(null);
    widget.controller.removeListener(_syncPlayerWithState);
    _videoStateSub?.cancel();
    _ytController?.close();
    super.dispose();
  }

  Future<dynamic> _handlePipCall(MethodCall call) async {
    if (call.method == 'onPipChanged' && mounted) {
      setState(() => _isInPipMode = call.arguments == true);
    }
  }

  Future<void> _setNativePipEnabled(bool enabled) async {
    try {
      await _pipChannel.invokeMethod('setPipEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> _enterPip() async {
    try {
      await _pipChannel.invokeMethod('enterPip');
    } catch (_) {}
  }

  void _syncPlayerWithState() {
    _setNativePipEnabled(widget.controller.backgroundPlayEnabled);
    final video = widget.controller.activeVideo;
    if (video == null) return;

    if (_ytController == null) {
      _initPlayer(video);
      return;
    }

    if (_loadedVideoId != video.id) {
      _loadedVideoId = video.id;
      _skippedNotice = null;
      _ytController!.loadVideoById(videoId: video.id);
    }

    _ytController!.setPlaybackRate(widget.controller.playbackSpeed);
  }

  void _initPlayer(VideoItem video) {
    _loadedVideoId = video.id;
    final next = YoutubePlayerController.fromVideoId(
      videoId: video.id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        mute: false,
      ),
    );

    _videoStateSub?.cancel();
    _videoStateSub = next.videoStateStream.listen((state) {
      final posSec = state.position.inMilliseconds / 1000.0;
      if (video.durationSeconds > 0) {
        widget.controller.seekTo(posSec / video.durationSeconds);
      }

      if (widget.controller.sponsorBlockEnabled) {
        for (final seg in widget.controller.activeSponsorSegments) {
          if (posSec >= seg.startSeconds && posSec < seg.endSeconds - 0.5) {
            next.seekTo(seconds: seg.endSeconds, allowSeekAhead: true);
            if (mounted) {
              setState(() => _skippedNotice = 'Skipped ${seg.category}');
            }
            break;
          }
        }
      }
    });

    _ytController = next;
    if (mounted) setState(() {});
  }

  void _showQualitySheet(BuildContext context) {
    const qualities = ['2160p 4K', '1440p', '1080p', '720p', '480p', '360p'];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const ListTile(
              title: Text('Resolution', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final q in qualities)
              ListTile(
                title: Text(q),
                trailing: widget.controller.selectedQuality == q
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  widget.controller.setQuality(q);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDownloadSheet(BuildContext context, VideoItem video) {
    const qualities = ['1080p MP4', '720p MP4', '480p MP4', 'Audio only M4A'];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const ListTile(
              title: Text(
                'Download resolution',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final q in qualities)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(q),
                onTap: () {
                  widget.controller.saveDownload(video.id, q);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved "${video.title}" ($q)')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareVideo(BuildContext context, VideoItem video) async {
    final url = 'https://youtu.be/${video.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied: $url')),
    );
  }

  void _showSpeedSheet(BuildContext context) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const ListTile(
              title: Text('Playback speed', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final s in speeds)
              ListTile(
                title: Text('${s}x'),
                trailing: widget.controller.playbackSpeed == s
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  widget.controller.setPlaybackSpeed(s);
                  _ytController?.setPlaybackRate(s);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final video = widget.controller.activeVideo;
            if (video == null) return const SizedBox.shrink();
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Comments (${video.comments.length})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: widget.controller.isLoadingWatchDetails &&
                          video.comments.isEmpty
                      ? ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: 4,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (_, __) => const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 140, height: 12),
                              SizedBox(height: 8),
                              SkeletonBox(height: 14),
                            ],
                          ),
                        )
                      : video.comments.isEmpty
                          ? const Center(child: Text('No comments yet.'))
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: video.comments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (_, index) {
                                final c = video.comments[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${c.author} • ${c.publishedAgo}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c.text),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${c.likes} likes • ${c.replyCount} replies',
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ],
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showLiveChatSheet(BuildContext context) {
    final chatController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) => ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final messages = widget.controller.liveChatMessages;
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.forum_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Live Chat',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final msg = messages[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  children: [
                                    TextSpan(
                                      text: '${msg.author}  ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(text: msg.message),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              msg.timestampLabel,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatController,
                            decoration: const InputDecoration(
                              hintText: 'Send a live chat message...',
                              border: InputBorder.none,
                            ),
                            onSubmitted: (value) {
                              widget.controller.sendLiveChatMessage(value);
                              chatController.clear();
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            widget.controller.sendLiveChatMessage(chatController.text);
                            chatController.clear();
                          },
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ).whenComplete(chatController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final video = widget.controller.activeVideo;
        if (video == null) {
          return const Scaffold(
            body: Center(child: Text('No active video')),
          );
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final upNext = widget.controller.upNextFor(video);
        final player = _ytController;

        if (_isInPipMode) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: player != null
                  ? YoutubePlayer(controller: player)
                  : const CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                GestureDetector(
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 350) {
                      Navigator.pop(context);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (player != null)
                        YoutubePlayer(controller: player)
                      else
                        const AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      Container(
                        color: scheme.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
                              tooltip: 'Minimize',
                            ),
                            if (_skippedNotice != null ||
                                (widget.controller.sponsorBlockEnabled &&
                                    video.hasSponsorBlock))
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  _skippedNotice ?? 'SponsorBlock active',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            const Spacer(),
                            IconButton(
                              onPressed: _enterPip,
                              icon: const Icon(
                                Icons.picture_in_picture_alt_rounded,
                                size: 20,
                              ),
                              tooltip: 'Picture-in-Picture',
                            ),
                            TextButton(
                              onPressed: () => _showSpeedSheet(context),
                              child: Text('${widget.controller.playbackSpeed}x'),
                            ),
                            TextButton(
                              onPressed: () => _showQualitySheet(context),
                              child: Text(widget.controller.selectedQuality),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${video.viewsText} • ${video.publishedAgo}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onOpenChannel(video.channel),
                          child: Row(
                            children: [
                              ChannelAvatar(
                                channel: video.channel,
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video.channel.name,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      video.channel.subscriberCount,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _LikeDislikePill(
                              likesCount: video.likesCount,
                              dislikesCount: widget.controller.returnDislikeEnabled
                                  ? video.dislikesCount
                                  : null,
                              isLiked: widget.controller.isLiked(video.id),
                              isDisliked: widget.controller.isDisliked(video.id),
                              onLikeTap: () => widget.controller.toggleLike(video.id),
                              onDislikeTap: () =>
                                  widget.controller.toggleDislike(video.id),
                            ),
                            const SizedBox(width: 8),
                            _ActionPill(
                              icon: Icons.share_outlined,
                              label: 'Share',
                              onTap: () => _shareVideo(context, video),
                            ),
                            const SizedBox(width: 8),
                            _ActionPill(
                              icon: widget.controller.isDownloaded(video.id)
                                  ? Icons.download_done_rounded
                                  : Icons.download_outlined,
                              label: widget.controller.isDownloaded(video.id)
                                  ? 'Downloaded (${widget.controller.downloadedQualityFor(video.id) ?? ''})'
                                  : 'Download',
                              isActive: widget.controller.isDownloaded(video.id),
                              onTap: () => _showDownloadSheet(context, video),
                            ),
                            const SizedBox(width: 8),
                            _ActionPill(
                              icon: widget.controller.isSaved(video.id)
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_add_outlined,
                              label: widget.controller.isSaved(video.id)
                                  ? 'Saved'
                                  : 'Save',
                              isActive: widget.controller.isSaved(video.id),
                              onTap: () => showSaveToFolderSheet(
                                context,
                                widget.controller,
                                video.id,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ActionPill(
                              icon: Icons.comment_outlined,
                              label: 'Comments (${video.comments.length})',
                              onTap: () => _showCommentsSheet(context),
                            ),
                            if (video.isLive) ...[
                              const SizedBox(width: 8),
                              _ActionPill(
                                icon: Icons.forum_outlined,
                                label: 'Live chat',
                                onTap: () => _showLiveChatSheet(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showCommentsSheet(context),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Comments',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${video.comments.length}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.unfold_more_rounded,
                                        size: 18,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                  if (video.comments.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      video.comments.first.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() {
                              _descriptionExpanded = !_descriptionExpanded;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Description & Chapters',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Icon(
                                        _descriptionExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    video.description.isEmpty
                                        ? 'No description provided.'
                                        : video.description,
                                    maxLines: _descriptionExpanded ? null : 2,
                                    overflow: _descriptionExpanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (_descriptionExpanded && video.chapters.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    for (final chapter in video.chapters)
                                      ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Text(
                                          chapter.timestamp,
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        title: Text(chapter.title),
                                        onTap: () {
                                          _ytController?.seekTo(
                                            seconds: chapter.seconds.toDouble(),
                                            allowSeekAhead: true,
                                          );
                                        },
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                        child: Text(
                          'Up next',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final next in upNext)
                        VideoCard(
                          video: next,
                          isSaved: widget.controller.isSaved(next.id),
                          isDownloaded: widget.controller.isDownloaded(next.id),
                          showDeArrowBadge: widget.controller.deArrowEnabled,
                          showSponsorBlockBadge: widget.controller.sponsorBlockEnabled,
                          onTap: () => widget.controller.playVideo(next),
                          onChannelTap: () => widget.onOpenChannel(next.channel),
                          onSaveTap: () => widget.controller.toggleWatchLater(next.id),
                          onDownloadTap: () => widget.controller.toggleDownload(next.id),
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

class _LikeDislikePill extends StatelessWidget {
  const _LikeDislikePill({
    required this.likesCount,
    required this.dislikesCount,
    required this.isLiked,
    required this.isDisliked,
    required this.onLikeTap,
    required this.onDislikeTap,
  });

  final String likesCount;
  final String? dislikesCount;
  final bool isLiked;
  final bool isDisliked;
  final VoidCallback onLikeTap;
  final VoidCallback onDislikeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
            onTap: onLikeTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                    size: 18,
                    color: isLiked ? scheme.primary : scheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    likesCount,
                    style: labelStyle?.copyWith(
                      color: isLiked ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: scheme.outlineVariant,
          ),
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(22)),
            onTap: onDislikeTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                    size: 18,
                    color: isDisliked ? scheme.primary : scheme.onSurface,
                  ),
                  if (dislikesCount != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      dislikesCount!,
                      style: labelStyle?.copyWith(
                        color: isDisliked ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isActive ? scheme.secondaryContainer : scheme.surfaceContainerHigh;
    final fg = isActive ? scheme.onSecondaryContainer : scheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
