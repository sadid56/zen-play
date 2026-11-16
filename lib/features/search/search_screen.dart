import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/video_card.dart';
import 'package:zenplay/shared/widgets/video_skeleton.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.onOpenVideo,
    required this.onOpenChannel,
  });

  final ZenPlayController controller;
  final ValueChanged<VideoItem> onOpenVideo;
  final ValueChanged<ChannelInfo> onOpenChannel;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      widget.controller.updateSearchSuggestions(value);
    });
  }

  Future<void> _runSearch(String query) async {
    _debounce?.cancel();
    _textController.text = query;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    FocusScope.of(context).unfocus();

    final directVideo = await widget.controller.openVideoUrlIfValid(query);
    if (directVideo != null && mounted) {
      widget.onOpenVideo(directVideo);
      return;
    }

    widget.controller.performSearch(query);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final query = _textController.text;
        final suggestions = widget.controller.searchSuggestions;
        final results = widget.controller.searchVideos(query);
        final showResults = widget.controller.hasActiveSearch;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: TextField(
              controller: _textController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search YouTube...',
                border: InputBorder.none,
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _textController.clear();
                          widget.controller.performSearch('');
                          setState(() {});
                        },
                      ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: _runSearch,
            ),
          ),
          body: widget.controller.isLoadingSearch
              ? const VideoFeedSkeleton()
              : query.trim().isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            'Recent searches',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        for (final item in widget.controller.recentSearches)
                          ListTile(
                            leading: const Icon(Icons.history_rounded),
                            title: Text(item),
                            trailing: IconButton(
                              icon: const Icon(Icons.north_west_rounded, size: 18),
                              onPressed: () {
                                _textController.text = item;
                                _onQueryChanged(item);
                              },
                            ),
                            onTap: () => _runSearch(item),
                          ),
                      ],
                    )
                  : !showResults
                      ? ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: suggestions.length,
                          itemBuilder: (_, index) {
                            final item = suggestions[index];
                            return ListTile(
                              leading: const Icon(Icons.search_rounded),
                              title: Text(item),
                              trailing: IconButton(
                                icon: const Icon(Icons.north_west_rounded, size: 18),
                                onPressed: () {
                                  _textController.text = item;
                                  _onQueryChanged(item);
                                },
                              ),
                              onTap: () => _runSearch(item),
                            );
                          },
                        )
                      : results.isEmpty
                          ? const EmptyStateView(
                              icon: Icons.search_off_rounded,
                              title: 'No matching videos',
                              subtitle: 'Try a different keyword.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: results.length,
                              itemBuilder: (_, index) {
                                final video = results[index];
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
                                  onSaveTap: () =>
                                      widget.controller.toggleWatchLater(video.id),
                                  onDownloadTap: () =>
                                      widget.controller.toggleDownload(video.id),
                                );
                              },
                            ),
        );
      },
    );
  }
}
