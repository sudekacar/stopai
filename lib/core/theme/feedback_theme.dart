import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Cevap geri bildirimi renklerini `ThemeData` üzerinden taşıyan uzantı.
///
/// Böylece "doğru = yeşil", "yanlış = lacivert/mavi" kararı tek yerde durur;
/// widget'lar `Theme.of(context).feedback` üzerinden okur ve ileride tema
/// değişse (ör. koyu mod) widget kodu değişmez.
@immutable
class FeedbackTheme extends ThemeExtension<FeedbackTheme> {
  const FeedbackTheme({
    required this.correct,
    required this.correctStrong,
    required this.correctSurface,
    required this.onCorrect,
    required this.wrong,
    required this.wrongStrong,
    required this.wrongSurface,
    required this.onWrong,
    required this.neutralSurface,
    required this.neutralBorder,
  });

  /// Doğru şıkkın çerçeve ve ikon rengi.
  final Color correct;

  /// "Doğru!" bildirim şeridinin zemini.
  final Color correctStrong;

  /// Doğru şıkkın açık zemini.
  final Color correctSurface;

  /// [correctStrong] üzerine yazılan metin rengi.
  final Color onCorrect;

  /// Seçilen yanlış şıkkın çerçeve ve ikon rengi.
  final Color wrong;

  /// "Yanlış!" bildirim şeridinin zemini (lacivert).
  final Color wrongStrong;

  /// Seçilen yanlış şıkkın açık zemini.
  final Color wrongSurface;

  /// [wrongStrong] üzerine yazılan metin rengi.
  final Color onWrong;

  /// Henüz seçilmemiş şıkkın zemini.
  final Color neutralSurface;

  /// Henüz seçilmemiş şıkkın çerçevesi.
  final Color neutralBorder;

  static const FeedbackTheme light = FeedbackTheme(
    correct: AppColors.green,
    correctStrong: AppColors.greenDark,
    correctSurface: AppColors.greenSurface,
    onCorrect: AppColors.white,
    wrong: AppColors.blue,
    wrongStrong: AppColors.navy,
    wrongSurface: AppColors.blueSurface,
    onWrong: AppColors.white,
    neutralSurface: AppColors.white,
    neutralBorder: AppColors.border,
  );

  @override
  FeedbackTheme copyWith({
    Color? correct,
    Color? correctStrong,
    Color? correctSurface,
    Color? onCorrect,
    Color? wrong,
    Color? wrongStrong,
    Color? wrongSurface,
    Color? onWrong,
    Color? neutralSurface,
    Color? neutralBorder,
  }) {
    return FeedbackTheme(
      correct: correct ?? this.correct,
      correctStrong: correctStrong ?? this.correctStrong,
      correctSurface: correctSurface ?? this.correctSurface,
      onCorrect: onCorrect ?? this.onCorrect,
      wrong: wrong ?? this.wrong,
      wrongStrong: wrongStrong ?? this.wrongStrong,
      wrongSurface: wrongSurface ?? this.wrongSurface,
      onWrong: onWrong ?? this.onWrong,
      neutralSurface: neutralSurface ?? this.neutralSurface,
      neutralBorder: neutralBorder ?? this.neutralBorder,
    );
  }

  @override
  FeedbackTheme lerp(ThemeExtension<FeedbackTheme>? other, double t) {
    if (other is! FeedbackTheme) return this;
    return FeedbackTheme(
      correct: Color.lerp(correct, other.correct, t)!,
      correctStrong: Color.lerp(correctStrong, other.correctStrong, t)!,
      correctSurface: Color.lerp(correctSurface, other.correctSurface, t)!,
      onCorrect: Color.lerp(onCorrect, other.onCorrect, t)!,
      wrong: Color.lerp(wrong, other.wrong, t)!,
      wrongStrong: Color.lerp(wrongStrong, other.wrongStrong, t)!,
      wrongSurface: Color.lerp(wrongSurface, other.wrongSurface, t)!,
      onWrong: Color.lerp(onWrong, other.onWrong, t)!,
      neutralSurface: Color.lerp(neutralSurface, other.neutralSurface, t)!,
      neutralBorder: Color.lerp(neutralBorder, other.neutralBorder, t)!,
    );
  }
}

extension FeedbackThemeAccess on ThemeData {
  /// Cevap geri bildirimi renkleri. Tema kurulumunda uzantı her zaman
  /// eklendiği için varsayılan olarak [FeedbackTheme.light] döner.
  FeedbackTheme get feedback => extension<FeedbackTheme>() ?? FeedbackTheme.light;
}
