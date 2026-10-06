import '../../purchase/domain/subscription_status.dart';

/// Oturumu açık kullanıcı.
///
/// [id], [email], [subscriptionStatus] ve [createdAt] sunucudan gelir.
/// [displayName] backend'de karşılığı olmadığı için yalnızca bu cihazda
/// tutulur; başka bir cihazda giriş yapıldığında e-postadan türetilir.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.subscriptionStatus,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String displayName;
  final SubscriptionStatus subscriptionStatus;
  final DateTime createdAt;

  /// Profilde gösterilen baş harfler.
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);

    if (parts.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  AppUser copyWith({
    String? displayName,
    SubscriptionStatus? subscriptionStatus,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      createdAt: createdAt,
    );
  }

  /// Çevrimdışı açılışta kullanılmak üzere diske yazılan biçim.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'subscription_status': subscriptionStatus.apiValue,
        'created_at': createdAt.toIso8601String(),
      };

  static AppUser fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      subscriptionStatus:
          SubscriptionStatus.fromApi(json['subscription_status'] as String?),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  /// Ad kaydı yoksa e-postanın kullanıcı adı kısmından okunabilir bir isim
  /// üretir: `ali.veli@x.com` -> `Ali Veli`.
  static String displayNameFromEmail(String email) {
    final localPart = email.split('@').first;
    final words = localPart
        .split(RegExp(r'[._\-+]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1));

    final name = words.join(' ').trim();
    return name.isEmpty ? email : name;
  }
}
