import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Vertical bar showing reservation status color. Use as a card accent.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.status,
    this.width = 4,
    this.height = 48,
  });

  final String status;
  final double width;
  final double height;

  static Color colorFor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return AppColors.pending;
      case 'APPROVED':
        return AppColors.approved;
      case 'CANCELLED':
      case 'REJECTED':
        return AppColors.cancelled;
      default:
        return AppColors.neutral600;
    }
  }

  /// Compact colored pill — use where a text badge is clearer than a bar.
  static Widget badge(String status) {
    final color = colorFor(status);
    final label = status.isEmpty
        ? '—'
        : status[0].toUpperCase() + status.substring(1).toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorFor(status),
        borderRadius: AppRadius.radiusXs,
      ),
    );
  }
}