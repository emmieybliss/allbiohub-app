import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shimmering placeholder shapes shown while content loads. One animation
/// drives every [SkeletonBox] below a [Skeleton].
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
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
    final brand = context.brand;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: reduceMotion
            ? widget.child
            : AnimatedBuilder(
                animation: _controller,
                child: widget.child,
                builder: (context, child) => ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      brand.skeleton,
                      brand.skeletonHighlight,
                      brand.skeleton,
                    ],
                    stops: const [0.35, 0.5, 0.65],
                    begin: Alignment(-1.0 + _controller.value * 3 - 1, -0.2),
                    end: Alignment(1.0 + _controller.value * 3 - 1, 0.2),
                  ).createShader(bounds),
                  child: child,
                ),
              ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.brand.skeleton,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Skeleton matching [ArticleListTile].
class ArticleTileSkeleton extends StatelessWidget {
  const ArticleTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 80, height: 10),
              SizedBox(height: 10),
              SkeletonBox(height: 16),
              SizedBox(height: 6),
              SkeletonBox(width: 180, height: 16),
              SizedBox(height: 12),
              SkeletonBox(width: 90, height: 10),
            ],
          ),
        ),
        SizedBox(width: 16),
        SkeletonBox(width: 96, height: 96, radius: 12),
      ],
    ),
  );
}

class ArticleListSkeleton extends StatelessWidget {
  const ArticleListSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Column(
      children: [for (var i = 0; i < count; i++) const ArticleTileSkeleton()],
    ),
  );
}

/// Skeleton for the Home screen's first paint.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Skeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SkeletonBox(height: 380, radius: 22),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SkeletonBox(width: 140, height: 18),
        ),
        SizedBox(height: 8),
        ArticleTileSkeleton(),
        ArticleTileSkeleton(),
        ArticleTileSkeleton(),
      ],
    ),
  );
}
