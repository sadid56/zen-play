import 'package:material_ui/material_ui.dart';

Future<void> showOptionPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required T selected,
  required String Function(T) labelBuilder,
  required ValueChanged<T> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final option in options)
            ListTile(
              title: Text(labelBuilder(option)),
              trailing:
                  option == selected ? const Icon(Icons.check_rounded) : null,
              onTap: () {
                onSelected(option);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    ),
  );
}
