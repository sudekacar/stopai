import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_scaffold.dart';
import '../ai/presentation/ai_coach_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../tests/presentation/test_list_screen.dart';

/// Oturum açıldıktan sonraki ana kabuk: üç sekme ve altta sabit banner alanı.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<String> _titles = [
    'Deneme Testleri',
    'AI Koç',
    'Profil',
  ];

  @override
  Widget build(BuildContext context) {
    final entitlement = AppScope.of(context).entitlement;

    return AppScaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      // Sekmeler IndexedStack'te: sohbet geçmişi ve liste konumu korunur.
      body: IndexedStack(
        index: _index,
        children: [
          const TestListScreen(),
          AiCoachScreen(isActive: _index == 1),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: entitlement,
        builder: (context, _) => NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.redSurface,
          surfaceTintColor: Colors.transparent,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.checklist_rounded),
              label: 'Testler',
            ),
            NavigationDestination(
              icon: Icon(
                entitlement.aiUnlocked
                    ? Icons.auto_awesome_outlined
                    : Icons.lock_outline_rounded,
              ),
              selectedIcon: Icon(
                entitlement.aiUnlocked
                    ? Icons.auto_awesome_rounded
                    : Icons.lock_rounded,
              ),
              label: 'AI Koç',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
