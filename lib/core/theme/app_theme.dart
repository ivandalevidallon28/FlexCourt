import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _lightColorScheme,
        textTheme: _textTheme,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: _lightColorScheme.surface,
          foregroundColor: _lightColorScheme.onSurface,
          titleTextStyle: AppTypography.titleLarge.copyWith(
            color: _lightColorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.strongBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.deepRoyal.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.strongBlue,
            side: const BorderSide(color: AppColors.electricBlue),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.strongBlue,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.iceWhite,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: BorderSide(color: AppColors.coolGray.withValues(alpha: 0.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.electricBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: AppColors.midnightNavy.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
          clipBehavior: Clip.antiAlias,
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          minLeadingWidth: 40,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.iceWhite,
          selectedColor: AppColors.blue200,
          labelStyle: AppTypography.labelMedium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkColorScheme,
        textTheme: _textTheme.apply(
          bodyColor: AppColors.neutral900Dark,
          displayColor: AppColors.neutral900Dark,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 4,
          backgroundColor: _darkColorScheme.surface,
          foregroundColor: _darkColorScheme.onSurface,
          titleTextStyle: AppTypography.titleLarge.copyWith(
            color: _darkColorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.electricBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.electricBlue.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.skyBlue,
            side: const BorderSide(color: AppColors.electricBlue),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusMd,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.skyBlue,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.neutral100Dark,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: BorderSide(
              color: AppColors.coolGray.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.skyBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          color: AppColors.neutral100Dark,
          margin: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
          clipBehavior: Clip.antiAlias,
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          minLeadingWidth: 40,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        ),
      );

  static ColorScheme get _lightColorScheme => ColorScheme.light(
        primary: AppColors.strongBlue,
        onPrimary: Colors.white,
        primaryContainer: AppColors.iceWhite,
        onPrimaryContainer: AppColors.midnightNavy,
        secondary: AppColors.orange500,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.orange100,
        onSecondaryContainer: AppColors.orange900,
        tertiary: AppColors.electricBlue,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.blue100,
        onTertiaryContainer: AppColors.deepRoyal,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.iceWhite,
        onSurface: AppColors.midnightNavy,
        surfaceContainerHighest: AppColors.neutral100,
        onSurfaceVariant: AppColors.coolGray,
        outline: AppColors.neutral400,
      );

  static ColorScheme get _darkColorScheme => ColorScheme.dark(
        primary: AppColors.electricBlue,
        onPrimary: Colors.white,
        primaryContainer: AppColors.deepRoyal,
        onPrimaryContainer: AppColors.iceWhite,
        secondary: AppColors.orange400,
        onSecondary: AppColors.orange900,
        secondaryContainer: AppColors.orange800,
        onSecondaryContainer: AppColors.orange100,
        tertiary: AppColors.skyBlue,
        onTertiary: AppColors.midnightNavy,
        tertiaryContainer: AppColors.strongBlue,
        onTertiaryContainer: AppColors.iceWhite,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.midnightNavy,
        onSurface: AppColors.iceWhite,
        surfaceContainerHighest: AppColors.deepRoyal,
        onSurfaceVariant: AppColors.coolGray,
        outline: AppColors.neutral600,
      );

  static TextTheme get _textTheme => TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      );
}
