import 'package:flutter_test/flutter_test.dart';
import 'package:qrsigned/utils/crypto_utils.dart';
import 'package:qrsigned/cliente_global.dart';
import 'package:qrsigned/usuario_global.dart';
import 'dart:io';


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
      buffer.writeln('  ${testMap['passed'] ? 'Ok' : 'Algo fallo'} ${testMap['name']}');
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

  group(' CryptoUtils Pruebas', () {
    tearDown(() {
     
    });

    runTest(' CryptoUtils', 'encriptado y desencriptado de texto normal', () {
      const text = 'Hola Mundo';
      final encrypted = CryptoUtils.encryptText(text);
      final decrypted = CryptoUtils.decryptText(encrypted);
      expect(decrypted, text);
    });

    runTest(' CryptoUtils', 'encriptado de texto vacio devuelve texto vacio', () {
      final encrypted = CryptoUtils.encryptText('');
      expect(encrypted, '');
    });

    runTest(' CryptoUtils', 'desencriptado de texto vacio devuelve texto vacio', () {
      final decrypted = CryptoUtils.decryptText('');
      expect(decrypted, '');
    });

    runTest(' CryptoUtils', 'encriptado y desencriptado de números', () {
      const text = '1234567890';
      final encrypted = CryptoUtils.encryptText(text);
      final decrypted = CryptoUtils.decryptText(encrypted);
      expect(decrypted, text);
    });

    runTest(' CryptoUtils', 'encriptado y desencriptado de caracteres especiales', () {
      const text = 'Holaaaaaaaaaaa como tas??';
      final encrypted = CryptoUtils.encryptText(text);
      final decrypted = CryptoUtils.decryptText(encrypted);
      expect(decrypted, text);
    });

    runTest(' CryptoUtils', 'textos diferentes producen resultados encriptados diferentes', () {
      const text1 = 'text1';
      const text2 = 'text2';
      final encrypted1 = CryptoUtils.encryptText(text1);
      final encrypted2 = CryptoUtils.encryptText(text2);
      expect(encrypted1, isNot(encrypted2));
    });
  });

  group(' ClienteGlobal Tests', () {
    tearDown(() {
      ClienteGlobal.seleccionado = null;
    });

    runTest(' ClienteGlobal', 'cliente seleccionado inicialmente debe ser nulo', () {
      expect(ClienteGlobal.seleccionado, isNull);
    });

    runTest(' ClienteGlobal', 'seleccionar cliente debe almacenar datos del cliente', () {
      final testClient = {
        '_id': '123',
        'nombre': 'Juan Pérez',
        'cedula': 'test_cedula',
      };
      ClienteGlobal.seleccionar(testClient);
      expect(ClienteGlobal.seleccionado, testClient);
      expect(ClienteGlobal.seleccionado!['nombre'], 'Juan Pérez');
    });

    runTest(' ClienteGlobal', 'clear selection works', () {
      final testClient = {'_id': '123', 'nombre': 'Test'};
      ClienteGlobal.seleccionar(testClient);
      ClienteGlobal.seleccionado = null;
      expect(ClienteGlobal.seleccionado, isNull);
    });

    runTest(' ClienteGlobal', 'múltiples selecciones mantienen el último cliente', () {
      final client1 = {'_id': '1', 'nombre': 'Cliente 1'};
      final client2 = {'_id': '2', 'nombre': 'Cliente 2'};
      ClienteGlobal.seleccionar(client1);
      ClienteGlobal.seleccionar(client2);
      expect(ClienteGlobal.seleccionado!['nombre'], 'Cliente 2');
    });
  });

  group(' UsuarioGlobal Tests', () {
    tearDown(() {
      UsuarioGlobal.setUsuario(tipoUsuario: '', nombreUsuario: '');
    });

    runTest(' UsuarioGlobal', 'valores iniciales deben estar vacíos', () {
      expect(UsuarioGlobal.tipoUsuario, '');
      expect(UsuarioGlobal.nombreUsuario, '');
      expect(UsuarioGlobal.esAdmin, false);
      expect(UsuarioGlobal.esUsuario, false);
    });

    runTest(' UsuarioGlobal', 'establecer usuario admin funciona correctamente', () {
      UsuarioGlobal.setUsuario(tipoUsuario: "admin", nombreUsuario: "Esthefany");
      expect(UsuarioGlobal.tipoUsuario, "admin");
      expect(UsuarioGlobal.nombreUsuario, "Esthefany");
      expect(UsuarioGlobal.esAdmin, true);
      expect(UsuarioGlobal.esUsuario, false);
    });

    runTest(' UsuarioGlobal', 'establecer usuario regular funciona correctamente', () {
      UsuarioGlobal.setUsuario(tipoUsuario: "usuario", nombreUsuario: "Tadeo");
      expect(UsuarioGlobal.tipoUsuario, "usuario");
      expect(UsuarioGlobal.nombreUsuario, "Tadeo");
      expect(UsuarioGlobal.esAdmin, false);
      expect(UsuarioGlobal.esUsuario, true);
    });

    runTest(' UsuarioGlobal', 'detección de admin es precisa', () {
      UsuarioGlobal.setUsuario(tipoUsuario: "admin", nombreUsuario: "Test");
      expect(UsuarioGlobal.esAdmin, true);
      UsuarioGlobal.setUsuario(tipoUsuario: "usuario", nombreUsuario: "Test");
      expect(UsuarioGlobal.esAdmin, false);
    });

    runTest(' UsuarioGlobal', 'detección de usuario es precisa', () {
      UsuarioGlobal.setUsuario(tipoUsuario: "usuario", nombreUsuario: "Test");
      expect(UsuarioGlobal.esUsuario, true);
      UsuarioGlobal.setUsuario(tipoUsuario: "admin", nombreUsuario: "Test");
      expect(UsuarioGlobal.esUsuario, false);
    });
  });

  group(' Simulación de Login ', () {
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

    runTest(' Simulación de Login', 'admin login con credenciales correctas', () {
      expect(login("admin@admin.com", "made"), "admin");
    });

    runTest(' Simulación de Login', 'usuario login con credenciales correctas', () {
      expect(login("usuario@gmail.com", "made"), "usuario");
    });

    runTest(' Simulación de Login', 'login con credenciales incorrectas falla', () {
      expect(login("wrong@email.com", "wrong"), "error");
    });

    runTest(' Simulación de Login', 'email no distingue entre mayúsculas y minúsculas', () {
      expect(login("ADMIN@ADMIN.COM", "made"), "admin");
    });

    runTest(' Simulación de Login', 'el recorte de email funciona', () {
      expect(login("  admin@admin.com  ", "made"), "admin");
    });

    runTest(' Simulación de Login', 'contraseña incorrecta con email correcto falla', () {
      expect(login("admin@admin.com", "wrong"), "error");
    });
  });

  group(' Pruebas de Validación de Datos ', () {
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

    runTest(' Validación de Datos', 'email válido pasa la validación', () {
      expect(validateEmail('test@test.com'), isNull);
    });

    runTest(' Validación de Datos', 'email vacío falla la validación', () {
      expect(validateEmail(''), 'Email requerido');
    });

    runTest(' Validación de Datos', 'formato de email inválido falla', () {
      expect(validateEmail('invalid'), 'Email inválido');
    });

    runTest(' Validación de Datos', 'contraseña válida pasa la validación', () {
      expect(validatePassword('password123'), isNull);
    });

    runTest(' Validación de Datos', 'contraseña corta falla la validación', () {
      expect(validatePassword('12'), 'Mínimo 3 caracteres');
    });
  });

  
  
}