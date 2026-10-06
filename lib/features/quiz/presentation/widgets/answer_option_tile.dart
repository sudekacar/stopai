import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/feedback_theme.dart';
import '../../domain/answer_state.dart';

/// Tek bir şık satırı. Renkleri tamamen [AnswerOptionState] belirler.
class AnswerOptionTile extends StatelessWidget {
  const AnswerOptionTile({
    super.key,
    required this.label,
    required this.text,
    required this.state,
    required this.onTap,
  });

  /// Şık harfi: A, B, C, D.
  final String label;

  final String text;
  final AnswerOptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedback = theme.feedback;
    final style = _OptionStyle.of(state, feedback);

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: AppRadius.md,
        border: Border.all(color: style.border, width: style.borderWidth),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: state == AnswerOptionState.idle ? onTap : null,
          borderRadius: AppRadius.md,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                _LabelBadge(label: label, style: style),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.normal,
                    curve: AppMotion.curve,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: style.foreground,
                      fontWeight: style.isHighlighted
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    child: Text(text),
                  ),
                ),
                if (style.trailingIcon != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(style.trailingIcon, color: style.accent, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelBadge extends StatelessWidget {
  const _LabelBadge({required this.label, required this.style});

  final String label;
  final _OptionStyle style;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.badgeBackground,
        shape: BoxShape.circle,
        border: Border.all(color: style.badgeBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: style.badgeForeground,
              fontSize: 14,
            ),
      ),
    );
  }
}

/// [AnswerOptionState] -> renk eşlemesi. Tek karar noktası.
class _OptionStyle {
  const _OptionStyle({
    required this.background,
    required this.border,
    required this.borderWidth,
    required this.foreground,
    required this.accent,
    required this.badgeBackground,
    required this.badgeBorder,
    required this.badgeForeground,
    required this.isHighlighted,
    this.trailingIcon,
  });

  final Color background;
  final Color border;
  final double borderWidth;
  final Color foreground;
  final Color accent;
  final Color badgeBackground;
  final Color badgeBorder;
  final Color badgeForeground;
  final bool isHighlighted;
  final IconData? trailingIcon;

  factory _OptionStyle.of(AnswerOptionState state, FeedbackTheme feedback) {
    switch (state) {
      case AnswerOptionState.idle:
        return _OptionStyle(
          background: feedback.neutralSurface,
          border: feedback.neutralBorder,
          borderWidth: 1,
          foreground: AppColors.ink,
          accent: AppColors.inkFaint,
          badgeBackground: AppColors.surfaceSoft,
          badgeBorder: AppColors.border,
          badgeForeground: AppColors.inkMuted,
          isHighlighted: false,
        );

      // Doğru cevap: kullanıcı seçtiyse de, yanlış seçip açığa çıktıysa da yeşil.
      case AnswerOptionState.selectedCorrect:
      case AnswerOptionState.revealedCorrect:
        return _OptionStyle(
          background: feedback.correctSurface,
          border: feedback.correct,
          borderWidth: 2,
          foreground: feedback.correctStrong,
          accent: feedback.correct,
          badgeBackground: feedback.correct,
          badgeBorder: feedback.correct,
          badgeForeground: feedback.onCorrect,
          isHighlighted: true,
          trailingIcon: Icons.check_circle_rounded,
        );

      // Kullanıcının seçtiği yanlış şık: mavi.
      case AnswerOptionState.selectedWrong:
        return _OptionStyle(
          background: feedback.wrongSurface,
          border: feedback.wrong,
          borderWidth: 2,
          foreground: feedback.wrongStrong,
          accent: feedback.wrong,
          badgeBackground: feedback.wrong,
          badgeBorder: feedback.wrong,
          badgeForeground: feedback.onWrong,
          isHighlighted: true,
          trailingIcon: Icons.cancel_rounded,
        );

      case AnswerOptionState.dimmed:
        return _OptionStyle(
          background: AppColors.white,
          border: AppColors.border,
          borderWidth: 1,
          foreground: AppColors.inkFaint,
          accent: AppColors.inkFaint,
          badgeBackground: AppColors.white,
          badgeBorder: AppColors.border,
          badgeForeground: AppColors.inkFaint,
          isHighlighted: false,
        );
    }
  }
}
