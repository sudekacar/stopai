import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../profile/domain/test_attempt.dart';
import '../../domain/test_bundle.dart';

/// Ana menüdeki tek bir test satırı.
///
/// Kilitli hâlde kart soluklaşır, sağ tarafta kilit simgesi çıkar ve dokunma
/// kullanıcıyı paywall'a götürür.
class TestCard extends StatelessWidget {
  const TestCard({
    super.key,
    required this.bundle,
    required this.isLocked,
    required this.onTap,
    this.bestScore,
  });

  final TestBundle bundle;
  final bool isLocked;
  final VoidCallback onTap;

  /// Bu testin en iyi skoru (0-100); hiç çözülmediyse `null`.
  final int? bestScore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: isLocked ? AppColors.surfaceSoft : AppColors.white,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _TestNumberBadge(number: bundle.number, isLocked: isLocked),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            bundle.title,
                            style: textTheme.titleMedium?.copyWith(
                              color:
                                  isLocked ? AppColors.inkMuted : AppColors.ink,
                            ),
                          ),
                        ),
                        if (bundle.isFree) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _Tag(
                            label: 'ÜCRETSİZ',
                            color: AppColors.greenDark,
                            background: AppColors.greenSurface,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${bundle.questionCount} soru · ${bundle.categorySummary}',
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (bestScore != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _BestScoreRow(score: bestScore!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                isLocked ? Icons.lock_rounded : Icons.chevron_right_rounded,
                color: isLocked ? AppColors.red : AppColors.inkFaint,
                size: isLocked ? 20 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestNumberBadge extends StatelessWidget {
  const _TestNumberBadge({required this.number, required this.isLocked});

  final int number;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isLocked ? AppColors.white : AppColors.redSurface,
        borderRadius: AppRadius.sm,
        border: Border.all(
          color: isLocked ? AppColors.border : AppColors.redSurface,
        ),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isLocked ? AppColors.inkFaint : AppColors.red,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _BestScoreRow extends StatelessWidget {
  const _BestScoreRow({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final passed = score >= TestAttempt.passingPercentage;

    return Row(
      children: [
        _Tag(
          label: 'EN İYİ %$score',
          color: passed ? AppColors.greenDark : AppColors.navy,
          background: passed ? AppColors.greenSurface : AppColors.blueSurface,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            passed ? 'geçtin' : 'geçme notu %70',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.pill),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, letterSpacing: 0.4),
      ),
    );
  }
}
