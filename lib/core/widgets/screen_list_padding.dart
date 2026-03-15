import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';
import '../theme/responsive.dart';
import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// reservation_list_card.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../theme/app_design_system.dart';
import 'glass_card.dart';

/// Reusable card row for a reservation: title, subtitle, optional leading/trailing.
class ScreenListPadding extends StatelessWidget {
  const ScreenListPadding({
    super.key,
    required this.child,
    this.horizontal,
    this.vertical,
  });

  final Widget child;
  final double? horizontal;
  final double? vertical;

  @override
  Widget build(BuildContext context) {
    final isNarrow = Responsive.isNarrow(context);
    final h = horizontal ?? AppSpacing.screenPaddingH(isNarrow);
    final v = vertical ?? AppSpacing.screenPaddingV;
    return Padding(
      padding: EdgeInsets.fromLTRB(h, v, h, 32),
      child: child,
    );
  }
}