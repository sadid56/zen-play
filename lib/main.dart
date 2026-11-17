import 'package:material_ui/material_ui.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/core/theme/app_theme.dart';
import 'package:zenplay/features/shell/zenplay_shell.dart';

void main() {
  runApp(const ZenPlayApp());
}

class ZenPlayApp extends StatefulWidget {
  const ZenPlayApp({
    super.key,
    this.controller,
  });

  final ZenPlayController? controller;

  @override
  State<ZenPlayApp> createState() => _ZenPlayAppState();
}

class _ZenPlayAppState extends State<ZenPlayApp> {
  late final ZenPlayController _controller =
      widget.controller ?? ZenPlayController();
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'ZenPlay',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _controller.themeMode,
          home: ZenPlayShell(controller: _controller),
        );
      },
    );
  }
}
