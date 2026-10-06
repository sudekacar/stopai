import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/message_banner.dart';
import '../../purchase/presentation/paywall_screen.dart';
import '../../quiz/domain/question.dart';
import '../../tests/data/test_catalog.dart';
import '../domain/quiz_stats.dart';
import '../domain/test_attempt.dart';
import 'stats_controller.dart';

/// Sonuçlar ve profil: istatistikler, konu bazlı başarı ve üyelik durumu.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        services.auth,
        services.entitlement,
        services.stats,
      ]),
      builder: (context, _) {
        final user = services.auth.user;
        final entitlement = services.entitlement.entitlement;
        final statsController = services.stats;
        final localStats = statsController.local;

        return RefreshIndicator(
          onRefresh: statsController.refresh,
          color: AppColors.red,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.lg,
            AppSpacing.screenGutter,
            AppSpacing.xxl,
          ),
          children: [
            if (statsController.pendingCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _SyncNotice(pending: statsController.pendingCount),
              ),
            _UserCard(
              initials: user?.initials ?? '?',
              displayName: user?.displayName ?? 'Misafir',
              email: user?.email ?? '',
            ),
            const SizedBox(height: AppSpacing.lg),
            _MembershipCard(
              planLabel: entitlement.planLabel,
              isPaid: entitlement.hasAnyPurchase,
              aiUnlocked: entitlement.aiUnlocked,
              onSeePlans: () => showPaywall(
                context,
                reason: 'Paketleri karşılaştırıp kilitleri açabilirsin.',
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('İstatistikler', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _StatsGrid(controller: statsController),
            if (!localStats.isEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Konu bazlı başarı',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              // Sunucu yalnızca skoru saklıyor; konu kırılımı bu cihazda
              // tutulan ayrıntılı kayıtlardan hesaplanıyor.
              _CategoryBreakdown(stats: localStats),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Son denemeler',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              _RecentAttempts(attempts: localStats.attempts.take(5).toList()),
            ],
            const SizedBox(height: AppSpacing.xxxl),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Çıkış Yap'),
            ),
          ],
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final services = AppScope.of(context);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text(
          'İstatistiklerin ve satın alımların hesabında kayıtlı kalır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (shouldLogout ?? false) await services.auth.logout();
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.initials,
    required this.displayName,
    required this.email,
  });

  final String initials;
  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.red,
            shape: BoxShape.circle,
          ),
          child: Text(
            initials,
            style: textTheme.titleLarge?.copyWith(color: AppColors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: textTheme.headlineSmall),
              if (email.isNotEmpty)
                Text(email, style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.planLabel,
    required this.isPaid,
    required this.aiUnlocked,
    required this.onSeePlans,
  });

  final String planLabel;
  final bool isPaid;
  final bool aiUnlocked;
  final VoidCallback onSeePlans;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isPaid ? AppColors.greenSurface : AppColors.surfaceSoft,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: isPaid ? AppColors.green : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isPaid ? Icons.workspace_premium_rounded : Icons.person_outline,
                color: isPaid ? AppColors.greenDark : AppColors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  planLabel,
                  style: textTheme.titleMedium?.copyWith(
                    color: isPaid ? AppColors.greenDark : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _PlanRow(
            label: 'Tüm testler (2-20)',
            unlocked: isPaid,
          ),
          _PlanRow(label: 'AI görselli/sesli çalışma', unlocked: aiUnlocked),
          _PlanRow(label: 'Reklamsız kullanım', unlocked: isPaid),
          if (!isPaid) ...[
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: onSeePlans,
              child: const Text('Paketleri Gör'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label, required this.unlocked});

  final String label;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
            size: 18,
            color: unlocked ? AppColors.green : AppColors.inkFaint,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: unlocked ? AppColors.ink : AppColors.inkMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.controller});

  final StatsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Tamamlanan test',
                value:
                    '${controller.completedTestCount}/${TestCatalog.testCount}',
                icon: Icons.checklist_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatTile(
                label: 'Çözülen soru',
                value: '${controller.totalQuestions}',
                icon: Icons.help_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Ortalama başarı',
                value: '%${controller.averageScore}',
                icon: Icons.insights_rounded,
                valueColor:
                    controller.averageScore >= TestAttempt.passingPercentage
                        ? AppColors.greenDark
                        : AppColors.navy,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatTile(
                label: 'En iyi sonuç',
                value: '%${controller.bestScore}',
                icon: Icons.emoji_events_outlined,
                valueColor: AppColors.greenDark,
              ),
            ),
          ],
        ),
        if (controller.isEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Henüz test çözmedin. 1. deneme testi ücretsiz, oradan başlayabilirsin.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (controller.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.lg),
          MessageBanner.info(
            'Sunucudaki istatistikler alınamadı, bu cihazdaki kayıtlar '
            'gösteriliyor. Aşağı çekerek yeniden deneyebilirsin.',
          ),
        ],
      ],
    );
  }
}

/// Çevrimdışı çözülüp henüz gönderilemeyen sonuçlar için bilgi şeridi.
class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    return MessageBanner.info(
      '$pending test sonucu sunucuya gönderilmeyi bekliyor. Bağlantı '
      'gelince otomatik yüklenecek.',
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.inkFaint),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(color: valueColor),
          ),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.stats});

  final QuizStats stats;

  @override
  Widget build(BuildContext context) {
    final entries = stats.byCategory.entries.toList()
      ..sort((a, b) => b.value.ratio.compareTo(a.value.ratio));
    final weakest = stats.weakestCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _CategoryRow(
              category: entry.key,
              percentage: entry.value.percentage,
              correct: entry.value.correct,
              total: entry.value.total,
            ),
          ),
        if (weakest != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.blueSurface,
              borderRadius: AppRadius.md,
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.navy),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'En çok zorlandığın konu: ${weakest.label}. AI koç '
                    'sekmesinden bu konuyu sorabilirsin.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.navy),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.percentage,
    required this.correct,
    required this.total,
  });

  final QuestionCategory category;
  final int percentage;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final passed = percentage >= TestAttempt.passingPercentage;
    final color = passed ? AppColors.green : AppColors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(category.label, style: textTheme.titleMedium)),
            Text(
              '%$percentage',
              style: textTheme.titleMedium?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.pill,
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : correct / total,
            color: color,
            backgroundColor: AppColors.border,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('$correct / $total doğru', style: textTheme.bodySmall),
      ],
    );
  }
}

class _RecentAttempts extends StatelessWidget {
  const _RecentAttempts({required this.attempts});

  final List<TestAttempt> attempts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        for (final attempt in attempts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deneme Testi ${attempt.testNumber}',
                          style: textTheme.titleMedium,
                        ),
                        Text(
                          '${_formatDate(attempt.completedAt)} · '
                          '${attempt.correctCount}/${attempt.questionCount} doğru',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '%${attempt.successPercentage}',
                    style: textTheme.titleLarge?.copyWith(
                      color:
                          attempt.passed ? AppColors.greenDark : AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// `intl` bağımlılığı eklemeye değmeyecek kadar basit bir biçim.
  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
