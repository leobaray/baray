import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerHigh,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}