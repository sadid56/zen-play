import 'package:material_ui/material_ui.dart';
import 'package:zenplay/core/models/tv_channel.dart';
import 'package:zenplay/core/services/tv_service.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/shared/widgets/empty_state_view.dart';
import 'package:zenplay/shared/widgets/filter_chip_bar.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({
    super.key,
    required this.controller,
  });

  final ZenPlayController controller;

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.tvChannels.isEmpty && !widget.controller.isLoadingTv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.loadTvChannels();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final channels = widget.controller.tvChannels;
        final activeId = widget.controller.activeVideo?.id;

        return Column(
          children: [
            FilterChipBar(
              items: TvService.categories,
              selected: widget.controller.selectedTvCategory,
              onSelected: widget.controller.setTvCategory,
            ),
            Expanded(
              child: widget.controller.isLoadingTv
                  ? const _TvLoadingGrid()
                  : channels.isEmpty
                      ? EmptyStateView(
                          icon: Icons.live_tv_outlined,
                          title: 'No live TV channels available',
                          subtitle:
                              'Pull down or tap retry to load live TV channels.',
                          action: FilledButton.icon(
                            onPressed: () => widget.controller
                                .loadTvChannels(forceRefresh: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => widget.controller
                              .loadTvChannels(forceRefresh: true),
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 210,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.96,
                            ),
                            itemCount: channels.length,
                            itemBuilder: (_, index) {
                              final channel = channels[index];
                              final isPlaying = activeId == 'tv_${channel.id}';
                              return _TvChannelCard(
                                channel: channel,
                                isPlaying: isPlaying,
                                onTap: () =>
                                    widget.controller.playTvChannel(channel),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _TvChannelCard extends StatelessWidget {
  const _TvChannelCard({
    required this.channel,
    required this.isPlaying,
    required this.onTap,
  });

  final TvChannel channel;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: isPlaying ? 3 : 0,
      color: isPlaying
          ? scheme.primaryContainer.withValues(alpha: 0.45)
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isPlaying
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: isPlaying ? 1.8 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPlaying)
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: channel.logoUrl != null
                        ? Image.network(
                            channel.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.live_tv_rounded,
                              size: 32,
                              color: scheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.live_tv_rounded,
                            size: 32,
                            color: scheme.primary,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  channel.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvLoadingGrid extends StatelessWidget {
  const _TvLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.96,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
