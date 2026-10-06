/// Bir şıkkın o anki görsel durumu.
///
/// Renklendirme kuralı: doğru olan her şey yeşil, kullanıcının seçtiği
/// yanlış şık mavi, geri kalan şıklar nötr.
enum AnswerOptionState {
  /// Henüz cevap verilmedi, şık tıklanabilir.
  idle,

  /// Kullanıcı bu şıkkı seçti ve doğruydu -> yeşil.
  selectedCorrect,

  /// Kullanıcı bu şıkkı seçti ve yanlıştı -> mavi.
  selectedWrong,

  /// Kullanıcı yanlış cevap verdi, doğru şık bu -> yeşil.
  revealedCorrect,

  /// Cevap verildi ama bu şık ilgisiz -> soluk.
  dimmed;

  bool get isCorrectTone =>
      this == selectedCorrect || this == revealedCorrect;

  bool get isWrongTone => this == selectedWrong;
}

/// Cevap sonrası gösterilecek geri bildirim şeridinin durumu.
enum AnswerFeedback { none, correct, wrong }
