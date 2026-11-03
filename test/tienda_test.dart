import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_cliente/core/api/modelos.dart';
import 'package:novatech_cliente/features/direcciones/geocodificador.dart';
import 'package:novatech_cliente/features/tienda/api_tienda.dart';

import 'apoyo.dart';

void main() {
  group('Dirección desde el mapa', () {
    test('arma la dirección al estilo colombiano', () {
      expect(
        textoDireccion({'road': 'Carrera 43', 'house_number': '84-20', 'city': 'Barranquilla'}),
        'Cra 43 #84-20, Barranquilla',
      );
      expect(textoDireccion({'road': 'Calle 76', 'town': 'Soledad'}), 'Calle 76, Soledad');
      expect(textoDireccion({'road': 'Avenida Circunvalar', 'house_number': '#10-5'}), 'Av Circunvalar #10-5');
      expect(textoDireccion({'city': 'Barranquilla'}), isNull);
      expect(
        textoDireccion({'road': 'Calle 74', 'city': 'Perímetro Urbano Barranquilla'}),
        'Calle 74, Barranquilla',
      );
    });

    test('abrevia solo el tipo de vía', () {
      expect(abreviarVia('Carrera 51B'), 'Cra 51B');
      expect(abreviarVia('Diagonal 5'), 'Dg 5');
      expect(abreviarVia('Vía 40'), 'Vía 40');
    });
  });

  test('las categorías siguen el orden de la tienda y solo aparecen si hay productos', () {
    final productos = [
      for (final c in ['SSD', 'Procesadores', 'Accesorios', 'SSD'])
        Producto.fromJson(productoJson(1, 'x', c, 1, 1)),
    ];
    expect(categoriasCon(productos), ['Procesadores', 'SSD', 'Accesorios']);
  });

  group('Tienda y direcciones', () {
    late ApiFalsa api;
    late AlmacenFalso almacen;

    setUp(() {
      api = ApiFalsa();
      almacen = AlmacenFalso()..guardada = (tokenDePrueba(), Usuario.fromJson(usuarioJson()));
    });

    testWidgets('sin direcciones invita a agregar una y muestra el catálogo', (tester) async {
      await tester.pumpWidget(appDePrueba(api, almacen));
      await tester.pumpAndSettle();
      expect(find.text('Agrega tu dirección'), findsOneWidget);
      expect(find.text('¿Dónde te entregamos? Agrega tu dirección'), findsOneWidget);
      expect(find.text('Ryzen 5 7600'), findsOneWidget);
      expect(find.text('\$ 899.000'), findsOneWidget);
      expect(find.text('Última unidad'), findsOneWidget);
    });

    testWidgets('el encabezado muestra la dirección principal y las píldoras filtran', (tester) async {
      api.agregarDireccion('casa', 'Cra 43 #84-20, Barranquilla');
      await tester.pumpWidget(appDePrueba(api, almacen));
      await tester.pumpAndSettle();
      expect(find.text('Entregar en'), findsOneWidget);
      expect(find.text('Casa · Cra 43 #84-20'), findsOneWidget);

      await tester.tap(find.text('RAM'));
      await tester.pumpAndSettle();
      expect(find.text('RAM DDR5 16 GB'), findsOneWidget);
      expect(find.text('Ryzen 5 7600'), findsNothing);

      await tester.tap(find.text('Todo'));
      await tester.pumpAndSettle();
      expect(find.text('Ryzen 5 7600'), findsOneWidget);
    });

    testWidgets('el detalle muestra precio, marca y disponibles', (tester) async {
      await tester.pumpWidget(appDePrueba(api, almacen));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RTX 4060 8 GB'));
      await tester.pumpAndSettle();
      expect(find.text('Marca2 · Tarjetas gráficas'), findsOneWidget);
      expect(find.text('\$ 1.649.000'), findsOneWidget);
      expect(find.text('2 disponibles'), findsOneWidget);
    });

    testWidgets('en Mis direcciones se elige la principal y se borra', (tester) async {
      api.agregarDireccion('casa', 'Cra 43 #84-20, Barranquilla');
      api.agregarDireccion('oficina', 'Calle 76 #52-18, Barranquilla');
      await tester.pumpWidget(appDePrueba(api, almacen));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Casa · Cra 43 #84-20'));
      await tester.pumpAndSettle();
      expect(find.text('Mis direcciones'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);

      await tester.tap(find.text('Oficina'));
      await tester.pumpAndSettle();
      expect(api.direcciones.firstWhere((d) => d['etiqueta'] == 'oficina')['principal'], isTrue);

      // Borrar la casa desde el menú ⋮ (la oficina ahora va primero).
      await tester.tap(find.byTooltip('Opciones').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.pumpAndSettle();
      expect(api.direcciones.map((d) => d['etiqueta']), ['oficina']);
      expect(find.text('Cra 43 #84-20'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Oficina · Calle 76 #52-18'), findsOneWidget);
    });

    testWidgets('agregar dirección: se completa sola y queda como principal', (tester) async {
      await tester.pumpWidget(appDePrueba(api, almacen));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Dónde te entregamos? Agrega tu dirección'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Cra 43 #84-20, Barranquilla'), findsOneWidget);

      await tester.tap(find.text('Oficina'));
      await tester.enterText(find.byType(TextField), 'Piso 3');
      await tester.tap(find.text('Confirmar dirección'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(api.direcciones.single['etiqueta'], 'oficina');
      expect(api.direcciones.single['principal'], isTrue);
      expect(find.text('Oficina · Cra 43 #84-20'), findsOneWidget);
    });
  });
}
