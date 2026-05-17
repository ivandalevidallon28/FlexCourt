import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Branded "FlexCourt" title — two-tone wordmark aligned with the logo palette.
class FlexCourtWordmark extends StatelessWidget {
  const FlexCourtWordmark({
    super.key,
    this.variant = FlexCourtWordmarkVariant.hero,
  });

  final FlexCourtWordmarkVariant variant;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (variant) {
      case FlexCourtWordmarkVariant.appBar:
        return const _AppBarWordmark();
      case FlexCourtWordmarkVariant.hero:
        return _HeroWordmark(isDark: isDark);
    }
  }
}

enum FlexCourtWordmarkVariant { hero, appBar }

class _HeroWordmark extends StatelessWidget {
  const _HeroWordmark({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final flexColor = isDark ? AppColors.iceWhite : AppColors.midnightNavy;
    final courtColor = isDark ? AppColors.skyBlue : AppColors.electricBlue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Flex',
                style: _heroStyle.copyWith(color: flexColor),
              ),
              TextSpan(
                text: 'Court',
                style: _heroStyle.copyWith(
                  color: courtColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Book your court',
          style: AppTypography.bodySmall.copyWith(
            color: isDark
                ? AppColors.coolGray
                : AppColors.coolGray.withValues(alpha: 0.9),
            letterSpacing: 0.6,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static const _heroStyle = TextStyle(
    fontSize: 34,
    height: 1.05,
    letterSpacing: -0.8,
    fontWeight: FontWeight.w700,
  );
}

class _AppBarWordmark extends StatelessWidget {
  const _AppBarWordmark();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Flex',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              shadows: [
                Shadow(
                  color: AppColors.midnightNavy.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          TextSpan(
            text: 'Court',
            style: TextStyle(
              color: AppColors.skyBlue.withValues(alpha: 0.95),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              shadows: [
                Shadow(
                  color: AppColors.midnightNavy.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
