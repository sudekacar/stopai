import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/feedback_theme.dart';
import '../../domain/answer_state.dart';

/// Cevaptan sonra beliren geri bildirim şeridi.
///
/// Doğruysa yeşil "Doğru!", yanlışsa lacivert "Yanlış!" gösterir.
/// Cevap verilmediğinde yer kaplamaz.
class AnswerFeedbackBanner extends StatelessWidget {
  const AnswerFeedbackBanner({
    super.key,
    required this.feedback,
    this.explanation,
  });

  final AnswerFeedback feedback;

  /// Doğru cevabın gerekçesi; verilirse şeridin altında gösterilir.
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.feedback;

    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: switch (feedback) {
        AnswerFeedback.none => const SizedBox(width: double.infinity),
        AnswerFeedback.correct => _Banner(
            background: colors.correctStrong,
            foreground: colors.onCorrect,
            icon: Icons.check_circle_rounded,
            title: 'Doğru!',
            message: explanation,
          ),
        AnswerFeedback.wrong => _Banner(
            background: colors.wrongStrong,
            foreground: colors.onWrong,
            icon: Icons.info_rounded,
            title: 'Yanlış!',
            message: explanation,
          ),
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.title,
    this.message,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: foreground, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(color: foreground),
              ),
            ],
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              style: textTheme.bodyMedium?.copyWith(
                color: foreground.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
