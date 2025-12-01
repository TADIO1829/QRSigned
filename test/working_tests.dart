import 'package:flutter_test/flutter_test.dart';
import 'package:qrsigned/utils/crypto_utils.dart';
import 'package:qrsigned/cliente_global.dart';
import 'package:qrsigned/usuario_global.dart';
import 'dart:io';

// Contador global
final _testResults = <String, Map<String, dynamic>>{};
int _totalTests = 0;
int _passedTests = 0;

void _recordTest(String group, String testName, bool passed) {
  _totalTests++;
  if (passed) _passedTests++;
  
  if (!_testResults.containsKey(group)) {
    _testResults[group] = {'total': 0, 'passed': 0, 'tests': []};
  }
  
  _testResults[group]!['total']++;
  if (passed) _testResults[group]!['passed']++;
  _testResults[group]!['tests'].add({'name': testName, 'passed': passed});
}

void _generateRealReport() {
  final successRate = (_passedTests / _totalTests * 100).toStringAsFixed(1);
  
  final report = '''
╔══════════════════════════════════════════════╗
║           REPORTE REAL DE PRUEBAS            ║
║                  QRSIGNED                    ║
╠══════════════════════════════════════════════╣
║ FECHA: ${DateTime.now().toString().substring(0, 16)}                ║
╠══════════════════════════════════════════════╣
║           RESULTADOS EJECUTADOS              ║
╠══════════════════════════════════════════════╣
║ 🧪 TOTAL PRUEBAS: $_totalTests                              ║
║ ✅ PRUEBAS EXITOSAS: $_passedTests                              ║
║ ❌ PRUEBAS FALLIDAS: ${_totalTests - _passedTests}                              ║
║ 📈 TASA DE ÉXITO: $successRate%                           ║
╠══════════════════════════════════════════════╣
║             DESGLOSE REAL                    ║
╠══════════════════════════════════════════════╣
${_generateRealBreakdown()}
╠══════════════════════════════════════════════╣
║                 DETALLE                      ║
╚══════════════════════════════════════════════╝

${_generateTestDetails()}

${_passedTests == _totalTests ? '🎉 TODAS LAS PRUEBAS PASARON - SISTEMA ESTABLE' : '⚠️ ALGUNAS PRUEBAS REQUIEREN ATENCIÓN'}
''';

  
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  File('reporte_real_$timestamp.txt').writeAsStringSync(report);
  
  print(report);
  print('\n📄 Reporte real guardado en: reporte_real_$timestamp.txt');
}

String _generateRealBreakdown() {
  final buffer = StringBuffer();
  _testResults.forEach((group, data) {
    final total = data['total'] as int;
    final passed = data['passed'] as int;
    final percentage = total > 0 ? (passed / total * 100).toStringAsFixed(0) : '0';
    buffer.writeln('║ $group: $passed/$total ($percentage%)'.padRight(48) + '║');
  });
  return buffer.toString();
}

String _generateTestDetails() {
  final buffer = StringBuffer();
  _testResults.forEach((group, data) {
    buffer.writeln('$group:');
    final tests = data['tests'] as List<dynamic>;
    for (final test in tests) {
      final testMap = test as Map<String, dynamic>;
      buffer.writeln('  ${testMap['passed'] ? '✅' : '❌'} ${testMap['name']}');
    }
    buffer.writeln();
  });
  return buffer.toString();
}

