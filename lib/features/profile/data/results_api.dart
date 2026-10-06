import '../../../core/network/api_service.dart';
import '../domain/remote_stats.dart';

/// `/results` uçlarının ince sarmalayıcısı.
class ResultsApi {
  const ResultsApi(this._api);

  final ApiService _api;

  /// Çözülen testin skorunu sunucuya yazar.
  ///
  /// `user_id` gönderilmez; sunucu onu JWT'den okur.
  Future<void> submitResult({
    required int testId,
    required int score,
    DateTime? completedAt,
  }) async {
    await _api.postJson(
      '/results',
      body: {
        'test_id': testId,
        'score': score,
        if (completedAt != null)
          'completed_at': completedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<RemoteStats> fetchStats() async {
    return RemoteStats.fromJson(await _api.getJson('/results/stats'));
  }
}
