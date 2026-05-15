import 'package:flutter/material.dart';

import 'shimmer_skeleton.dart';

/// Skeleton genérico para listas em loading state.
///
/// Substitui CircularProgressIndicator central pelo padrão "placeholder
/// estrutural antecipado" (web.dev — Skeleton screens), reduzindo CLS
/// percebido e mantendo consistência com Dashboard/Agenda.
class ListSkeleton extends StatelessWidget {
  final int items;
  final double itemHeight;
  final EdgeInsets padding;

  const ListSkeleton({
    super.key,
    this.items = 6,
    this.itemHeight = 64,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: items,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => ShimmerSkeleton(
        width: double.infinity,
        height: itemHeight,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Skeleton para telas de detalhe (header + corpo).
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ShimmerSkeleton(width: double.infinity, height: 80, borderRadius: BorderRadius.circular(14)),
        const SizedBox(height: 14),
        ShimmerSkeleton(width: double.infinity, height: 120, borderRadius: BorderRadius.circular(14)),
        const SizedBox(height: 14),
        ShimmerSkeleton(width: double.infinity, height: 200, borderRadius: BorderRadius.circular(14)),
      ],
    );
  }
}
