import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'core/widgets/stop_sign_logo.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/shell/main_shell.dart';

/// Uygulamanın kökü. Servisler, tema ve ilk ekran burada bağlanır.
class StopApp extends StatelessWidget {
  const StopApp({super.key, required this.services});

  static const String appName = 'Stop! AI Ehliyet Koçu';

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Tasarım beyaz zemin üzerine kurulu; koyu mod ayrı bir adımda eklenecek.
        themeMode: ThemeMode.light,
        builder: (context, child) {
          return OfflineBannerHost(
            network: services.network,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}

/// Oturum durumuna göre giriş ekranı ile ana kabuk arasında geçiş yapar.
///
/// Giriş/kayıt ekranlarının ayrıca yönlendirme yapmasına gerek yok: oturum
/// açıldığı anda kullanıcı ana test menüsüne düşer.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return switch (auth.status) {
          AuthStatus.unknown => const _SplashView(),
          AuthStatus.authenticated => const MainShell(),
          AuthStatus.unauthenticated => const LoginScreen(),
        };
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StopSignLogo(size: 88),
            SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
