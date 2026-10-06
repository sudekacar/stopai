import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_theme.dart';
import 'feedback_theme.dart';

/// Uygulamanın tema tanımı. `MaterialApp.theme` buradan beslenir.
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.red,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.redSurface,
      onPrimaryContainer: AppColors.redDark,
      secondary: AppColors.navy,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.blueSurface,
      onSecondaryContainer: AppColors.navy,
      tertiary: AppColors.green,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.greenSurface,
      onTertiaryContainer: AppColors.greenDark,
      error: AppColors.red,
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.surfaceSoft,
      surfaceContainer: AppColors.surfaceSoft,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTextTheme.light,
      fontFamily: AppTextTheme.fontFamily,
      scaffoldBackgroundColor: AppColors.white,
      canvasColor: AppColors.white,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shadowColor: AppColors.redShadow,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: AppTextTheme.light.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.red,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.red, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: AppTextTheme.light.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.red,
          textStyle: AppTextTheme.light.labelLarge,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.red,
        linearTrackColor: AppColors.border,
        linearMinHeight: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.redSurface,
        side: BorderSide.none,
        labelStyle: AppTextTheme.light.labelMedium?.copyWith(
          color: AppColors.redDark,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: AppTextTheme.light.bodyMedium?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      extensions: const <ThemeExtension<dynamic>>[FeedbackTheme.light],
    );
  }
}
