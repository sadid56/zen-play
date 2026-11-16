import 'package:flutter/material.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';

Future<void> showSaveToFolderSheet(
  BuildContext context,
  ZenPlayController controller,
  String videoId,
) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final folders = controller.folderNames;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text(
                    'Save to folder',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => _showNewFolderDialog(context, controller),
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('New folder'),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    itemBuilder: (_, index) {
                      final folder = folders[index];
                      final checked = controller.isSavedInFolder(folder, videoId);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(folder),
                        secondary: const Icon(Icons.folder_outlined),
                        onChanged: (_) =>
                            controller.toggleVideoInFolder(folder, videoId),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _showNewFolderDialog(
  BuildContext context,
  ZenPlayController controller,
) async {
  final textController = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        controller: textController,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Folder name'),
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
    controller.createFolder(name);
  }
}
