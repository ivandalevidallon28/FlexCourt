/// FlexCourt design system — single import for all tokens.
///
/// Brand palette: midnight navy → deep royal → strong / electric / sky blue,
/// ice white highlights, cool gray borders. See [AppColors] for named swatches.
///
/// Usage:
/// ```dart
/// import 'package:flexcourt/core/theme/app_design_system.dart';
///
/// // Colors
/// Container(color: AppColors.electricBlue);
/// Text('Status', style: TextStyle(color: AppColors.approved));
///
/// // Typography
/// Text('Title', style: AppTypography.headlineMedium);
///
/// // Spacing
/// Padding(padding: AppSpacing.paddingMd);
/// SizedBox(height: AppSpacing.lg);
///
/// // Radius
/// BorderRadius: AppRadius.radiusMd,
/// ```
library;

export 'app_colors.dart';
export 'app_typography.dart';
export 'app_spacing.dart';
export 'app_radius.dart';
