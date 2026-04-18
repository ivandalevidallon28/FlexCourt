import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';

class BallStatusChip extends StatelessWidget {
  const BallStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isAvailable = status == 'AVAILABLE';
    final bg = isAvailable
        ? AppColors.approved.withOpacity(0.15)
        : AppColors.orange700.withOpacity(0.15);
    final fg = isAvailable ? AppColors.approved : AppColors.orange700;
    final label = isAvailable ? 'Available' : 'In use';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
