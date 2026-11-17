import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/channel_avatar.dart';
import 'package:zenplay/shared/widgets/option_picker_sheet.dart';
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
  bool _isInPipMode = false;
  bool _isFullscreen = false;
  bool _showOverlay = true;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    _pipChannel.setMethodCallHandler(_handlePipCall);
    widget.controller.addListener(_syncNativePip);
    _syncNativePip();
    _scheduleOverlayHide();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _setNativePipEnabled(false);
    _pipChannel.setMethodCallHandler(null);
    widget.controller.removeListener(_syncNativePip);
    if (_isFullscreen) {
      _exitFullscreenSystemUi();
    }
    super.dispose();
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showOverlay && widget.controller.isPlaying) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) _scheduleOverlayHide();
  }

  Future<dynamic> _handlePipCall(MethodCall call) async {
    if (call.method == 'onPipChanged' && mounted) {
      final inPip = call.arguments == true;
      setState(() => _isInPipMode = inPip);
      if (inPip && widget.controller.isPlaying) {
        widget.controller.videoController?.play();
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

  void _syncNativePip() {
    _setNativePipEnabled(widget.controller.backgroundPlayEnabled);
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _exitFullscreenSystemUi();
    }
  }

  Future<void> _exitFullscreenSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showPlayerOptionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const ListTile(
                title: Text(
                  'Playback options',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.high_quality_outlined),
                title: const Text('Resolution'),
                trailing: Text(widget.controller.activeQualityLabel),
                onTap: () {
                  Navigator.pop(context);
                  _showQualitySheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.speed_outlined),
                title: const Text('Playback speed'),
                trailing: Text('${widget.controller.playbackSpeed}x'),
                onTap: () {
                  Navigator.pop(context);
                  _showSpeedSheet(context);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.repeat_rounded),
                title: const Text('Loop video'),
                value: widget.controller.isLooping,
                onChanged: widget.controller.setLooping,
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Sleep timer'),
                trailing: Text(
                  widget.controller.sleepTimerMinutes != null
                      ? '${widget.controller.sleepTimerMinutes} min'
                      : 'Off',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSleepTimerSheet(context);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      widget.controller.isMuted || widget.controller.volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                    const SizedBox(width: 12),
                    const Text('Sound'),
                    Expanded(
                      child: Slider(
                        value: widget.controller.isMuted
                            ? 0
                            : widget.controller.volume.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label:
                            '${widget.controller.isMuted ? 0 : widget.controller.volume}%',
                        onChanged: (v) =>
                            widget.controller.setVolumeLevel(v.round()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepTimerSheet(BuildContext context) {
    showOptionPickerSheet<int?>(
      context: context,
      title: 'Sleep timer',
      options: const <int?>[null, 15, 30, 60],
      selected: widget.controller.sleepTimerMinutes,
      labelBuilder: (mins) => mins == null ? 'Off' : '$mins minutes',
      onSelected: widget.controller.setSleepTimer,
    );
  }

  void _showQualitySheet(BuildContext context) {
    showOptionPickerSheet<String>(
      context: context,
      title: 'Quality',
      options: widget.controller.availableQualities,
      selected: widget.controller.effectiveQuality,
      labelBuilder: (q) => q == 'Auto' ? 'Auto (recommended)' : q,
      onSelected: widget.controller.setQuality,
    );
  }

  void _showDownloadSheet(BuildContext context, VideoItem video) {
    if (widget.controller.isDownloaded(video.id)) {
      final quality = widget.controller.downloadedQualityFor(video.id) ?? '';
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download_done_rounded),
                title: const Text(
                  'Downloaded',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  quality.isEmpty ? 'Saved locally' : 'Saved locally • $quality',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove download'),
                onTap: () {
                  widget.controller.removeDownload(video.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Removed from downloads')),
                  );
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

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
    showOptionPickerSheet<double>(
      context: context,
      title: 'Playback speed',
      options: const [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
      selected: widget.controller.playbackSpeed,
      labelBuilder: (s) => '${s}x',
      onSelected: widget.controller.setPlaybackSpeed,
    );
  }

  void _showDescriptionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) => ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final video = widget.controller.activeVideo;
            if (video == null) return const SizedBox.shrink();
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        video.title,
                        style: theme.textTheme.titleSmall?.copyWith(
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
                      const SizedBox(height: 14),
                      if (widget.controller.isLoadingWatchDetails &&
                          video.description.isEmpty) ...[
                        const SkeletonBox(height: 12),
                        const SizedBox(height: 8),
                        const SkeletonBox(height: 12),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 200, height: 12),
                      ] else
                        Text(
                          video.description.isEmpty
                              ? 'No description provided.'
                              : video.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (video.chapters.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Chapters',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                              widget.controller.seekToSeconds(chapter.seconds);
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
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
                                final repliesExpanded =
                                    widget.controller.isRepliesExpanded(c.id);
                                final repliesLoading =
                                    widget.controller.isLoadingReplies(c.id);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                    InkWell(
                                                      onTap: () => widget
                                                          .controller
                                                          .toggleCommentReplies(
                                                        c,
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 2,
                                                        ),
                                                        child: Text(
                                                          repliesExpanded
                                                              ? 'Hide replies'
                                                              : '${c.replyCount} replies',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .labelSmall
                                                                  ?.copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .primary,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (repliesExpanded) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        margin: const EdgeInsets.only(left: 15),
                                        padding: const EdgeInsets.only(left: 16),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outlineVariant,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: repliesLoading
                                            ? const Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SkeletonBox(
                                                    width: 120,
                                                    height: 10,
                                                  ),
                                                  SizedBox(height: 6),
                                                  SkeletonBox(height: 12),
                                                ],
                                              )
                                            : c.replies.isEmpty
                                                ? Text(
                                                    'No replies available.',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  )
                                                : Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      for (final r in c.replies)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                            bottom: 10,
                                                          ),
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              _CommentAvatar(
                                                                author:
                                                                    r.author,
                                                                avatarUrl:
                                                                    r.avatarUrl,
                                                                radius: 12,
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      '${r.author} • ${r.publishedAgo}',
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .labelSmall
                                                                          ?.copyWith(
                                                                            color:
                                                                                Theme.of(context).colorScheme.onSurfaceVariant,
                                                                          ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height: 2,
                                                                    ),
                                                                    _ReplyText(
                                                                      text: r
                                                                          .text,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                      ),
                                    ],
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
        final player = widget.controller.videoController;
        final hideBelowPlayer = _isInPipMode || _isFullscreen;

        return Scaffold(
          backgroundColor: hideBelowPlayer ? Colors.black : null,
          body: SafeArea(
            top: !hideBelowPlayer,
            bottom: !hideBelowPlayer,
            child: Column(
              mainAxisAlignment: hideBelowPlayer
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onVerticalDragEnd: hideBelowPlayer
                      ? null
                      : (details) {
                          if ((details.primaryVelocity ?? 0) > 350) {
                            widget.controller.minimizeWatch();
                          }
                        },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NativePlayerSurface(
                        key: _playerKey,
                        video: video,
                        player: player,
                        isPlaying: widget.controller.isPlaying,
                        isMuted: widget.controller.isMuted,
                        isFullscreen: _isFullscreen,
                        playbackError: widget.controller.playbackError,
                        showSponsorBlock: widget.controller.sponsorBlockEnabled &&
                            video.hasSponsorBlock,
                        showOverlay: _showOverlay && !_isInPipMode,
                        progressListenable:
                            widget.controller.playbackProgressNotifier,
                        formatDuration: _formatDuration,
                        onTapSurface: _toggleOverlay,
                        onRetry: () => widget.controller.playVideo(video),
                        onMinimize: _isFullscreen
                            ? _toggleFullscreen
                            : widget.controller.minimizeWatch,
                        onTogglePlay: () {
                          widget.controller.togglePlayPause();
                          _scheduleOverlayHide();
                        },
                        onToggleMute: widget.controller.toggleMute,
                        onEnterPip: _enterPip,
                        onToggleFullscreen: _toggleFullscreen,
                        onOpenSettings: () => _showPlayerOptionsSheet(context),
                        onDoubleTapLeft: () =>
                            widget.controller.seekBySeconds(-10),
                        onDoubleTapRight: () =>
                            widget.controller.seekBySeconds(10),
                        onSeek: widget.controller.seekTo,
                      ),
                    ],
                  ),
                ),
                if (!hideBelowPlayer)
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showDescriptionSheet(context),
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${video.viewsText} • ${video.publishedAgo}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '...more',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              video.channel.name,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (widget.controller.isLoadingWatchDetails &&
                                                video.channel.subscriberCount ==
                                                    'YouTube channel') ...[
                                              const SizedBox(height: 4),
                                              const SkeletonBox(
                                                  width: 110, height: 11),
                                            ] else
                                              Text(
                                                video.channel.subscriberCount,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
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
                                height: 36,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  children: [
                                    _LikeDislikePill(
                                      likesCount: video.likesCount,
                                      dislikesCount:
                                          widget.controller.returnDislikeEnabled
                                              ? video.dislikesCount
                                              : null,
                                      isLiked:
                                          widget.controller.isLiked(video.id),
                                      isDisliked:
                                          widget.controller.isDisliked(video.id),
                                      onLikeTap: () =>
                                          widget.controller.toggleLike(video.id),
                                      onDislikeTap: () => widget.controller
                                          .toggleDislike(video.id),
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
                                      isActive:
                                          widget.controller.isDownloaded(video.id),
                                      onTap: () =>
                                          _showDownloadSheet(context, video),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Comments',
                                                style: theme.textTheme.labelLarge
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (widget.controller
                                                      .isLoadingWatchDetails &&
                                                  video.totalCommentsCount ==
                                                      null &&
                                                  video.comments.isEmpty)
                                                const SkeletonBox(
                                                    width: 32, height: 12)
                                              else
                                                Text(
                                                  video.totalCommentsCount ??
                                                      '${video.comments.length}',
                                                  style: theme.textTheme.bodySmall
                                                      ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
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
                                          if (widget.controller
                                                  .isLoadingWatchDetails &&
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
                                                Expanded(
                                                    child:
                                                        SkeletonBox(height: 12)),
                                              ],
                                            ),
                                          ] else if (video.comments.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                _CommentAvatar(
                                                  author:
                                                      video.comments.first.author,
                                                  avatarUrl: video
                                                      .comments.first.avatarUrl,
                                                  radius: 12,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    video.comments.first.text,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        theme.textTheme.bodySmall,
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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                                child: Text(
                                  'Up next',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 24),
                          sliver: SliverList.builder(
                            itemCount: upNext.length,
                            itemBuilder: (_, index) {
                              final next = upNext[index];
                              return VideoCard(
                                video: next,
                                isSaved: widget.controller.isSaved(next.id),
                                isDownloaded:
                                    widget.controller.isDownloaded(next.id),
                                showDeArrowBadge:
                                    widget.controller.deArrowEnabled,
                                showSponsorBlockBadge:
                                    widget.controller.sponsorBlockEnabled,
                                onTap: () => widget.controller.playVideo(next),
                                onPrefetch: () =>
                                    widget.controller.prefetchVideo(next.id),
                                onChannelTap: () =>
                                    widget.onOpenChannel(next.channel),
                                onSaveTap: () => showSaveToFolderSheet(
                                  context,
                                  widget.controller,
                                  next.id,
                                ),
                                onDownloadTap: () =>
                                    widget.controller.toggleDownload(next.id),
                              );
                            },
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

class _NativePlayerSurface extends StatelessWidget {
  const _NativePlayerSurface({
    super.key,
    required this.video,
    required this.player,
    required this.isPlaying,
    required this.isMuted,
    required this.isFullscreen,
    required this.playbackError,
    required this.showSponsorBlock,
    required this.showOverlay,
    required this.progressListenable,
    required this.formatDuration,
    required this.onTapSurface,
    required this.onRetry,
    required this.onMinimize,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onEnterPip,
    required this.onToggleFullscreen,
    required this.onOpenSettings,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    required this.onSeek,
  });

  final VideoItem video;
  final VideoPlayerController? player;
  final bool isPlaying;
  final bool isMuted;
  final bool isFullscreen;
  final String? playbackError;
  final bool showSponsorBlock;
  final bool showOverlay;
  final ValueNotifier<double> progressListenable;
  final String Function(Duration) formatDuration;
  final VoidCallback onTapSurface;
  final VoidCallback onRetry;
  final VoidCallback onMinimize;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onEnterPip;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onOpenSettings;
  final VoidCallback onDoubleTapLeft;
  final VoidCallback onDoubleTapRight;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final isReady = player != null && player!.value.isInitialized;
    final thumbUrl = video.thumbnailUrl;

    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isReady)
                Center(
                  child: AspectRatio(
                    aspectRatio: player!.value.aspectRatio > 0
                        ? player!.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(player!),
                  ),
                )
              else if (thumbUrl != null && thumbUrl.isNotEmpty)
                Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: onTapSurface,
                      onDoubleTap: onDoubleTapLeft,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: onTapSurface,
                      onDoubleTap: onDoubleTapRight,
                    ),
                  ),
                ],
              ),
              if (!isReady)
                Center(
                  child: playbackError != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                playbackError!,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: onRetry,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
                )
              else if (showOverlay) ...[
                Container(color: Colors.black26),
                Positioned(
                  top: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        onPressed: onMinimize,
                        icon: Icon(
                          isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        ),
                        tooltip: isFullscreen ? 'Exit fullscreen' : 'Minimize',
                      ),
                      if (showSponsorBlock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'SponsorBlock',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        color: Colors.white,
                        onPressed: onEnterPip,
                        icon: const Icon(
                          Icons.picture_in_picture_alt_rounded,
                          size: 20,
                        ),
                        tooltip: 'Picture-in-Picture',
                      ),
                      IconButton(
                        color: Colors.white,
                        onPressed: onOpenSettings,
                        icon: const Icon(
                          Icons.settings_outlined,
                          size: 20,
                        ),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
                Center(
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: onTogglePlay,
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 36,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 4,
                  bottom: 2,
                  child: ValueListenableBuilder<double>(
                    valueListenable: progressListenable,
                    builder: (_, progress, __) {
                      final total = player!.value.duration;
                      final current = Duration(
                        milliseconds: (total.inMilliseconds * progress).round(),
                      );
                      return Row(
                        children: [
                          Text(
                            formatDuration(current),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: progress.clamp(0.0, 1.0),
                              onChanged: onSeek,
                            ),
                          ),
                          Text(
                            video.isLive ? 'LIVE' : formatDuration(total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          IconButton(
                            color: Colors.white,
                            onPressed: onToggleMute,
                            icon: Icon(
                              isMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            color: Colors.white,
                            onPressed: onToggleFullscreen,
                            icon: Icon(
                              isFullscreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              size: 22,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyText extends StatelessWidget {
  const _ReplyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('@')) {
      return Text(text, style: style);
    }

    final splitIndex = trimmed.indexOf(RegExp(r'\s'));
    if (splitIndex <= 1) {
      return Text(text, style: style);
    }

    final mention = trimmed.substring(0, splitIndex);
    final rest = trimmed.substring(splitIndex);

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: mention,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: rest),
        ],
      ),
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
        cacheWidth: 120,
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
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            onTap: onLikeTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                    size: 16,
                    color: isLiked ? scheme.primary : scheme.onSurface,
                  ),
                  const SizedBox(width: 5),
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
            height: 16,
            color: scheme.outlineVariant,
          ),
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
            onTap: onDislikeTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                    size: 16,
                    color: isDisliked ? scheme.primary : scheme.onSurface,
                  ),
                  if (dislikesCount != null) ...[
                    const SizedBox(width: 5),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
