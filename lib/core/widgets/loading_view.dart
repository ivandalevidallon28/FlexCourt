import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// Centered loading indicator for async content. Use for consistent loading states.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.neutral500),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
