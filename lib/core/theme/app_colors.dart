import 'package:flutter/material.dart';

/// FlexCourt design system — color palette.
/// Blue (primary), Orange (secondary), Yellow (accent), Green (success).
class AppColors {
  AppColors._();

  // ─── Primary: Blue ───────────────────────────────────────────────────────
  static const Color blue50 = Color(0xFFE3F2FD);
  static const Color blue100 = Color(0xFFBBDEFB);
  static const Color blue200 = Color(0xFF90CAF9);
  static const Color blue300 = Color(0xFF64B5F6);
  static const Color blue400 = Color(0xFF42A5F5);
  static const Color blue500 = Color(0xFF2196F3);
  static const Color blue600 = Color(0xFF1E88E5);
  static const Color blue700 = Color(0xFF1976D2);
  static const Color blue800 = Color(0xFF1565C0);
  static const Color blue900 = Color(0xFF0D47A1);

  // ─── Secondary: Orange ────────────────────────────────────────────────────
  static const Color orange50 = Color(0xFFFFF3E0);
  static const Color orange100 = Color(0xFFFFE0B2);
  static const Color orange200 = Color(0xFFFFCC80);
  static const Color orange300 = Color(0xFFFFB74D);
  static const Color orange400 = Color(0xFFFFA726);
  static const Color orange500 = Color(0xFFFF9800);
  static const Color orange600 = Color(0xFFFB8C00);
  static const Color orange700 = Color(0xFFF57C00);
  static const Color orange800 = Color(0xFFEF6C00);
  static const Color orange900 = Color(0xFFE65100);

  // ─── Accent: Yellow (light use) ───────────────────────────────────────────
  static const Color yellow50 = Color(0xFFFFFDE7);
  static const Color yellow100 = Color(0xFFFFF9C4);
  static const Color yellow200 = Color(0xFFFFF59D);
  static const Color yellow300 = Color(0xFFFFF176);
  static const Color yellow400 = Color(0xFFFFEE58);
  static const Color yellow500 = Color(0xFFFFEB3B);
  static const Color yellow600 = Color(0xFFFDD835);
  static const Color yellow700 = Color(0xFFFBC02D);

  // ─── Success: Green ───────────────────────────────────────────────────────
  static const Color green50 = Color(0xFFE8F5E9);
  static const Color green100 = Color(0xFFC8E6C9);
  static const Color green200 = Color(0xFFA5D6A7);
  static const Color green300 = Color(0xFF81C784);
  static const Color green400 = Color(0xFF66BB6A);
  static const Color green500 = Color(0xFF4CAF50);
  static const Color green600 = Color(0xFF43A047);
  static const Color green700 = Color(0xFF388E3C);
  static const Color green800 = Color(0xFF2E7D32);
  static const Color green900 = Color(0xFF1B5E20);

  // ─── Neutrals ────────────────────────────────────────────────────────────
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFEEEEEE);
  static const Color neutral300 = Color(0xFFE0E0E0);
  static const Color neutral400 = Color(0xFFBDBDBD);
  static const Color neutral500 = Color(0xFF9E9E9E);
  static const Color neutral600 = Color(0xFF757575);
  static const Color neutral700 = Color(0xFF616161);
  static const Color neutral800 = Color(0xFF424242);
  static const Color neutral900 = Color(0xFF212121);

  // ─── Semantic (status) ────────────────────────────────────────────────────
  static const Color pending = yellow500;
  static const Color approved = green600;
  static const Color rejected = orange700;
  static const Color cancelled = neutral600;
  static const Color adminStatus = indigo500; // Admin-created reservations
  static const Color error = Color(0xFFD32F2F);

  // ─── Dark mode ────────────────────────────────────────────────────────────
  static const Color neutral100Dark = Color(0xFF2C2C2C);
  static const Color neutral200Dark = Color(0xFF383838);
  static const Color neutral800Dark = Color(0xFFE0E0E0);
  static const Color neutral900Dark = Color(0xFFF5F5F5);

  // ─── Tech / gradient accents ──────────────────────────────────────────────
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color cyan600 = Color(0xFF0891B2);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color violet500 = Color(0xFF8B5CF6);

  /// Primary gradient (light): blue → cyan
  static const LinearGradient primaryGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E88E5), Color(0xFF06B6D4)],
  );

  /// Primary gradient (dark): deep blue → cyan glow
  static const LinearGradient primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E7490), Color(0xFF06B6D4), Color(0xFF22D3EE)],
  );

  /// Surface gradient for hero (dark)
  static const LinearGradient surfaceGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  /// Status color for reservation: PENDING, APPROVED, REJECTED, CANCELLED, ADMIN.
  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return pending;
      case 'APPROVED':
        return approved;
      case 'REJECTED':
        return rejected;
      case 'CANCELLED':
        return cancelled;
      case 'ADMIN':
        return adminStatus;
      default:
        return neutral600;
    }
  }
}
