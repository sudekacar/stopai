import 'package:flutter/material.dart';

import '../../../core/ads/ad_manager.dart';
import '../../../core/ads/interstitial_ad_placeholder.dart';
import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../profile/presentation/stats_controller.dart';
import '../../tests/domain/test_bundle.dart';
import '../domain/answer_state.dart';
import 'quiz_controller.dart';
import 'widgets/answer_feedback_banner.dart';
import 'widgets/answer_option_tile.dart';
import 'widgets/quiz_progress_header.dart';
import 'widgets/quiz_result_view.dart';

/// Test ekranı: soruyu gösterir, cevabı renklendirir, sonraki soruya geçer.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.bundle});

  final TestBundle bundle;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final AdManager _adManager;
  late final StatsController _stats;
  late final QuizController _controller;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final services = AppScope.of(context);
    _adManager = services.ads;
    _stats = services.stats;

    _controller = QuizController(
      bundle: widget.bundle,
      adManager: _adManager,
      onCompleted: _stats.recordAttempt,
    );

    _adManager
      ..resetQuestionCounter()
      ..onInterstitialTriggered = _onInterstitialTriggered;
  }

  @override
  void dispose() {
    _adManager.onInterstitialTriggered = null;
    _controller.dispose();
    super.dispose();
  }

  /// Reklam SDK'sı bağlanana kadar yer tutucuyu gösterir.
  void _onInterstitialTriggered() {
    if (!mounted) return;
    showInterstitialAdPlaceholder(context);
  }

  /// Yarıda kalan testten çıkarken onay ister.
  Future<void> _confirmExit() async {
    final navigator = Navigator.of(context);

    if (!_controller.hasStarted || _controller.isFinished) {
      navigator.pop();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Testten çıkılsın mı?'),
        content: const Text(
          'Şu ana kadar verdiğin cevaplar kaydedilmeyecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Devam Et'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );

    if ((shouldExit ?? false) && navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(widget.bundle.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Kapat',
          onPressed: _confirmExit,
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isFinished) {
            return QuizResultView(
              testTitle: widget.bundle.title,
              correctCount: _controller.correctCount,
              wrongCount: _controller.wrongCount,
              successPercentage: _controller.successPercentage,
              onRestart: _controller.restart,
              onExit: () => Navigator.of(context).pop(),
            );
          }
          return _QuestionView(controller: _controller);
        },
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = controller.currentQuestion;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.sm,
            AppSpacing.screenGutter,
            AppSpacing.lg,
          ),
          child: QuizProgressHeader(
            questionNumber: controller.currentQuestionNumber,
            questionCount: controller.questionCount,
            correctCount: controller.correctCount,
            wrongCount: controller.wrongCount,
            progressRatio: controller.progressRatio,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              0,
              AppSpacing.screenGutter,
              AppSpacing.xxl,
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: AppRadius.lg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.category.label.toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.red),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(question.text, style: theme.textTheme.headlineSmall),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < question.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AnswerOptionTile(
                    label: String.fromCharCode(65 + i),
                    text: question.options[i],
                    state: controller.optionState(i),
                    onTap: () => controller.selectAnswer(i),
                  ),
                ),
              AnswerFeedbackBanner(
                feedback: controller.feedback,
                explanation: controller.feedback == AnswerFeedback.none
                    ? null
                    : question.explanation,
              ),
            ],
          ),
        ),
        _NextButtonBar(controller: controller),
      ],
    );
  }
}

class _NextButtonBar extends StatelessWidget {
  const _NextButtonBar({required this.controller});

  final QuizController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ElevatedButton(
        onPressed: controller.isAnswered ? controller.goToNextQuestion : null,
        child: Text(controller.isLastQuestion ? 'Testi Bitir' : 'Sonraki Soru'),
      ),
    );
  }
}
