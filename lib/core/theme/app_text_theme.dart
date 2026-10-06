import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Uygulamanın tipografi ölçeği.
///
/// Özel font dosyası bağlanmadığı için platformun sistem fontu kullanılır;
/// `pubspec.yaml`'a bir font eklendiğinde tek yapılacak şey buradaki
/// [fontFamily] değerini doldurmaktır.
abstract final class AppTextTheme {
  static const String? fontFamily = null;

  static const TextTheme light = TextTheme(
    // Ekran başlıkları
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      color: AppColors.ink,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: AppColors.ink,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 21,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: AppColors.ink,
    ),
    // Kart ve bölüm başlıkları
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    // Soru metni ve şıklar
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.inkMuted,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: AppColors.inkMuted,
    ),
    // Buton ve etiketler
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.inkMuted,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: AppColors.inkFaint,
    ),
  );
}
