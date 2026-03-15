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
            backgroundColor: AppColors.blue600,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.blue600.withOpacity(0.4),
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
            foregroundColor: AppColors.blue600,
            side: const BorderSide(color: AppColors.blue400),
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
            foregroundColor: AppColors.blue600,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.neutral100,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.neutral300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.blue500, width: 2),
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
      shadowColor: Colors.black26,
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
          backgroundColor: AppColors.blue50,
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
            backgroundColor: AppColors.cyan500,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 2,
            shadowColor: AppColors.cyan500.withOpacity(0.5),
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
            foregroundColor: AppColors.cyan400,
            side: const BorderSide(color: AppColors.cyan500),
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
            foregroundColor: AppColors.cyan400,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.neutral100Dark,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.neutral200Dark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.cyan500, width: 2),
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
        primary: AppColors.blue600,
        onPrimary: Colors.white,
        primaryContainer: AppColors.blue100,
        onPrimaryContainer: AppColors.blue900,
        secondary: AppColors.orange500,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.orange100,
        onSecondaryContainer: AppColors.orange900,
        tertiary: AppColors.cyan600,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.blue50,
        onTertiaryContainer: AppColors.blue900,
        error: AppColors.error,
        onError: Colors.white,
        surface: const Color(0xFFF8FAFC),
        onSurface: AppColors.neutral900,
        surfaceContainerHighest: AppColors.neutral100,
        onSurfaceVariant: AppColors.neutral600,
        outline: AppColors.neutral400,
      );

  static ColorScheme get _darkColorScheme => ColorScheme.dark(
        primary: AppColors.cyan500,
        onPrimary: const Color(0xFF0F172A),
        primaryContainer: AppColors.cyan600,
        onPrimaryContainer: AppColors.cyan400,
        secondary: AppColors.orange400,
        onSecondary: AppColors.orange900,
        secondaryContainer: AppColors.orange800,
        onSecondaryContainer: AppColors.orange100,
        tertiary: AppColors.cyan400,
        onTertiary: const Color(0xFF0F172A),
        tertiaryContainer: AppColors.cyan600,
        onTertiaryContainer: AppColors.cyan400,
        error: AppColors.error,
        onError: Colors.white,
        surface: const Color(0xFF0F172A),
        onSurface: AppColors.neutral900Dark,
        surfaceContainerHighest: const Color(0xFF1E293B),
        onSurfaceVariant: AppColors.neutral500,
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
