import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/ai_message.dart';

/// Sohbetteki tek bir mesaj balonu.
///
/// Kullanıcı mesajları kırmızı zeminde sağda, koç mesajları beyaz/çerçeveli
/// zeminde solda durur. Sunucu hatası dönen mesajlar lacivert uyarı kutusu
/// olarak gösterilir.
class AiMessageBubble extends StatelessWidget {
  const AiMessageBubble({
    super.key,
    required this.message,
    required this.isSpeaking,
    required this.onToggleSpeech,
    required this.onRetry,
    required this.onShowPaywall,
  });

  final AiMessage message;
  final bool isSpeaking;
  final VoidCallback onToggleSpeech;
  final VoidCallback onRetry;
  final VoidCallback onShowPaywall;

  @override
  Widget build(BuildContext context) {
    if (message.isError) {
      return _ErrorBubble(
        message: message,
        onRetry: onRetry,
        onShowPaywall: onShowPaywall,
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isUser ? AppColors.red : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: Border.all(
              color: isUser ? AppColors.red : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.attachment != null) ...[
                _AttachmentPreview(
                  attachment: message.attachment!,
                  onUserBubble: isUser,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                message.text,
                style: textTheme.bodyLarge?.copyWith(
                  color: isUser ? AppColors.white : AppColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (message.canPlayAudio) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _SpeechButton(
                      isSpeaking: isSpeaking,
                      onPressed: onToggleSpeech,
                    ),
                    if (message.model != null && message.model!.isNotEmpty)
                      Expanded(
                        child: Text(
                          message.model!,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sunucu hatalarını gösteren uyarı kutusu.
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({
    required this.message,
    required this.onRetry,
    required this.onShowPaywall,
  });

  final AiMessage message;
  final VoidCallback onRetry;
  final VoidCallback onShowPaywall;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final needsSubscription =
        message.errorCode == ApiErrorCode.subscriptionRequired;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.blueSurface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                needsSubscription
                    ? Icons.lock_rounded
                    : Icons.cloud_off_rounded,
                size: 20,
                color: AppColors.navy,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  needsSubscription ? 'Paket gerekli' : 'AI koça ulaşılamadı',
                  style: textTheme.titleMedium?.copyWith(color: AppColors.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message.text,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.navy),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: needsSubscription
                ? FilledButton.icon(
                    onPressed: onShowPaywall,
                    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                    label: const Text('Paketi Gör'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: AppColors.white,
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Tekrar Dene'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachment,
    required this.onUserBubble,
  });

  final AiAttachment attachment;
  final bool onUserBubble;

  @override
  Widget build(BuildContext context) {
    final foreground = onUserBubble ? AppColors.white : AppColors.inkMuted;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: onUserBubble
            ? AppColors.white.withValues(alpha: 0.16)
            : AppColors.surfaceSoft,
        borderRadius: AppRadius.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  attachment.source,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechButton extends StatelessWidget {
  const _SpeechButton({required this.isSpeaking, required this.onPressed});

  final bool isSpeaking;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
        size: 18,
      ),
      label: Text(isSpeaking ? 'Durdur' : 'Sesli anlat'),
    );
  }
}
