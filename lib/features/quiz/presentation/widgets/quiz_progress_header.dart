import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Soru sayacı, doğru/yanlış sayısı ve ilerleme çubuğu.
class QuizProgressHeader extends StatelessWidget {
  const QuizProgressHeader({
    super.key,
    required this.questionNumber,
    required this.questionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.progressRatio,
  });

  final int questionNumber;
  final int questionCount;
  final int correctCount;
  final int wrongCount;

  /// 0 ile 1 arasında ilerleme oranı.
  final double progressRatio;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'Soru $questionNumber',
                style: textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                ' / $questionCount',
                style:
                    textTheme.titleMedium?.copyWith(color: AppColors.inkFaint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            _ScoreChip(
              icon: Icons.check_rounded,
              value: correctCount,
              color: AppColors.green,
              background: AppColors.greenSurface,
            ),
            const SizedBox(width: AppSpacing.sm),
            _ScoreChip(
              icon: Icons.close_rounded,
              value: wrongCount,
              color: AppColors.blue,
              background: AppColors.blueSurface,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progressRatio.clamp(0.0, 1.0)),
          duration: AppMotion.normal,
          curve: AppMotion.curve,
          builder: (context, value, _) => ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(value: value),
          ),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.icon,
    required this.value,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final int value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.pill),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$value',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
