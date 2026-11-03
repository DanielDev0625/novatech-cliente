import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_cliente/core/api/modelos.dart';
import 'package:novatech_cliente/core/rutas/rutas.dart';
import 'package:novatech_cliente/core/sesion/sesion.dart';
import 'package:novatech_cliente/features/acceso/pantalla_registro.dart';

import 'apoyo.dart';

void main() {
  group('Validación del registro', () {
    String? validar({String n = 'Ana Soto', String u = 'ana.soto', String p = 'clave1234', String? c}) =>
        validarRegistro(nombre: n, usuario: u, password: p, confirmacion: c ?? p);

    test('datos correctos pasan', () => expect(validar(), isNull));
    test('usuario con espacios o muy corto no pasa', () {
      expect(validar(u: 'ana soto'), contains('sin espacios'));
      expect(validar(u: 'an'), contains('entre 3 y 50'));
    });
    test('contraseña corta o distinta no pasa', () {
      expect(validar(p: 'corta'), contains('al menos 8'));
      expect(validar(c: 'otra12345'), 'Las contraseñas no coinciden.');
    });
    test('falta el nombre', () => expect(validar(n: ' '), 'Escribe tu nombre.'));
  });

  group('Redirección', () {
    final cliente = Usuario.fromJson(usuarioJson());

    test('sin sesión solo se ven las pantallas de acceso', () {
      const sesion = EstadoSesion();
      expect(redireccionPorSesion(sesion, '/tienda'), '/acceso');
      expect(redireccionPorSesion(sesion, '/acceso'), isNull);
      expect(redireccionPorSesion(sesion, '/acceso/registro'), isNull);
      expect(redireccionPorSesion(sesion, '/accesorios'), '/acceso');
    });

    test('con sesión no se vuelve al acceso', () {
      final sesion = EstadoSesion(usuario: cliente, token: 't');
      expect(redireccionPorSesion(sesion, '/acceso'), rutaInicio);
      expect(redireccionPorSesion(sesion, '/cargando'), rutaInicio);
      expect(redireccionPorSesion(sesion, '/perfil'), isNull);
    });

    test('mientras se restaura se muestra la carga', () {
      expect(redireccionPorSesion(const EstadoSesion(restaurando: true), '/tienda'), '/cargando');
    });
  });

  group('Acceso', () {
    late ApiFalsa api;
    late AlmacenFalso almacen;

    Widget app() => appDePrueba(api, almacen);

    Future<void> escribir(WidgetTester tester, String pista, String texto) =>
        tester.enterText(find.widgetWithText(TextField, pista), texto);

    setUp(() {
      api = ApiFalsa();
      almacen = AlmacenFalso();
    });

    testWidgets('entra con usuario y contraseña', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await escribir(tester, 'Usuario', ' Camila.T ');
      await escribir(tester, 'Contraseña', 'clave1234');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Tienda'), findsWidgets);
      expect(almacen.guardada?.$2.usuario, 'camila.t');
    });

    testWidgets('contraseña incorrecta muestra el error', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await escribir(tester, 'Usuario', 'camila.t');
      await escribir(tester, 'Contraseña', 'otra');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
      expect(almacen.guardada, isNull);
    });

    testWidgets('crea la cuenta y entra a la tienda', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      await escribir(tester, 'Nombre y apellido', 'Ana Soto');
      await escribir(tester, 'Usuario', 'Ana.Soto');
      await escribir(tester, 'Contraseña (mínimo 8 caracteres)', 'clave1234');
      await escribir(tester, 'Repite la contraseña', 'clave1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(api.registros, ['Ana Soto|ana.soto']);
      expect(find.text('Tienda'), findsWidgets);
    });

    testWidgets('un usuario repetido pide elegir otro', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      await escribir(tester, 'Nombre y apellido', 'Camila');
      await escribir(tester, 'Usuario', 'camila.t');
      await escribir(tester, 'Contraseña (mínimo 8 caracteres)', 'clave1234');
      await escribir(tester, 'Repite la contraseña', 'clave1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Ese usuario ya existe. Elige otro.'), findsOneWidget);
      expect(api.registros, isEmpty);
    });

    testWidgets('una cuenta del personal no entra en la app del cliente', (tester) async {
      api.rol = 'operario';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await escribir(tester, 'Usuario', 'camila.t');
      await escribir(tester, 'Contraseña', 'clave1234');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.textContaining('app del personal'), findsOneWidget);
      expect(almacen.guardada, isNull);
    });

    testWidgets('una sesión guardada entra directo y «Cerrar sesión» vuelve al acceso', (tester) async {
      almacen.guardada = (tokenDePrueba(), Usuario.fromJson(usuarioJson()));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Tienda'), findsWidgets);

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Camila Torres'), findsOneWidget);
      expect(find.text('@camila.t'), findsOneWidget);

      await tester.tap(find.text('Cerrar sesión').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(almacen.guardada, isNull);
    });

    testWidgets('una sesión vencida no se usa', (tester) async {
      almacen.guardada = (tokenDePrueba(dura: const Duration(minutes: -5)), Usuario.fromJson(usuarioJson()));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  });
}
