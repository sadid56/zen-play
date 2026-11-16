import 'package:flutter/material.dart';
import 'package:zenplay/core/models/channel_info.dart';
import 'package:zenplay/core/models/video_item.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/save_to_folder_sheet.dart';
import 'package:zenplay/shared/widgets/video_card.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({
    super.key,
    required this.controller,
    required this.onOpenVideo,
    required this.onOpenChannel,
  });

  final ZenPlayController controller;
  final ValueChanged<VideoItem> onOpenVideo;
  final ValueChanged<ChannelInfo> onOpenChannel;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String? _selectedFolder;

  Future<void> _createFolderDialog() async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create collection folder'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Favorites, Coding'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, textController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (name != null && name.trim().isNotEmpty) {
      widget.controller.createFolder(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final activeFolder = _selectedFolder;
        if (activeFolder != null) {
          final videos = widget.controller.videosInFolder(activeFolder);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _selectedFolder = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeFolder,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${videos.length} videos',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: videos.isEmpty
                    ? EmptyStateView(
                        icon: Icons.folder_open_rounded,
                        title: 'No videos in "$activeFolder"',
                        subtitle: 'Tap Save on any video to add it to this folder.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: videos.length,
                        itemBuilder: (_, index) {
                          final video = videos[index];
                          return VideoCard(
                            video: video,
                            isSaved: widget.controller.isSaved(video.id),
                            isDownloaded:
                                widget.controller.isDownloaded(video.id),
                            showDeArrowBadge: widget.controller.deArrowEnabled,
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
                          );
                        },
                      ),
              ),
            ],
          );
        }

        final folders = widget.controller.folderNames;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Collections',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _createFolderDialog,
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('New folder'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: folders.length,
                itemBuilder: (_, index) {
                  final folder = folders[index];
                  final count = widget.controller.countInFolder(folder);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        child: const Icon(Icons.folder_rounded),
                      ),
                      title: Text(
                        folder,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('$count ${count == 1 ? 'video' : 'videos'}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _selectedFolder = folder),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
