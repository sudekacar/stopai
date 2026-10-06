import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../profile/domain/test_attempt.dart';

/// Test bittiğinde gösterilen özet.
class QuizResultView extends StatelessWidget {
  const QuizResultView({
    super.key,
    required this.testTitle,
    required this.correctCount,
    required this.wrongCount,
    required this.successPercentage,
    required this.onRestart,
    required this.onExit,
  });

  final String testTitle;
  final int correctCount;
  final int wrongCount;
  final int successPercentage;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final passed = successPercentage >= TestAttempt.passingPercentage;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            testTitle.toUpperCase(),
            style: textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: passed ? AppColors.greenSurface : AppColors.blueSurface,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '%$successPercentage',
                    style: textTheme.displaySmall?.copyWith(
                      color: passed ? AppColors.greenDark : AppColors.navy,
                    ),
                  ),
                  Text(
                    'başarı',
                    style: textTheme.labelMedium?.copyWith(
                      color: passed ? AppColors.greenDark : AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            passed ? 'Tebrikler, geçtin!' : 'Biraz daha çalışmak gerek',
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Sonuç profilindeki istatistiklere işlendi. AI koç sekmesinden '
            'yanlışlarını sorup konuyu pekiştirebilirsin.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: _ResultTile(
                  label: 'Doğru',
                  value: correctCount,
                  color: AppColors.greenDark,
                  background: AppColors.greenSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ResultTile(
                  label: 'Yanlış',
                  value: wrongCount,
                  color: AppColors.navy,
                  background: AppColors.blueSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          ElevatedButton(onPressed: onRestart, child: const Text('Tekrar Çöz')),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onExit,
            child: const Text('Test Listesine Dön'),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final int value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.md),
      child: Column(
        children: [
          Text(
            '$value',
            style: textTheme.headlineMedium?.copyWith(color: color),
          ),
          Text(label, style: textTheme.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}
