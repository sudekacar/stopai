import 'package:flutter/foundation.dart';

import '../../../core/safe_notifier.dart';

import '../../../core/network/api_exception.dart';
import '../data/stats_repository.dart';
import '../domain/quiz_stats.dart';
import '../domain/remote_stats.dart';
import '../domain/test_attempt.dart';

/// Profil ekranının beslendiği istatistik durumu.
///
/// İki kaynak birlikte kullanılır: toplu sayılar sunucudan (cihazlar arası
/// doğru kaynak), konu bazlı kırılım cihazdaki ayrıntılı kayıtlardan.
class StatsController extends ChangeNotifier with SafeNotifier {
  StatsController(this._repository);

  final StatsRepository _repository;

  QuizStats _local = QuizStats.empty;
  RemoteStats _remote = RemoteStats.empty;
  bool _isLoading = false;
  bool _hasRemoteData = false;
  String? _errorMessage;
  int _refreshEpoch = 0;

  /// Cihazdaki denemeler; konu bazlı başarı buradan hesaplanır.
  QuizStats get local => _local;

  /// Sunucudaki toplu istatistikler.
  RemoteStats get remote => _remote;

  bool get isLoading => _isLoading;

  /// Sunucudan en az bir kez veri alındı mı.
  bool get hasRemoteData => _hasRemoteData;

  String? get errorMessage => _errorMessage;

  /// Gönderilmeyi bekleyen sonuç sayısı (çevrimdışı çözülen testler).
  int get pendingCount => _repository.pendingCount;

  /// Hiç test çözülmemiş mi (her iki kaynağa göre).
  bool get isEmpty => _remote.isEmpty && _local.isEmpty;

  /// Oturum değiştiğinde çağrılır.
  Future<void> loadFor(String? email) async {
    _repository.setUser(email);
    _local = _repository.loadLocal();
    final cached = _repository.loadCachedRemote();
    _remote = cached ?? RemoteStats.empty;
    _hasRemoteData = cached != null;
    _errorMessage = null;
    safeNotifyListeners();

    if (email == null) return;

    await _repository.syncPending();
    await refresh();
  }

  /// Sunucudaki istatistikleri yeniden okur.
  ///
  /// Üst üste çağrılırsa son istek kazanır: çek-bırak yenileme, oturum
  /// değişince başlayan yükleme ile çakışmasın.
  Future<void> refresh() async {
    final epoch = ++_refreshEpoch;
    _isLoading = true;
    _errorMessage = null;
    safeNotifyListeners();

    try {
      final remote = await _repository.fetchRemote();
      if (epoch != _refreshEpoch) return;
      _remote = remote;
      _hasRemoteData = true;
    } on ApiException catch (error) {
      if (epoch != _refreshEpoch) return;
      // Çevrimdışıyken profil boş görünmesin: önbellek + yerel veriyle devam.
      final cached = _repository.loadCachedRemote();
      if (cached != null) {
        _remote = cached;
        _hasRemoteData = true;
      }
      _errorMessage = error.message;
    } finally {
      if (epoch == _refreshEpoch) {
        _isLoading = false;
        safeNotifyListeners();
      }
    }
  }

  /// Test bitince çağrılır: cihaza yazar, sunucuya gönderir, özeti tazeler.
  Future<void> recordAttempt(TestAttempt attempt) async {
    final result = await _repository.saveAttempt(attempt);
    _local = result.local;
    safeNotifyListeners();

    if (result.synced) {
      await refresh();
    }
  }

  /// Bağlantı gelince kuyruğu boşaltır ve özeti tazeler.
  Future<void> syncWhenOnline() async {
    if (_repository.pendingCount > 0) {
      await _repository.syncPending();
    }
    await refresh();
  }

  /// Bir testin en iyi skoru: sunucu verisi varsa ondan, yoksa cihazdan.
  int? bestScoreFor(int testNumber) {
    final remoteBest = _remote.breakdownFor(testNumber)?.bestScore;
    if (remoteBest != null) return remoteBest;
    return _local.bestAttemptFor(testNumber)?.successPercentage;
  }

  /// Profilde gösterilen toplam sayılar; sunucu verisi yoksa yerelden.
  int get completedTestCount => _hasRemoteData
      ? _remote.completedTestCount
      : _local.completedTestCount;

  int get totalAttempts =>
      _hasRemoteData ? _remote.totalAttempts : _local.attemptCount;

  int get averageScore => _hasRemoteData
      ? _remote.averageScore
      : _local.averageSuccessPercentage;

  int get bestScore =>
      _hasRemoteData ? _remote.bestScore : _local.bestSuccessPercentage;

  int get totalQuestions => _local.totalQuestions;

  DateTime? get lastCompletedAt =>
      _remote.lastCompletedAt ?? _local.lastAttempt?.completedAt;

  Future<void> clear() async {
    await _repository.clearLocal();
    _local = QuizStats.empty;
    safeNotifyListeners();
  }
}
