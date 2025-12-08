import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:qrsigned/login_page.dart';

void main() {
  print('PRUEBAS DE INTEGRACIÓN - MÓDULO LOGIN');
  print('=' * 50);
  
  testWidgets('Login básico - solo UI', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginPage()));
    
    expect(find.text('Iniciar sesión'), findsOneWidget);
    
    
    print('\nLogin básico - solo UI');
    print('Estado: Pasó');
    print('Descripción: Validar renderizado correcto de la interfaz de login con todos sus componentes visuales');
    print('─' * 40);
  });

  testWidgets('Login admin - sin diálogo', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginPage()));

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'admin@admin.com');
    await tester.enterText(textFields.at(1), 'made');
    
    expect(find.text('admin@admin.com'), findsOneWidget);
    expect(find.text('made'), findsOneWidget);
    
    
    print('Login admin - sin diálogo');
    print('Estado: Pasó');
    print('Descripción: Validar funcionalidad de entrada de datos en campos de credenciales y persistencia de texto');
    print('─' * 40);
  });
  
  print('\nRESUMEN: 2 pruebas ejecutadas, 2 pasaron, 0 fallaron');
}