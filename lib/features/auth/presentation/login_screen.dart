import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_primary_button.dart';
import '../../../core/widgets/message_banner.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'register_screen.dart';
import 'widgets/auth_scaffold.dart';

/// E-posta ve şifre ile giriş.
///
/// Başarılı girişte yönlendirme yapılmaz: `AuthGate` oturum durumunu
/// dinlediği için kullanıcı doğrudan ana test menüsüne düşer.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return AuthScaffold(
          title: 'Tekrar hoş geldin',
          subtitle: 'Kaldığın yerden devam etmek için giriş yap.',
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'E-posta',
                    controller: _emailController,
                    hintText: 'ornek@eposta.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: AuthValidators.email,
                    enabled: !auth.isBusy,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Şifre',
                    controller: _passwordController,
                    hintText: 'Şifreni gir',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscurable: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: AuthValidators.loginPassword,
                    enabled: !auth.isBusy,
                    onSubmitted: () => _submit(auth),
                  ),
                ],
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              MessageBanner.error(auth.errorMessage!),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AsyncPrimaryButton(
              label: 'Giriş Yap',
              isLoading: auth.isBusy,
              onPressed: () => _submit(auth),
            ),
            const SizedBox(height: AppSpacing.sm),
            AuthFooterLink(
              question: 'Hesabın yok mu?',
              actionLabel: 'Üye Ol',
              onPressed: auth.isBusy ? null : _openRegister,
            ),
          ],
        );
      },
    );
  }
}
