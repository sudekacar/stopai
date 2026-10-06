import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_primary_button.dart';
import '../../../core/widgets/message_banner.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Yeni hesap oluşturma.
///
/// Kayıt başarılıysa ekran kapatılır; `AuthGate` oturumu görüp kullanıcıyı
/// ana test menüsüne alır.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthController auth) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final success = await auth.register(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _nameController.text,
    );

    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return AuthScaffold(
          showBackButton: true,
          title: 'Hesap oluştur',
          subtitle: '1. deneme testi ücretsiz; hemen çözmeye başlayabilirsin.',
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Ad Soyad',
                    controller: _nameController,
                    hintText: 'Adın ve soyadın',
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: AuthValidators.displayName,
                    enabled: !auth.isBusy,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'E-posta',
                    controller: _emailController,
                    hintText: 'ornek@eposta.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newUsername],
                    validator: AuthValidators.email,
                    enabled: !auth.isBusy,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Şifre',
                    controller: _passwordController,
                    hintText: 'En az 6 karakter, harf ve rakam',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscurable: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: AuthValidators.password,
                    enabled: !auth.isBusy,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Şifre Tekrar',
                    controller: _confirmController,
                    hintText: 'Şifreni tekrar gir',
                    prefixIcon: Icons.lock_reset_rounded,
                    obscurable: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) => AuthValidators.passwordConfirmation(
                      value,
                      _passwordController.text,
                    ),
                    enabled: !auth.isBusy,
                    onSubmitted: () => _submit(auth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const MessageBanner.info(
              'Şifren cihazda düz metin olarak tutulmaz; salt eklenip '
              'hashlenerek saklanır.',
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              MessageBanner.error(auth.errorMessage!),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AsyncPrimaryButton(
              label: 'Üye Ol',
              isLoading: auth.isBusy,
              onPressed: () => _submit(auth),
            ),
            const SizedBox(height: AppSpacing.sm),
            AuthFooterLink(
              question: 'Zaten hesabın var mı?',
              actionLabel: 'Giriş Yap',
              onPressed:
                  auth.isBusy ? null : () => Navigator.of(context).maybePop(),
            ),
          ],
        );
      },
    );
  }
}
