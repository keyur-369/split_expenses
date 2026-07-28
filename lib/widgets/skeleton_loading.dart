import 'package:flutter/material.dart';

/// Animated Shimmer Gradient Wrapper
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE6ECF5),
    this.highlightColor = const Color(0xFFF5F8FC),
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_animation.value - 1, -0.3),
              end: Alignment(_animation.value + 1, 0.3),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Reusable rectangular skeleton block
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 12.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFFE6ECF5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Reusable circular skeleton block
class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: Color(0xFFE6ECF5),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton placeholder for Group List Cards
class GroupCardSkeleton extends StatelessWidget {
  const GroupCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEBF0F8), width: 1.2),
        ),
        child: Row(
          children: [
            const SkeletonCircle(size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 140, height: 16, borderRadius: 6),
                  SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 12, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SkeletonBox(width: 80, height: 28, borderRadius: 14),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder for Group Summary Header Card
class SummaryCardSkeleton extends StatelessWidget {
  const SummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEBF0F8), width: 1.2),
        ),
        child: Column(
          children: [
            const SkeletonBox(width: 120, height: 14, borderRadius: 6),
            const SizedBox(height: 12),
            const SkeletonBox(width: 160, height: 32, borderRadius: 8),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6ECF5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 70, height: 10, borderRadius: 4),
                        SizedBox(height: 8),
                        SkeletonBox(width: 90, height: 18, borderRadius: 6),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6ECF5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 70, height: 10, borderRadius: 4),
                        SizedBox(height: 8),
                        SkeletonBox(width: 90, height: 18, borderRadius: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder for Expense Items
class ExpenseTileSkeleton extends StatelessWidget {
  const ExpenseTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEBF0F8), width: 1.2),
        ),
        child: Row(
          children: [
            const SkeletonCircle(size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 130, height: 15, borderRadius: 6),
                  SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 12, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                SkeletonBox(width: 65, height: 16, borderRadius: 6),
                SizedBox(height: 6),
                SkeletonBox(width: 45, height: 10, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton view for whole Group List Page loading
class GroupListScreenSkeleton extends StatelessWidget {
  const GroupListScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const SummaryCardSkeleton(),
            const SizedBox(height: 8),
            SkeletonShimmer(
              child: Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6ECF5),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SkeletonShimmer(
              child: const SkeletonBox(width: 110, height: 14, borderRadius: 6, margin: EdgeInsets.only(left: 8, bottom: 12)),
            ),
            const GroupCardSkeleton(),
            const GroupCardSkeleton(),
            const GroupCardSkeleton(),
            const GroupCardSkeleton(),
          ],
        ),
      ),
    );
  }
}

/// Skeleton view for Group Detail Page loading
class GroupDetailScreenSkeleton extends StatelessWidget {
  const GroupDetailScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            SkeletonShimmer(
              child: Container(
                height: 160,
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEBF0F8), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 160, height: 22, borderRadius: 8),
                    SizedBox(height: 10),
                    SkeletonBox(width: 100, height: 14, borderRadius: 6),
                    Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonBox(width: 110, height: 36, borderRadius: 18),
                        SkeletonBox(width: 110, height: 36, borderRadius: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SkeletonShimmer(
              child: const SkeletonBox(width: 100, height: 14, borderRadius: 6, margin: EdgeInsets.only(left: 4, bottom: 12)),
            ),
            const ExpenseTileSkeleton(),
            const ExpenseTileSkeleton(),
            const ExpenseTileSkeleton(),
            const ExpenseTileSkeleton(),
          ],
        ),
      ),
    );
  }
}

/// Generic full-screen card/list skeleton loader
class GenericScreenSkeleton extends StatelessWidget {
  final int itemHeight;
  final int itemCount;

  const GenericScreenSkeleton({
    super.key,
    this.itemHeight = 70,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return SkeletonShimmer(
          child: Container(
            height: itemHeight.toDouble(),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEBF0F8), width: 1.2),
            ),
          ),
        );
      },
    );
  }
}
