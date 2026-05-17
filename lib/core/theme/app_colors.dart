import 'package:flutter/material.dart';

/// FlexCourt palette — aligned with the FlexCourt logo badge.
class AppColors {
  AppColors._();

  // ─── Brand (logo) ─────────────────────────────────────────────────────────
  static const Color midnightNavy = Color(0xFF001F50);
  static const Color deepRoyal = Color(0xFF002D7A);
  static const Color strongBlue = Color(0xFF1050B0);
  static const Color electricBlue = Color(0xFF3A86E8);
  static const Color skyBlue = Color(0xFF60A8F0);
  static const Color iceWhite = Color(0xFFE6F2FC);
  static const Color coolGray = Color(0xFF708090);

  // ─── Primary scale (maps to logo tones for existing `blue*` usages) ───────
  static const Color blue50 = iceWhite;
  static const Color blue100 = Color(0xFFD4E8F8);
  static const Color blue200 = Color(0xFFA8D0F4);
  static const Color blue300 = skyBlue;
  static const Color blue400 = skyBlue;
  static const Color blue500 = electricBlue;
  static const Color blue600 = strongBlue;
  static const Color blue700 = deepRoyal;
  static const Color blue800 = deepRoyal;
  static const Color blue900 = midnightNavy;

  // ─── Accent highlights (dark UI — formerly cyan) ─────────────────────────
  static const Color cyan400 = skyBlue;
  static const Color cyan500 = electricBlue;
  static const Color cyan600 = strongBlue;

  // ─── Secondary: Orange (reservation / admin accents) ───────────────────
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

  // ─── Accent: Yellow (pending status) ─────────────────────────────────────
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

  // ─── Neutrals (cool gray anchor from logo ring) ───────────────────────────
  static const Color neutral100 = Color(0xFFF4F7FA);
  static const Color neutral200 = Color(0xFFE8EDF2);
  static const Color neutral300 = Color(0xFFD0D8E0);
  static const Color neutral400 = Color(0xFF9AA8B4);
  static const Color neutral500 = coolGray;
  static const Color neutral600 = Color(0xFF5A6A78);
  static const Color neutral700 = Color(0xFF3D4A56);
  static const Color neutral800 = Color(0xFF243040);
  static const Color neutral900 = Color(0xFF121A24);

  // ─── Semantic (status) ──────────────────────────────────────────────────
  static const Color pending = yellow500;
  static const Color approved = green600;
  static const Color rejected = orange700;
  static const Color cancelled = neutral600;
  static const Color adminStatus = strongBlue;
  static const Color error = Color(0xFFD32F2F);

  // ─── Dark mode surfaces ───────────────────────────────────────────────────
  static const Color neutral100Dark = Color(0xFF002D7A);
  static const Color neutral200Dark = Color(0xFF003A8C);
  static const Color neutral800Dark = iceWhite;
  static const Color neutral900Dark = Color(0xFFFFFFFF);
  static const Color surfaceCardDark = deepRoyal;

  // ─── Legacy accent ────────────────────────────────────────────────────────
  static const Color indigo500 = strongBlue;
  static const Color violet500 = electricBlue;

  /// App bar & primary actions (light + dark).
  static const LinearGradient primaryGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepRoyal, strongBlue, electricBlue],
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnightNavy, deepRoyal, strongBlue],
  );

  /// Full-screen background (light) — ice wash from the logo rim.
  static const LinearGradient surfaceGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [iceWhite, Color(0xFFF8FBFF), iceWhite],
  );

  /// Full-screen background (dark) — midnight badge depth.
  static const LinearGradient surfaceGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [midnightNavy, deepRoyal, midnightNavy],
  );

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
