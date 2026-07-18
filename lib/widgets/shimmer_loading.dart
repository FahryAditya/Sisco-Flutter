import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Kumpulan widget "skeleton" (placeholder berkilau) untuk keadaan loading,
/// menggantikan [CircularProgressIndicator] agar terasa lebih modern.
///
/// Bungkus satu atau beberapa [SkeletonBox] dengan [Shimmer]; atau pakai
/// preset siap-pakai seperti [SkeletonList] dan [SkeletonStatGrid].
class ShimmerLoading extends StatelessWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border.withAlpha(90),
      highlightColor: AppColors.background,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Satu blok abu-abu membulat sebagai bagian dari skeleton.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton untuk daftar berbasis [ListTile] (avatar + dua baris teks).
class SkeletonList extends StatelessWidget {
  final int items;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.items = 6,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, _) => Row(
          children: [
            const SkeletonBox(width: 48, height: 48, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 160, height: 13),
                  SizedBox(height: 8),
                  SkeletonBox(width: 100, height: 11),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const SkeletonBox(width: 32, height: 24),
          ],
        ),
      ),
    );
  }
}

/// Skeleton untuk grid kartu statistik (2 kolom, [rows] baris).
class SkeletonStatGrid extends StatelessWidget {
  final int rows;
  const SkeletonStatGrid({super.key, this.rows = 2});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(rows, (_) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: const [
                Expanded(child: SkeletonBox(height: 96, radius: 12)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 96, radius: 12)),
              ],
            ),
          );
        }),
      ),
    );
  }
}
