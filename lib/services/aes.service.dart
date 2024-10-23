import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

class AESService {
  int keySize; // late kaldırıldı
  late encrypt.Key _key;
  late encrypt.IV _iv;
  List<Uint8List> _sourceKeys = [];

  // Constructor'da keySize parametresi opsiyonel ve varsayılan değer 256
  AESService({this.keySize = 256}) {
    _iv = encrypt.IV.fromSecureRandom(16);
  }

  // Güvenlik seviyesini değiştirme fonksiyonu güncellendi
  void changeSecurityLevel(int newKeySize) {
    if (![128, 192, 256].contains(newKeySize)) {
      throw Exception('Geçersiz anahtar boyutu. 128, 192 veya 256 olmalı.');
    }
    keySize = newKeySize;
    if (_sourceKeys.isNotEmpty) {
      generateKeyFromSources(_sourceKeys);
    }
  }

  void generateKeyFromSources(List<Uint8List> sources) {
    if (sources.length != 2) {
      throw Exception('Tam olarak 2 veri kaynağı gerekli');
    }

    _sourceKeys = List.from(sources); // sources'ı kopyala
    Uint8List combinedSource = _combineSources(sources);

    var hash = sha256.convert(combinedSource);
    var keyBytes = Uint8List.fromList(hash.bytes);

    int requiredLength = keySize ~/ 8;
    if (keyBytes.length < requiredLength) {
      keyBytes = _padKey(keyBytes, requiredLength);
    } else if (keyBytes.length > requiredLength) {
      keyBytes = keyBytes.sublist(0, requiredLength);
    }

    _key = encrypt.Key(keyBytes);
    // IV'yi sıfırlama - bu sayede aynı veri kaynakları aynı şifreleme/çözme sonucunu verecek
    _iv = encrypt.IV.fromLength(16);
  }

  Uint8List _combineSources(List<Uint8List> sources) {
    int maxLength = sources.map((s) => s.length).reduce(max);
    var combined = Uint8List(maxLength);

    for (var i = 0; i < maxLength; i++) {
      combined[i] =
          sources[0][i % sources[0].length] ^ sources[1][i % sources[1].length];
    }
    return combined;
  }

  Uint8List _padKey(Uint8List key, int desiredLength) {
    var padded = Uint8List(desiredLength);
    padded.setAll(0, key);

    var paddingLength = desiredLength - key.length;
    for (var i = key.length; i < desiredLength; i++) {
      padded[i] = paddingLength;
    }

    return padded;
  }

  Future<Uint8List> encryptFile(Uint8List fileBytes) async {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final encrypted = encrypter.encryptBytes(fileBytes, iv: _iv);
      return Uint8List.fromList(encrypted.bytes);
    } catch (e) {
      debugPrint('Şifreleme hatası: $e');
      rethrow;
    }
  }

  Future<Uint8List> decryptFile(Uint8List encryptedBytes) async {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final decrypted =
          encrypter.decryptBytes(encrypt.Encrypted(encryptedBytes), iv: _iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('Şifre çözme hatası: $e');
      rethrow;
    }
  }

  // Yardımcı metodlar
  Uint8List generateKeyFromQR(String qrData) {
    var bytes = Uint8List.fromList(qrData.codeUnits);
    return Uint8List.fromList(sha256.convert(bytes).bytes);
  }

  Uint8List generateKeyFromImage(Uint8List imageBytes) {
    return Uint8List.fromList(sha256.convert(imageBytes).bytes);
  }

  Uint8List generateKeyFromAudio(Uint8List audioBytes) {
    return Uint8List.fromList(sha256.convert(audioBytes).bytes);
  }

  Uint8List generateKeyFromBarcode(String barcodeData) {
    var bytes = Uint8List.fromList(barcodeData.codeUnits);
    return Uint8List.fromList(sha256.convert(bytes).bytes);
  }

  // Getter'lar
  encrypt.IV get iv => _iv;

  void printDebugInfo() {
    debugPrint('AES Güvenlik Seviyesi: $keySize bit');
    debugPrint('IV: ${_iv.bytes}');
    if (_sourceKeys.isNotEmpty) {
      debugPrint('Kaynak 1 Hash: ${sha256.convert(_sourceKeys[0]).bytes}');
      debugPrint('Kaynak 2 Hash: ${sha256.convert(_sourceKeys[1]).bytes}');
    }
  }
}
