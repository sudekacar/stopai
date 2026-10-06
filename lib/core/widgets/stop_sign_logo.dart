import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marka logosu: kırmızı sekizgen dur levhası üzerinde "STOP" yazısı.
class StopSignLogo extends StatelessWidget {
  const StopSignLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipper: const _OctagonClipper(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.red, AppColors.redDark],
            ),
          ),
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: EdgeInsets.all(size * 0.22),
                child: const Text(
                  'STOP',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonClipper extends CustomClipper<Path> {
  const _OctagonClipper();

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final path = Path();

    for (var i = 0; i < 8; i++) {
      // Düz kenar üstte kalsın diye yarım adım (pi/8) döndürüyoruz.
      final angle = (math.pi / 4) * i - math.pi / 2 + math.pi / 8;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
