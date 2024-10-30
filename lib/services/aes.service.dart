import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

class AESService {
  int keySize; // Güvenlik seviyesi için (128/192/256)
  late encrypt.Key _key; // AES için kullanılacak anahtar
  List<Uint8List> _sourceKeys =
      []; // QR kod, barkod vs. kaynaklardan gelen veriler
  static const int ivLength = 16; // IV uzunluğu AES'te 16 byte olmak zorunda

  // Başlangıçta güvenlik seviyesini belirle (varsayılan 128 bit)
  AESService({this.keySize = 128});

  // Bu fonksiyon her şifreleme işleminde yeni bir rastgele IV üretiyor
  Uint8List _generateRandomIV() {
    // Random.secure() kullanıyoruz çünkü normal Random güvenli değilmiş
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(ivLength, (i) => random.nextInt(256)));
  }

  // Güvenlik seviyesini değiştirmek için bu fonksiyonu kullanıyoruz
  void changeSecurityLevel(int newKeySize) {
    // Sadece geçerli değerleri kabul et
    if (![128, 192, 256].contains(newKeySize)) {
      throw Exception('Geçersiz anahtar boyutu! 128, 192 veya 256 olmalı.');
    }
    keySize = newKeySize;

    // Eğer daha önce kaynak seçildiyse anahtarı yeniden üret
    if (_sourceKeys.isNotEmpty) {
      generateKeyFromSources(_sourceKeys);
    }
  }

  // Bu fonksiyon seçilen iki kaynaktan (QR, barkod vs.) anahtar üretiyor
  void generateKeyFromSources(List<Uint8List> sources) {
    if (sources.length != 2) {
      throw Exception('Tam olarak 2 veri kaynağı gerekli!');
    }

    // Kaynakları kopyalayıp saklıyoruz, belki lazım olur diye
    _sourceKeys = List.from(sources);

    // İki kaynağı XOR ile birleştiriyoruz
    Uint8List combinedSource = _combineSources(sources);

    var hash = sha256.convert(combinedSource);
    var keyBytes = Uint8List.fromList(hash.bytes);

    // Anahtar boyutunu ayarlıyoruz (128/192/256 bit için)
    int requiredLength = keySize ~/ 8; // bit'ten byte'a çevirmek için
    if (keyBytes.length < requiredLength) {
      keyBytes = _padKey(keyBytes, requiredLength);
    } else if (keyBytes.length > requiredLength) {
      keyBytes = keyBytes.sublist(0, requiredLength);
    }

    // Son olarak encrypt paketi için Key objesi oluştur
    _key = encrypt.Key(keyBytes);
  }

  // İki kaynağı birleştirmek için XOR kullanıyoruz
  Uint8List _combineSources(List<Uint8List> sources) {
    // En uzun kaynağın boyunu al
    int maxLength = sources.map((s) => s.length).reduce(max);
    var combined = Uint8List(maxLength);

    // Her byte'ı XOR'la
    for (var i = 0; i < maxLength; i++) {
      combined[i] =
          sources[0][i % sources[0].length] ^ sources[1][i % sources[1].length];
    }
    return combined;
  }

  // Bu fonksiyon anahtarı istenilen boyuta getiriyor
  // Padding
  Uint8List _padKey(Uint8List key, int desiredLength) {
    var padded = Uint8List(desiredLength);
    padded.setAll(0, key); // Önce mevcut anahtarı kopyala

    // Kalan kısmı PKCS7 padding ile doldur
    var paddingLength = desiredLength - key.length;
    for (var i = key.length; i < desiredLength; i++) {
      padded[i] = paddingLength;
    }
    return padded;
  }

  // Dosyayı şifrelemek için bu fonksiyonu kullanıyoruz
  Future<Uint8List> encryptFile(Uint8List fileBytes) async {
    try {
      // Her seferinde yeni bir IV üret
      final iv = _generateRandomIV();

      // AES şifreleme objesi oluştur
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));

      // Dosyayı şifrele
      final encrypted = encrypter.encryptBytes(fileBytes, iv: encrypt.IV(iv));

      return Uint8List.fromList([...iv, ...encrypted.bytes]);
    } catch (e) {
      debugPrint('Şifreleme hatası: $e');
      rethrow;
    }
  }

  // Şifreli dosyayı çözmek için bu fonksiyonu kullanıyoruz
  Future<Uint8List> decryptFile(Uint8List encryptedBytes) async {
    try {
      // Önce verinin yeterli uzunlukta olduğunu kontrol et
      if (encryptedBytes.length < ivLength) {
        throw Exception('Şifreli veri çok kısa! IV eksik olabilir.');
      }

      // Baştaki IV'yi al
      final iv = encryptedBytes.sublist(0, ivLength);
      // Geriye kalan kısım şifreli veri
      final encryptedData = encryptedBytes.sublist(ivLength);

      // AES ile şifreyi çöz
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final decrypted = encrypter.decryptBytes(encrypt.Encrypted(encryptedData),
          iv: encrypt.IV(iv));

      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('Şifre çözme hatası: $e');
      rethrow;
    }
  }

  // Debug
  void printDebugInfo() {
    debugPrint('AES Güvenlik Seviyesi: $keySize bit');
    if (_sourceKeys.isNotEmpty) {
      debugPrint('Kaynak 1 Hash: ${sha256.convert(_sourceKeys[0]).bytes}');
      debugPrint('Kaynak 2 Hash: ${sha256.convert(_sourceKeys[1]).bytes}');
      debugPrint(
          'Combined Hash: ${sha256.convert(_combineSources(_sourceKeys)).bytes}');
    }
  }
}
