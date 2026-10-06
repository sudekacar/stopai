import '../../../core/network/api_exception.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/quiz_stats.dart';
import '../domain/remote_stats.dart';
import '../domain/test_attempt.dart';
import 'results_api.dart';

/// Test sonuçlarını sunucuya yazar, istatistikleri sunucudan okur.
///
/// Yerel kayıt tamamen kaldırılmadı çünkü iki işi var:
/// 1. Sunucu yalnızca test numarası ve skoru tutuyor; profildeki konu bazlı
///    başarı kırılımı ancak cihazdaki ayrıntılı kayıtlardan hesaplanabiliyor.
/// 2. Çevrimdışı çözülen testler kuyruğa alınıp bağlantı gelince gönderiliyor.
class StatsRepository {
  StatsRepository(this._api, this._store);

  static const String _attemptsPrefix = 'stats.attempts.';
  static const String _pendingPrefix = 'stats.pending.';
  static const String _remotePrefix = 'stats.remote.';

  /// Profilde tutulan en fazla deneme sayısı; daha eskiler düşer.
  static const int _maxAttempts = 100;

  final ResultsApi _api;
  final KeyValueStore _store;

  String? _userKey;

  void setUser(String? email) => _userKey = email;

  // ------------------------------------------------------- Yerel kayıtlar

  /// Cihazdaki denemeler (konu kırılımı buradan gelir).
  QuizStats loadLocal() {
    if (_userKey == null) return QuizStats.empty;

    final attempts = _readAttempts(_attemptsKey);
    attempts.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return QuizStats(List.unmodifiable(attempts));
  }

  /// Sonucu önce cihaza yazar, sonra sunucuya göndermeyi dener.
  ///
  /// Gönderim başarısız olursa kayıt kuyruğa alınır; skor kaybolmaz.
  Future<({QuizStats local, bool synced})> saveAttempt(
    TestAttempt attempt,
  ) async {
    if (_userKey == null) {
      return (local: QuizStats.empty, synced: false);
    }

    final attempts = [attempt, ..._readAttempts(_attemptsKey)]
        .take(_maxAttempts)
        .toList();
    await _writeAttempts(_attemptsKey, attempts);

    var synced = true;
    try {
      await _api.submitResult(
        testId: attempt.testNumber,
        score: attempt.successPercentage,
        completedAt: attempt.completedAt,
      );
    } on ApiException {
      await _enqueue(attempt);
      synced = false;
    }

    return (
      local: QuizStats(List.unmodifiable(attempts)),
      synced: synced,
    );
  }

  // --------------------------------------------------------------- Sunucu

  /// Sunucudaki toplu istatistikler.
  Future<RemoteStats> fetchRemote() async {
    final remote = await _api.fetchStats();
    await cacheRemote(remote);
    return remote;
  }

  /// Çevrimdışı profil için son başarılı sunucu özeti.
  RemoteStats? loadCachedRemote() {
    if (_userKey == null) return null;
    final json = _store.getJson(_remoteKey);
    if (json == null) return null;
    try {
      return RemoteStats.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> cacheRemote(RemoteStats stats) async {
    if (_userKey == null) return;
    await _store.setJson(_remoteKey, stats.toJson());
  }

  /// Kuyrukta bekleyen sonuçları gönderir, gönderilenleri kuyruktan düşürür.
  ///
  /// Dönen değer: kaç kayıt gönderildi.
  Future<int> syncPending() async {
    if (_userKey == null) return 0;

    final pending = _readAttempts(_pendingKey);
    if (pending.isEmpty) return 0;

    final remaining = <TestAttempt>[];
    var sent = 0;

    for (final attempt in pending) {
      try {
        await _api.submitResult(
          testId: attempt.testNumber,
          score: attempt.successPercentage,
          completedAt: attempt.completedAt,
        );
        sent++;
      } on ApiException catch (error) {
        // Ağ hatasında sıradakileri denemek anlamsız; kalanları koru.
        remaining.add(attempt);
        if (error.isNetworkError) {
          remaining.addAll(pending.skip(pending.indexOf(attempt) + 1));
          break;
        }
      }
    }

    await _writeAttempts(_pendingKey, remaining);
    return sent;
  }

  int get pendingCount =>
      _userKey == null ? 0 : _readAttempts(_pendingKey).length;

  Future<void> clearLocal() async {
    if (_userKey == null) return;
    await _store.remove(_attemptsKey);
    await _store.remove(_pendingKey);
    await _store.remove(_remoteKey);
  }

  // ---------------------------------------------------------- Yardımcılar

  Future<void> _enqueue(TestAttempt attempt) async {
    final pending = [..._readAttempts(_pendingKey), attempt];
    await _writeAttempts(_pendingKey, pending.take(_maxAttempts).toList());
  }

  List<TestAttempt> _readAttempts(String key) {
    final json = _store.getJson(key);
    final raw = json?['attempts'];
    if (raw is! List) return [];

    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) TestAttempt.fromJson(item),
    ];
  }

  Future<void> _writeAttempts(String key, List<TestAttempt> attempts) {
    return _store.setJson(key, {
      'attempts': [for (final item in attempts) item.toJson()],
    });
  }

  String get _attemptsKey => '$_attemptsPrefix${_userKey ?? 'anonim'}';
  String get _pendingKey => '$_pendingPrefix${_userKey ?? 'anonim'}';
  String get _remoteKey => '$_remotePrefix${_userKey ?? 'anonim'}';
}
