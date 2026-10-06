import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../domain/ai_message.dart';

/// Fotoğraf seçme işini soyutlar.
///
/// Testler platform eklentisine gitmesin diye arayüz üzerinden çalışıyoruz.
abstract interface class ImagePickerService {
  /// Kamera ya da galeriden bir görsel alır; kullanıcı vazgeçerse `null`.
  Future<AiAttachment?> pick({required bool fromCamera});
}

/// Cihazın kamera/galerisini kullanan gerçek uygulama.
class DeviceImagePicker implements ImagePickerService {
  DeviceImagePicker([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();

  /// Ollama'ya gönderilen base64 gövdesini makul tutmak için küçültme.
  /// Araç parçasını tanımak için 1024 px yeterli.
  static const double _maxWidth = 1024;
  static const int _quality = 80;

  final ImagePicker _picker;

  @override
  Future<AiAttachment?> pick({required bool fromCamera}) async {
    final file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: _maxWidth,
      imageQuality: _quality,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();

    return AiAttachment(
      fileName: file.name,
      source: fromCamera ? 'Kamera' : 'Galeri',
      base64Data: base64Encode(bytes),
    );
  }
}
