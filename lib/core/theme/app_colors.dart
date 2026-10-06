import 'package:flutter/material.dart';

/// Uygulamadaki tek renk kaynağı. Widget'lar içinde `Color(0x...)` yazılmaz,
/// her renk buradan okunur.
///
/// Marka kimliği iki renge dayanır: saf beyaz zemin ve trafik levhası
/// kırmızısı. Geri bildirim renkleri (yeşil ve lacivert/mavi) yalnızca cevap
/// anında devreye girer, genel arayüzde kullanılmaz.
abstract final class AppColors {
  // ---------------------------------------------------------------- Marka
  /// Tüm ekranların zemini.
  static const Color white = Color(0xFFFFFFFF);

  /// Ana vurgu rengi: trafik levhası / App Store kırmızısı.
  static const Color red = Color(0xFFE31B23);

  /// Basılı hâl, gölge ve gradyan sonu için koyu kırmızı.
  static const Color redDark = Color(0xFFB4131A);

  /// Kırmızı üzerine çok açık zemin (etiket, chip, uyarı kutusu).
  static const Color redSurface = Color(0xFFFFEDEE);

  // -------------------------------------------------- Doğru cevap (yeşil)
  static const Color green = Color(0xFF16A34A);
  static const Color greenDark = Color(0xFF0E7A36);
  static const Color greenSurface = Color(0xFFE7F8EE);

  // ------------------------------------ Yanlış cevap (lacivert / mavi)
  /// "Yanlış!" bildiriminin zemini: şık, koyu lacivert.
  static const Color navy = Color(0xFF16325C);

  /// Kullanıcının seçtiği yanlış şıkkın vurgu rengi.
  static const Color blue = Color(0xFF2B5CA8);
  static const Color blueSurface = Color(0xFFE9EFF9);

  // ---------------------------------------------------------------- Nötr
  static const Color ink = Color(0xFF101828);
  static const Color inkMuted = Color(0xFF5A6474);
  static const Color inkFaint = Color(0xFF98A2B3);
  static const Color border = Color(0xFFE4E7EC);

  /// Beyazdan bir tık kırık zemin (kart içi, reklam yuvası).
  static const Color surfaceSoft = Color(0xFFF7F8FA);

  /// Kırmızı butonların altındaki yumuşak gölge.
  static const Color redShadow = Color(0x33E31B23);
}
