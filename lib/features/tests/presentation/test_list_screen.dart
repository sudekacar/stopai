import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../purchase/presentation/paywall_screen.dart';
import '../../quiz/presentation/quiz_screen.dart';
import '../data/test_catalog.dart';
import '../domain/test_bundle.dart';
import 'widgets/test_card.dart';

/// Ana test menüsü: 20 deneme testi, ilki ücretsiz diğerleri kilitli.
class TestListScreen extends StatelessWidget {
  const TestListScreen({super.key});

  Future<void> _openTest(BuildContext context, TestBundle bundle) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuizScreen(bundle: bundle)),
    );
  }

  Future<void> _openPaywall(BuildContext context, TestBundle bundle) async {
    final purchased = await showPaywall(
      context,
      reason: '${bundle.title} kilitli. Kilitleri açtığında bu test ve '
          'kalan tüm testler açılır.',
    );

    // Satın alma yapıldıysa kullanıcıyı beklettiğimiz teste doğrudan alalım.
    if (purchased && context.mounted) {
      await _openTest(context, bundle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        services.entitlement,
        services.stats,
        services.auth,
      ]),
      builder: (context, _) {
        final unlocked = services.entitlement.allTestsUnlocked;
        final stats = services.stats;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.lg,
            AppSpacing.screenGutter,
            AppSpacing.xxl,
          ),
          itemCount: TestCatalog.all.length + 1,
          separatorBuilder: (_, index) => SizedBox(
            height: index == 0 ? AppSpacing.xl : AppSpacing.md,
          ),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _MenuHeader(
                greetingName: services.auth.user?.displayName ?? '',
                completedTestCount: stats.completedTestCount,
                averageSuccess: stats.averageScore,
                isUnlocked: unlocked,
                onUnlockTap: () => showPaywall(
                  context,
                  reason: '2-20 arası testlerin tamamı kilitli.',
                ),
              );
            }

            final bundle = TestCatalog.all[index - 1];
            final isLocked = !bundle.isFree && !unlocked;

            return TestCard(
              bundle: bundle,
              isLocked: isLocked,
              bestScore: stats.bestScoreFor(bundle.number),
              onTap: () => isLocked
                  ? _openPaywall(context, bundle)
                  : _openTest(context, bundle),
            );
          },
        );
      },
    );
  }
}

/// Listenin başındaki özet ve kilit açma çağrısı.
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.greetingName,
    required this.completedTestCount,
    required this.averageSuccess,
    required this.isUnlocked,
    required this.onUnlockTap,
  });

  final String greetingName;
  final int completedTestCount;
  final int averageSuccess;
  final bool isUnlocked;
  final VoidCallback onUnlockTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final firstName = greetingName.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          firstName.isEmpty ? 'Deneme Testleri' : 'Merhaba $firstName',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$completedTestCount/${TestCatalog.testCount} test tamamlandı'
          '${completedTestCount == 0 ? '' : ' · ortalama %$averageSuccess'}',
          style: textTheme.bodyMedium,
        ),
        if (!isUnlocked) ...[
          const SizedBox(height: AppSpacing.lg),
          _UnlockBanner(onTap: onUnlockTap),
        ],
      ],
    );
  }
}

class _UnlockBanner extends StatelessWidget {
  const _UnlockBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.redSurface,
      borderRadius: AppRadius.lg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.lock_open_rounded, color: AppColors.red),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '19 test kilitli',
                      style: textTheme.titleMedium
                          ?.copyWith(color: AppColors.redDark),
                    ),
                    Text(
                      'Ömür boyu erişim için 99 TL',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.redDark),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.red),
            ],
          ),
        ),
      ),
    );
  }
}
