import 'package:flutter/material.dart';

/// CourtSide design system — spacing scale (4–8 base).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);

  static const SizedBox gapXsV = SizedBox(height: xs);
  static const SizedBox gapSmV = SizedBox(height: sm);
  static const SizedBox gapMdV = SizedBox(height: md);
  static const SizedBox gapLgV = SizedBox(height: lg);
  static const SizedBox gapXlV = SizedBox(height: xl);
  static const SizedBox gapXxlV = SizedBox(height: xxl);

  static const SizedBox gapXsH = SizedBox(width: xs);
  static const SizedBox gapSmH = SizedBox(width: sm);
  static const SizedBox gapMdH = SizedBox(width: md);
  static const SizedBox gapLgH = SizedBox(width: lg);
  static const SizedBox gapXlH = SizedBox(width: xl);

  /// Horizontal padding for screen content (narrow vs wide).
  static double screenPaddingH(bool isNarrow) => isNarrow ? md : lg;
  /// Vertical padding for screen content.
  static const double screenPaddingV = md;
  /// Gap between list items (cards, tiles).
  static const double listItemGap = md;
}
