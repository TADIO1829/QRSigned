import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoUtils {
  static final _key = encrypt.Key.fromUtf8('12345678901234567890123456789012');
  static final _iv = encrypt.IV.fromUtf8('1234567890123456');
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));

  static String encryptText(String plainText) {
    // ✅ MANEJAR TEXTO VACÍO
    if (plainText.isEmpty) {
      return '';
    }
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  static String decryptText(String encryptedText) {
    // ✅ MANEJAR TEXTO VACÍO
    if (encryptedText.isEmpty) {
      return '';
    }
    try {
      return _encrypter.decrypt64(encryptedText, iv: _iv);
    } catch (_) {
      return '[dato inválido]';
    }
  }
}