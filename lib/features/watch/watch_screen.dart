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

  final GlobalKey _playerKey = GlobalKey();
  bool _descriptionExpanded = false;
  bool _isInPipMode = false;
  bool _isLoopEnabled = false;
  YoutubePlayerController? _loopAttachedController;

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
    super.dispose();
  }

  Future<dynamic> _handlePipCall(MethodCall call) async {
    if (call.method == 'onPipChanged' && mounted) {
      final inPip = call.arguments == true;
      setState(() => _isInPipMode = inPip);
      if (inPip) {
        widget.controller.youtubeController?.playVideo();
      }
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
    final player = widget.controller.youtubeController;
    if (player != null && _loopAttachedController != player) {
      _loopAttachedController = player;
      player.listen((value) {
        if (_isLoopEnabled && value.playerState == PlayerState.ended) {
          player.seekTo(seconds: 0, allowSeekAhead: true);
          player.playVideo();
        }
      });
    }
  }

  String _mapQualityToYoutubeCode(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('2160')) return 'hd2160';
    if (q.contains('1440')) return 'hd1440';
    if (q.contains('1080')) return 'hd1080';
    if (q.contains('720')) return 'hd720';
    if (q.contains('480')) return 'large';
    if (q.contains('360')) return 'medium';
    if (q.contains('240')) return 'small';
    return 'default';
  }

  Future<void> _applyPlayerQuality(String quality) async {
    widget.controller.setQuality(quality);
    final player = widget.controller.youtubeController;
    if (player == null) return;
    final code = _mapQualityToYoutubeCode(quality);
    try {
      await player.webViewController.runJavaScript(
        "if (window.player && window.player.setPlaybackQualityRange) { window.player.setPlaybackQualityRange('$code', '$code'); } if (window.player && window.player.setPlaybackQuality) { window.player.setPlaybackQuality('$code'); }",
      );
    } catch (_) {}
  }

  void _showQualitySheet(BuildContext context) {
    final qualities = widget.controller.availableQualities;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const ListTile(
              title: Text('Quality', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final q in qualities)
              ListTile(
                title: Text(q == 'Auto' ? 'Auto (recommended)' : q),
                trailing: widget.controller.selectedQuality == q
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  _applyPlayerQuality(q);
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
                  widget.controller.startDownload(video, q);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading "${video.title}" ($q)...')),
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
                        'Comments (${video.totalCommentsCount ?? video.comments.length})',
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
                              itemCount: video.comments.length +
                                  (widget.controller.hasMoreComments ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (_, index) {
                                if (index >= video.comments.length) {
                                  return Center(
                                    child: widget.controller.isLoadingMoreComments
                                        ? const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: CircularProgressIndicator(),
                                          )
                                        : OutlinedButton(
                                            onPressed:
                                                widget.controller.loadMoreComments,
                                            child: const Text('Show more comments'),
                                          ),
                                  );
                                }
                                final c = video.comments[index];
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _CommentAvatar(
                                      author: c.author,
                                      avatarUrl: c.avatarUrl,
                                      radius: 16,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${c.author} • ${c.publishedAgo}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(c.text),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.thumb_up_outlined,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                c.likes,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall,
                                              ),
                                              if (c.replyCount > 0) ...[
                                                const SizedBox(width: 16),
                                                Text(
                                                  '${c.replyCount} replies',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
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
        final player = widget.controller.youtubeController;

        return Scaffold(
          backgroundColor: _isInPipMode ? Colors.black : null,
          body: SafeArea(
            top: !_isInPipMode,
            bottom: !_isInPipMode,
            child: Column(
              mainAxisAlignment: _isInPipMode
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onVerticalDragEnd: _isInPipMode
                      ? null
                      : (details) {
                          if ((details.primaryVelocity ?? 0) > 350) {
                            widget.controller.minimizeWatch();
                          }
                        },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isInPipMode)
                        Container(
                          color: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          height: 40,
                          child: Row(
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                color: Colors.white,
                                onPressed: widget.controller.minimizeWatch,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                                tooltip: 'Minimize',
                              ),
                              if (widget.controller.sponsorBlockEnabled &&
                                  video.hasSponsorBlock)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'SponsorBlock',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => _showQualitySheet(context),
                                child: Text(widget.controller.selectedQuality),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => _showSpeedSheet(context),
                                child: Text('${widget.controller.playbackSpeed}x'),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                color: _isLoopEnabled
                                    ? scheme.primary
                                    : Colors.white,
                                onPressed: () {
                                  setState(
                                    () => _isLoopEnabled = !_isLoopEnabled,
                                  );
                                },
                                icon: Icon(
                                  _isLoopEnabled
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  size: 20,
                                ),
                                tooltip: 'Loop video',
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                color: Colors.white,
                                onPressed: _enterPip,
                                icon: const Icon(
                                  Icons.picture_in_picture_alt_rounded,
                                  size: 20,
                                ),
                                tooltip: 'Picture-in-Picture',
                              ),
                            ],
                          ),
                        ),
                      if (player != null)
                        YoutubePlayer(
                          key: _playerKey,
                          controller: player,
                        )
                      else
                        const AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
                if (!_isInPipMode)
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
                                    if (widget.controller.isLoadingWatchDetails &&
                                        video.channel.subscriberCount ==
                                            'YouTube channel') ...[
                                      const SizedBox(height: 4),
                                      const SkeletonBox(width: 110, height: 11),
                                    ] else
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
                                      if (widget.controller.isLoadingWatchDetails &&
                                          video.totalCommentsCount == null &&
                                          video.comments.isEmpty)
                                        const SkeletonBox(width: 32, height: 12)
                                      else
                                        Text(
                                          video.totalCommentsCount ??
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
                                  if (widget.controller.isLoadingWatchDetails &&
                                      video.comments.isEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Row(
                                      children: [
                                        SkeletonBox(
                                          width: 24,
                                          height: 24,
                                          borderRadius: 12,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(child: SkeletonBox(height: 12)),
                                      ],
                                    ),
                                  ] else if (video.comments.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _CommentAvatar(
                                          author: video.comments.first.author,
                                          avatarUrl:
                                              video.comments.first.avatarUrl,
                                          radius: 12,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            video.comments.first.text,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
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
                                  if (widget.controller.isLoadingWatchDetails &&
                                      video.description.isEmpty) ...[
                                    const SkeletonBox(height: 12),
                                    const SizedBox(height: 6),
                                    const SkeletonBox(width: 220, height: 12),
                                  ] else
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
                                          widget.controller.youtubeController
                                              ?.seekTo(
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

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    required this.author,
    required this.avatarUrl,
    required this.radius,
  });

  final String author;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cleaned = author.replaceAll('@', '').trim();
    final initial = cleaned.isNotEmpty ? cleaned[0].toUpperCase() : 'U';
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final url = avatarUrl;
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
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