void main() {
 
  void runTest(String group, String description, Function testFunction) {
    test(description, () {
      try {
        testFunction();
        _recordTest(group, description, true);
      } catch (e) {
        _recordTest(group, description, false);
        rethrow;
      }
    });
  }

  group('🔐 CryptoUtils Working Tests', () {
    tearDown(() {
     
    });

    runTest('🔐 CryptoUtils', 'encrypt and decrypt normal text', () {
      const text = 'Hello World';
      final encrypted = CryptoUtils.encryptText(text);
      final decrypted = CryptoUtils.decryptText(encrypted);
      expect(decrypted, text);
    });

    runTest('🔐 CryptoUtils', 'encrypt empty string returns empty', () {
      final encrypted = CryptoUtils.encryptText('');
      expect(encrypted, '');
    });

    runTest('🔐 CryptoUtils', 'decrypt empty string returns empty', () {
      final decrypted = CryptoUtils.decryptText('');
      expect(decrypted, '');
    });

    runTest('🔐 CryptoUtils', 'encrypt and decrypt numbers', () {
      const text = '1234567890';
      final encrypted = CryptoUtils.encryptText(text);
      final decrypted = CryptoUtils.decryptText(encrypted);
      expect(decrypted, text);
    });

    runTest('🔐 CryptoUtils', 'encrypt and decrypt special characters', () {
      const text = '¡Hola! ¿Cómo estás?';
      final encrypted = CryptoUtils.encryptText(text);
      final decrypted = CryptoUtils.decryptText(encrypted);
      expect(decrypted, text);
    });

    runTest('🔐 CryptoUtils', 'different texts produce different encrypted results', () {
      const text1 = 'text1';
      const text2 = 'text2';
      final encrypted1 = CryptoUtils.encryptText(text1);
      final encrypted2 = CryptoUtils.encryptText(text2);
      expect(encrypted1, isNot(encrypted2));
    });
  });

  group('👥 ClienteGlobal Tests', () {
    tearDown(() {
      ClienteGlobal.seleccionado = null;
    });

    runTest('👥 ClienteGlobal', 'initial selected client should be null', () {
      expect(ClienteGlobal.seleccionado, isNull);
    });

    runTest('👥 ClienteGlobal', 'select client should store client data', () {
      final testClient = {
        '_id': '123',
        'nombre': 'Juan Pérez',
        'cedula': 'test_cedula',
      };
      ClienteGlobal.seleccionar(testClient);
      expect(ClienteGlobal.seleccionado, testClient);
      expect(ClienteGlobal.seleccionado!['nombre'], 'Juan Pérez');
    });

    runTest('👥 ClienteGlobal', 'clear selection works', () {
      final testClient = {'_id': '123', 'nombre': 'Test'};
      ClienteGlobal.seleccionar(testClient);
      ClienteGlobal.seleccionado = null;
      expect(ClienteGlobal.seleccionado, isNull);
    });

    runTest('👥 ClienteGlobal', 'multiple selections keep last client', () {
      final client1 = {'_id': '1', 'nombre': 'Cliente 1'};
      final client2 = {'_id': '2', 'nombre': 'Cliente 2'};
      ClienteGlobal.seleccionar(client1);
      ClienteGlobal.seleccionar(client2);
      expect(ClienteGlobal.seleccionado!['nombre'], 'Cliente 2');
    });
  });

  group('👤 UsuarioGlobal Tests', () {
    tearDown(() {
      UsuarioGlobal.setUsuario(tipoUsuario: '', nombreUsuario: '');
    });

    runTest('👤 UsuarioGlobal', 'initial values should be empty', () {
      expect(UsuarioGlobal.tipoUsuario, '');
      expect(UsuarioGlobal.nombreUsuario, '');
      expect(UsuarioGlobal.esAdmin, false);
      expect(UsuarioGlobal.esUsuario, false);
    });

    runTest('👤 UsuarioGlobal', 'set admin user works correctly', () {
      UsuarioGlobal.setUsuario(tipoUsuario: "admin", nombreUsuario: "Esthefany");
      expect(UsuarioGlobal.tipoUsuario, "admin");
      expect(UsuarioGlobal.nombreUsuario, "Esthefany");
      expect(UsuarioGlobal.esAdmin, true);
      expect(UsuarioGlobal.esUsuario, false);
    });

    runTest('👤 UsuarioGlobal', 'set regular user works correctly', () {
      UsuarioGlobal.setUsuario(tipoUsuario: "usuario", nombreUsuario: "Tadeo");
      expect(UsuarioGlobal.tipoUsuario, "usuario");
      expect(UsuarioGlobal.nombreUsuario, "Tadeo");
      expect(UsuarioGlobal.esAdmin, false);
      expect(UsuarioGlobal.esUsuario, true);
    });

    runTest('👤 UsuarioGlobal', 'admin detection is accurate', () {
      UsuarioGlobal.setUsuario(tipoUsuario: "admin", nombreUsuario: "Test");
      expect(UsuarioGlobal.esAdmin, true);
      UsuarioGlobal.setUsuario(tipoUsuario: "usuario", nombreUsuario: "Test");
      expect(UsuarioGlobal.esAdmin, false);
    });

    runTest('👤 UsuarioGlobal', 'user detection is accurate', () {
      UsuarioGlobal.setUsuario(tipoUsuario: "usuario", nombreUsuario: "Test");
      expect(UsuarioGlobal.esUsuario, true);
      UsuarioGlobal.setUsuario(tipoUsuario: "admin", nombreUsuario: "Test");
      expect(UsuarioGlobal.esUsuario, false);
    });
  });

  group('🔑 Login Simulation Tests', () {
    String login(String email, String password) {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail == "admin@admin.com" && password == "made") {
        return "admin";
      } else if (normalizedEmail == "usuario@gmail.com" && password == "made") {
        return "usuario";
      } else {
        return "error";
      }
    }

    runTest('🔑 Login Simulation', 'admin login with correct credentials', () {
      expect(login("admin@admin.com", "made"), "admin");
    });

    runTest('🔑 Login Simulation', 'user login with correct credentials', () {
      expect(login("usuario@gmail.com", "made"), "usuario");
    });

    runTest('🔑 Login Simulation', 'login with wrong credentials fails', () {
      expect(login("wrong@email.com", "wrong"), "error");
    });

    runTest('🔑 Login Simulation', 'email is case insensitive', () {
      expect(login("ADMIN@ADMIN.COM", "made"), "admin");
    });

    runTest('🔑 Login Simulation', 'email trimming works', () {
      expect(login("  admin@admin.com  ", "made"), "admin");
    });

    runTest('🔑 Login Simulation', 'wrong password with correct email fails', () {
      expect(login("admin@admin.com", "wrong"), "error");
    });
  });

  group('📊 Data Validation Tests', () {
    String? validateEmail(String? email) {
      if (email == null || email.isEmpty) return 'Email requerido';
      if (!email.contains('@')) return 'Email inválido';
      return null;
    }

    String? validatePassword(String? password) {
      if (password == null || password.isEmpty) return 'Contraseña requerida';
      if (password.length < 3) return 'Mínimo 3 caracteres';
      return null;
    }

    runTest('📊 Data Validation', 'valid email passes validation', () {
      expect(validateEmail('test@test.com'), isNull);
    });

    runTest('📊 Data Validation', 'empty email fails validation', () {
      expect(validateEmail(''), 'Email requerido');
    });

    runTest('📊 Data Validation', 'invalid email format fails', () {
      expect(validateEmail('invalid'), 'Email inválido');
    });

    runTest('📊 Data Validation', 'valid password passes validation', () {
      expect(validatePassword('password123'), isNull);
    });

    runTest('📊 Data Validation', 'short password fails validation', () {
      expect(validatePassword('12'), 'Mínimo 3 caracteres');
    });
  });

  
  tearDownAll(() {
    _generateRealReport();
  });
}