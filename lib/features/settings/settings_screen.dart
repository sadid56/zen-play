import 'package:flutter/material.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/zenplay_logo.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
  });

  final ZenPlayController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _filter = '';

  bool _matches(String title, String subtitle) {
    if (_filter.trim().isEmpty) return true;
    final q = _filter.trim().toLowerCase();
    return title.toLowerCase().contains(q) || subtitle.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SearchBar(
                  hintText: 'Search settings',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ),
              if (_matches('Theme', 'System, Light, Dark')) ...[
                const _SectionLabel('Appearance'),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme'),
                  subtitle: Text(_themeLabel(c.themeMode)),
                  onTap: () => _pickTheme(context, c),
                ),
              ],
              if (_matches('Picture-in-Picture', 'Continue playing when leaving app') ||
                  _matches('Default resolution', c.selectedQuality) ||
                  _matches('Default playback speed', '${c.playbackSpeed}x')) ...[
                const _SectionLabel('Playback'),
                if (_matches('Picture-in-Picture', 'Continue playing when leaving app'))
                  SwitchListTile(
                    secondary: const Icon(Icons.picture_in_picture_alt_outlined),
                    title: const Text('Picture-in-Picture'),
                    subtitle: const Text('Continue playing when leaving app'),
                    value: c.backgroundPlayEnabled,
                    onChanged: c.setBackgroundPlay,
                  ),
                if (_matches('Default resolution', c.selectedQuality))
                  ListTile(
                    leading: const Icon(Icons.high_quality_outlined),
                    title: const Text('Default resolution'),
                    subtitle: Text(
                      c.selectedQuality == 'Auto'
                          ? 'Auto (network adaptive)'
                          : c.selectedQuality,
                    ),
                    onTap: () => _pickQuality(context, c),
                  ),
                if (_matches('Default playback speed', '${c.playbackSpeed}x'))
                  ListTile(
                    leading: const Icon(Icons.speed_outlined),
                    title: const Text('Default playback speed'),
                    subtitle: Text('${c.playbackSpeed}x'),
                    onTap: () => _pickSpeed(context, c),
                  ),
              ],
              if (_matches('SponsorBlock', 'Skip sponsor segments') ||
                  _matches('Return YouTube Dislike', 'Show estimated dislike counts')) ...[
                const _SectionLabel('Enhancements'),
                if (_matches('SponsorBlock', 'Skip sponsor segments'))
                  SwitchListTile(
                    secondary: const Icon(Icons.fast_forward_outlined),
                    title: const Text('SponsorBlock'),
                    subtitle: const Text('Automatically skip sponsor segments'),
                    value: c.sponsorBlockEnabled,
                    onChanged: c.setSponsorBlock,
                  ),
                if (_matches('Return YouTube Dislike', 'Show estimated dislike counts'))
                  SwitchListTile(
                    secondary: const Icon(Icons.thumb_down_outlined),
                    title: const Text('Return YouTube Dislike'),
                    subtitle: const Text('Show estimated dislike counts'),
                    value: c.returnDislikeEnabled,
                    onChanged: c.setReturnDislike,
                  ),
              ],
              if (_matches('Clear watch history', 'recent videos') ||
                  _matches('Clear search history', 'saved queries') ||
                  _matches('Clear downloads', 'offline videos')) ...[
                const _SectionLabel('Storage & History'),
                if (_matches('Clear watch history', 'recent videos'))
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Clear watch history'),
                    subtitle: Text('${c.historyVideos.length} recent videos'),
                    onTap: c.historyVideos.isEmpty
                        ? null
                        : () {
                            c.clearHistory();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Watch history cleared')),
                            );
                          },
                  ),
                if (_matches('Clear search history', 'saved queries'))
                  ListTile(
                    leading: const Icon(Icons.search_off_outlined),
                    title: const Text('Clear search history'),
                    subtitle: Text('${c.recentSearches.length} saved queries'),
                    onTap: c.recentSearches.isEmpty
                        ? null
                        : () {
                            c.clearSearchHistory();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Search history cleared')),
                            );
                          },
                  ),
                if (_matches('Clear downloads', 'offline videos'))
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Clear downloads'),
                    subtitle: Text('${c.downloadedVideos.length} offline videos'),
                    onTap: c.downloadedVideos.isEmpty
                        ? null
                        : () {
                            c.clearDownloads();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Downloads cleared')),
                            );
                          },
                  ),
              ],
              if (_matches('ZenPlay', 'Android & iOS')) ...[
                const _SectionLabel('About'),
                const ListTile(
                  leading: ZenPlayLogo(size: 36),
                  title: Text('ZenPlay'),
                  subtitle: Text('Material 3 client for Android & iOS • v1.0.0'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Follow system',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  void _pickTheme(BuildContext context, ZenPlayController c) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Choose theme', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_themeLabel(mode)),
                trailing: c.themeMode == mode ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  c.setThemeMode(mode);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _pickQuality(BuildContext context, ZenPlayController c) {
    const qualities = ['Auto', '2160p', '1440p', '1080p', '720p', '480p', '360p'];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Default resolution', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final q in qualities)
              ListTile(
                title: Text(q == 'Auto' ? 'Auto (network adaptive)' : q),
                trailing: c.selectedQuality == q ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  c.setQuality(q);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _pickSpeed(BuildContext context, ZenPlayController c) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Default playback speed', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final s in speeds)
              ListTile(
                title: Text('${s}x'),
                trailing: c.playbackSpeed == s ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  c.setPlaybackSpeed(s);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
