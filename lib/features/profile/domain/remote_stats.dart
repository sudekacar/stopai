import 'test_attempt.dart';

/// Bir test için sunucudan gelen özet.
class RemoteTestBreakdown {
  const RemoteTestBreakdown({
    required this.testId,
    required this.attempts,
    required this.bestScore,
    required this.lastScore,
    required this.lastCompletedAt,
  });

  final int testId;
  final int attempts;
  final int bestScore;
  final int lastScore;
  final DateTime lastCompletedAt;

  bool get passed => bestScore >= TestAttempt.passingPercentage;

  Map<String, dynamic> toJson() => {
        'test_id': testId,
        'attempts': attempts,
        'best_score': bestScore,
        'last_score': lastScore,
        'last_completed_at': lastCompletedAt.toIso8601String(),
      };

  static RemoteTestBreakdown fromJson(Map<String, dynamic> json) {
    return RemoteTestBreakdown(
      testId: _asInt(json['test_id']),
      attempts: _asInt(json['attempts']),
      bestScore: _asInt(json['best_score']),
      lastScore: _asInt(json['last_score']),
      lastCompletedAt:
          DateTime.tryParse(json['last_completed_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// `GET /results/stats` yanıtı.
///
/// Sunucu yalnızca test numarası ve skoru sakladığı için konu (kategori)
/// kırılımı burada yoktur; onu cihazdaki yerel kayıtlardan hesaplıyoruz.
class RemoteStats {
  const RemoteStats({
    required this.totalAttempts,
    required this.completedTestCount,
    required this.averageScore,
    required this.bestScore,
    required this.passedAttempts,
    required this.lastCompletedAt,
    required this.perTest,
  });

  static const RemoteStats empty = RemoteStats(
    totalAttempts: 0,
    completedTestCount: 0,
    averageScore: 0,
    bestScore: 0,
    passedAttempts: 0,
    lastCompletedAt: null,
    perTest: [],
  );

  final int totalAttempts;
  final int completedTestCount;
  final int averageScore;
  final int bestScore;
  final int passedAttempts;
  final DateTime? lastCompletedAt;
  final List<RemoteTestBreakdown> perTest;

  bool get isEmpty => totalAttempts == 0;

  /// Bir testin sunucudaki özeti; hiç çözülmediyse `null`.
  RemoteTestBreakdown? breakdownFor(int testId) {
    for (final item in perTest) {
      if (item.testId == testId) return item;
    }
    return null;
  }

  static RemoteStats fromJson(Map<String, dynamic> json) {
    final rawPerTest = json['per_test'];

    return RemoteStats(
      totalAttempts: _asInt(json['total_attempts']),
      completedTestCount: _asInt(json['completed_test_count']),
      averageScore: _asInt(json['average_score']),
      bestScore: _asInt(json['best_score']),
      passedAttempts: _asInt(json['passed_attempts']),
      lastCompletedAt:
          DateTime.tryParse(json['last_completed_at'] as String? ?? ''),
      perTest: rawPerTest is List
          ? [
              for (final item in rawPerTest)
                if (item is Map<String, dynamic>)
                  RemoteTestBreakdown.fromJson(item),
            ]
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'total_attempts': totalAttempts,
        'completed_test_count': completedTestCount,
        'average_score': averageScore,
        'best_score': bestScore,
        'passed_attempts': passedAttempts,
        'last_completed_at': lastCompletedAt?.toIso8601String(),
        'per_test': [
          for (final item in perTest) item.toJson(),
        ],
      };
}

int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;
