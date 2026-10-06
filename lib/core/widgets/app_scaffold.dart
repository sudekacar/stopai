import 'package:flutter/material.dart';

import '../ads/banner_ad_slot.dart';

/// Projedeki tüm ekranların kullandığı iskelet.
///
/// Tek işi banner reklam yuvasını her ekranın altına aynı şekilde
/// yerleştirmek; böylece yeni bir ekran eklenirken reklam alanı unutulmaz.
/// Yuva, satın alma sonrası kendini gizler (bkz. [BannerAdSlot]).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.showBannerAd = true,
    this.safeAreaTop = true,
    this.floatingActionButton,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Banner'ın hemen altına yerleşecek gezinme çubuğu.
  final Widget? bottomNavigationBar;

  final bool showBannerAd;
  final bool safeAreaTop;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(top: safeAreaTop, bottom: false, child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: _buildBottom(),
    );
  }

  Widget? _buildBottom() {
    final banner = showBannerAd ? const BannerAdSlot() : null;
    if (banner == null) return bottomNavigationBar;
    if (bottomNavigationBar == null) return banner;

    // Reklam gezinme çubuğunun üstünde kalır: sekme değiştirirken banner
    // konumu sabit durur, yanlış dokunma riski azalır.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [banner, bottomNavigationBar!],
    );
  }
}
