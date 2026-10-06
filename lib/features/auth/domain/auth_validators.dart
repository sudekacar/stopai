/// Form alanlarının doğrulama kuralları.
///
/// Hem `TextFormField.validator` hem de repository tarafından kullanılır;
/// böylece arayüz atlansa bile kural tek yerde kalır.
abstract final class AuthValidators {
  static final RegExp _emailPattern =
      RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$');

  static const int minPasswordLength = 6;

  /// Geçerliyse `null`, değilse kullanıcıya gösterilecek mesaj döner.
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta adresi gerekli.';
    if (!_emailPattern.hasMatch(email)) return 'Geçerli bir e-posta girin.';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Şifre gerekli.';
    if (password.length < minPasswordLength) {
      return 'Şifre en az $minPasswordLength karakter olmalı.';
    }
    if (!password.contains(RegExp('[A-Za-zÇĞİÖŞÜçğıöşü]'))) {
      return 'Şifre en az bir harf içermeli.';
    }
    if (!password.contains(RegExp('[0-9]'))) {
      return 'Şifre en az bir rakam içermeli.';
    }
    return null;
  }

  /// Girişte sadece boş olup olmadığına bakılır; kural değişse bile eski
  /// kullanıcılar giriş yapabilsin.
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Şifre gerekli.';
    return null;
  }

  static String? displayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Ad soyad gerekli.';
    if (name.length < 2) return 'Ad soyad en az 2 karakter olmalı.';
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Şifreyi tekrar girin.';
    if (value != password) return 'Şifreler eşleşmiyor.';
    return null;
  }
}
