import 'package:flutter/material.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/features/channel/channel_screen.dart';
import 'package:zenplay/features/downloads/downloads_screen.dart';
import 'package:zenplay/features/history/history_screen.dart';
import 'package:zenplay/features/home/home_screen.dart';
import 'package:zenplay/features/search/search_screen.dart';
import 'package:zenplay/features/settings/settings_screen.dart';
import 'package:zenplay/features/watch/watch_screen.dart';
import 'package:zenplay/shared/widgets/mini_player_bar.dart';
import 'package:zenplay/shared/widgets/zenplay_logo.dart';

class ZenPlayShell extends StatefulWidget {
  const ZenPlayShell({
    super.key,
    required this.controller,
  });

  final ZenPlayController controller;

  @override
  State<ZenPlayShell> createState() => _ZenPlayShellState();
}

class _ZenPlayShellState extends State<ZenPlayShell> {
  late final PageController _pageController = PageController(
    initialPage: widget.controller.navIndex,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    widget.controller.setNavIndex(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _openWatch(BuildContext context, VideoItem video) {
    widget.controller.playVideo(video);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WatchScreen(
          controller: widget.controller,
          onOpenChannel: (channel) => _openChannel(context, channel),
        ),
      ),
    );
  }

  void _openActiveWatch(BuildContext context) {
    if (widget.controller.activeVideo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WatchScreen(
          controller: widget.controller,
          onOpenChannel: (channel) => _openChannel(context, channel),
        ),
      ),
    );
  }

  void _openChannel(BuildContext context, ChannelInfo channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChannelScreen(
          channel: channel,
          controller: widget.controller,
          onOpenVideo: (video) => _openWatch(context, video),
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(
          controller: widget.controller,
          onOpenVideo: (video) => _openWatch(context, video),
          onOpenChannel: (channel) => _openChannel(context, channel),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.isAppInitializing) {
          return const _AppOpeningSplash();
        }

        final activeVideo = widget.controller.activeVideo;

        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                ZenPlayLogo(size: 30),
                SizedBox(width: 10),
                Text('ZenPlay', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => _openSearch(context),
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search',
              ),
              IconButton(
                onPressed: () => _openSettings(context),
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: PageView(
            controller: _pageController,
            onPageChanged: widget.controller.setNavIndex,
            children: [
              HomeScreen(
                controller: widget.controller,
                onOpenVideo: (video) => _openWatch(context, video),
                onOpenChannel: (channel) => _openChannel(context, channel),
              ),
              HistoryScreen(
                controller: widget.controller,
                onOpenVideo: (video) => _openWatch(context, video),
                onOpenChannel: (channel) => _openChannel(context, channel),
              ),
              DownloadsScreen(
                controller: widget.controller,
                onOpenVideo: (video) => _openWatch(context, video),
                onOpenChannel: (channel) => _openChannel(context, channel),
              ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeVideo != null)
                MiniPlayerBar(
                  video: activeVideo,
                  isPlaying: widget.controller.isPlaying,
                  progress: widget.controller.playbackProgress,
                  onTap: () => _openActiveWatch(context),
                  onTogglePlay: widget.controller.togglePlayPause,
                  onClose: widget.controller.closeMiniPlayer,
                ),
              NavigationBar(
                selectedIndex: widget.controller.navIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.download_outlined),
                    selectedIcon: Icon(Icons.download_rounded),
                    label: 'Downloads',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppOpeningSplash extends StatelessWidget {
  const _AppOpeningSplash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZenPlayLogo(size: 72),
            const SizedBox(height: 16),
            Text(
              'ZenPlay',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
          ],
        ),
      ),
    );
  }
}
