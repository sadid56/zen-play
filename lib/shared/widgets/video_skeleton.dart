import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final shine = Color.lerp(base, scheme.surface, 0.38)!;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
        builder: (_, child) {
          final slide = (_controller.value * 2.0) - 1.0;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(slide - 0.7, 0),
                end: Alignment(slide + 0.7, 0),
                colors: [base, shine, base],
                stops: const [0.15, 0.5, 0.85],
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonBox(height: double.infinity, borderRadius: 0),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 40, height: 40, borderRadius: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 14),
                        SizedBox(height: 8),
                        SkeletonBox(width: 180, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoFeedSkeleton extends StatelessWidget {
  const VideoFeedSkeleton({
    super.key,
    this.itemCount = 3,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, __) => const VideoCardSkeleton(),
    );
  }
}
