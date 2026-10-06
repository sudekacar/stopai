import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../purchase/presentation/paywall_screen.dart';
import '../domain/ai_message.dart';
import 'ai_coach_controller.dart';
import 'widgets/ai_message_bubble.dart';

/// AI ile görselli/sesli çalışma alanı.
///
/// AI Pro paketi olmayan kullanıcıya kilitli tanıtım ekranı, paket sahibine
/// sohbet arayüzü gösterilir. Sorular sunucudaki `/ai/ask` ucuna gider.
class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key, this.isActive = false});

  /// `IndexedStack` tüm sekmeleri baştan kurduğu için sağlık kontrolünü
  /// yalnızca bu sekme görünürken çalıştırıyoruz. Aksi halde Ollama durumu
  /// kullanıcı AI'ya geçmeden, eski bir yanıtla kilitlenirdi.
  final bool isActive;

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  AiCoachController? _chat;
  bool _unlockedHealthRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chat != null) return;

    _chat = AppScope.of(context).createAiCoachController()
      ..addListener(_scrollToBottom);
    _syncHealthCheck();
  }

  @override
  void didUpdateWidget(covariant AiCoachScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _syncHealthCheck();
    }
  }

  /// Sekme görünür ve paket açıksa Ollama durumunu sorar.
  void _syncHealthCheck() {
    if (!widget.isActive) return;
    final chat = _chat;
    if (chat == null) return;
    if (!AppScope.of(context).entitlement.aiUnlocked) return;
    chat.checkHealth();
  }

  @override
  void dispose() {
    _chat?.removeListener(_scrollToBottom);
    _chat?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final chat = _chat!;
    final text = preset ?? _input.text;
    if (text.trim().isEmpty && chat.pendingAttachment == null) return;

    _input.clear();
    await chat.send(text);
  }

  Future<void> _openPaywall() async {
    await showPaywall(
      context,
      reason: 'AI ile görselli ve sesli çalışma alanı kilitli.',
    );
  }

  Future<void> _pickPhotoSource() async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (fromCamera == null) return;
    await _chat!.attachPhoto(fromCamera: fromCamera);
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = AppScope.of(context).entitlement;
    final chat = _chat!;

    return ListenableBuilder(
      listenable: entitlement,
      builder: (context, _) {
        if (!entitlement.aiUnlocked) {
          _unlockedHealthRequested = false;
          return _AiLockedView(onUnlock: _openPaywall);
        }

        // Paket bu sekme açıkken alınırsa IndexedStack güncellenmez;
        // kilit kalkınca sağlık kontrolünü bir kez tetikleriz.
        if (widget.isActive && !_unlockedHealthRequested) {
          _unlockedHealthRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncHealthCheck();
          });
        }

        return ListenableBuilder(
          listenable: chat,
          builder: (context, _) => Column(
            children: [
              if (chat.health != null && !chat.health!.isUsable)
                _AiStatusBanner(
                  detail: chat.health!.detail,
                  onRetry: chat.checkHealth,
                ),
              Expanded(child: _buildMessages(chat)),
              if (chat.messages.length <= 2 && !chat.isTyping)
                _SuggestionRow(
                  suggestions: chat.suggestions,
                  onSelected: _send,
                ),
              _Composer(
                controller: _input,
                pendingAttachment: chat.pendingAttachment,
                isSending: chat.isTyping,
                onRemoveAttachment: chat.removeAttachment,
                onAttach: _pickPhotoSource,
                onSend: _send,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(AiCoachController chat) {
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      itemCount: chat.messages.length + (chat.isTyping ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index >= chat.messages.length) return const _TypingIndicator();

        final message = chat.messages[index];
        return AiMessageBubble(
          message: message,
          isSpeaking: chat.speakingMessageId == message.id,
          onToggleSpeech: () => chat.toggleSpeech(message.id),
          onRetry: chat.retryLastQuestion,
          onShowPaywall: _openPaywall,
        );
      },
    );
  }
}

/// Ollama kapalıyken sohbetin üstünde duran şerit.
class _AiStatusBanner extends StatelessWidget {
  const _AiStatusBanner({required this.detail, required this.onRetry});

  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: AppColors.blueSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 20, color: AppColors.navy),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              detail ?? 'AI modeli şu an hazır değil, yanıtlar gecikebilir.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.navy),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.navy),
            child: const Text('Yenile'),
          ),
        ],
      ),
    );
  }
}

/// Paket almayan kullanıcıya gösterilen kilitli tanıtım.
class _AiLockedView extends StatelessWidget {
  const _AiLockedView({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.redSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 36,
                color: AppColors.red,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'AI ile görselli çalışma',
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bu alan AI Pro pakete dâhildir. Araç parçalarının fotoğrafını '
            'yükleyip sorabilir, yanıtları sesli dinleyebilirsin.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          const _LockedFeature(
            icon: Icons.photo_camera_outlined,
            title: 'Fotoğraf yükle, parçayı tanı',
            subtitle: 'Motor bölümünden çektiğin kareyi koça sor.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _LockedFeature(
            icon: Icons.volume_up_rounded,
            title: 'Sesli anlatım',
            subtitle: 'Yanıtları dinleyerek tekrar yap.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _LockedFeature(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Sınırsız soru',
            subtitle: '"Alternatör nedir?" gibi her soruyu yaz.',
          ),
          const SizedBox(height: AppSpacing.xxxl),
          ElevatedButton(
            onPressed: onUnlock,
            child: const Text('299 TL ile Kilidi Aç'),
          ),
        ],
      ),
    );
  }
}

class _LockedFeature extends StatelessWidget {
  const _LockedFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.red, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestions, required this.onSelected});

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
        ),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => ActionChip(
          label: Text(suggestions[index]),
          onPressed: () => onSelected(suggestions[index]),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: AppRadius.md,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Koç yazıyor...', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.pendingAttachment,
    required this.isSending,
    required this.onRemoveAttachment,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final AiAttachment? pendingAttachment;
  final bool isSending;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          if (pendingAttachment != null) ...[
            _PendingAttachmentChip(
              fileName: pendingAttachment!.fileName,
              source: pendingAttachment!.source,
              onRemove: onRemoveAttachment,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              IconButton(
                onPressed: isSending ? null : onAttach,
                icon: const Icon(Icons.add_a_photo_outlined),
                tooltip: 'Fotoğraf ekle',
                color: AppColors.red,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isSending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  cursorColor: AppColors.red,
                  decoration: const InputDecoration(
                    hintText: 'Örn: Alternatör nedir?',
                    filled: true,
                    fillColor: AppColors.surfaceSoft,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.pill,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: isSending ? null : onSend,
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: 'Gönder',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: AppColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({
    required this.fileName,
    required this.source,
    required this.onRemove,
  });

  final String fileName;
  final String source;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.redSurface,
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          children: [
            const Icon(Icons.image_outlined, size: 18, color: AppColors.redDark),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '$source · $fileName',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.redDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: 'Görseli kaldır',
              color: AppColors.redDark,
            ),
          ],
        ),
      ),
    );
  }
}
