import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_cliente/core/api/modelos.dart';
import 'package:novatech_cliente/features/carrito/carrito.dart';
import 'package:novatech_cliente/core/api/cliente_api.dart';
import 'package:novatech_cliente/core/sesion/sesion.dart';

import 'apoyo.dart';

Producto producto(int id, {int stock = 5, double precio = 1000}) =>
    Producto.fromJson(productoJson(id, 'P$id', 'SSD', precio, stock));

void main() {
  group('Carrito', () {
    late ProviderContainer contenedor;
    late CarritoNotifier carrito;

    setUp(() {
      contenedor = ProviderContainer(overrides: [
        clienteApiProvider.overrideWithValue(ApiFalsa()),
        almacenSeguroProvider.overrideWithValue(AlmacenFalso()),
      ]);
      carrito = contenedor.read(carritoProvider.notifier);
    });
    tearDown(() => contenedor.dispose());

    test('suma, resta y nunca pasa del stock', () {
      final p = producto(1, stock: 2, precio: 899000);
      carrito
        ..sumar(p)
        ..sumar(p)
        ..sumar(p);
      expect(carrito.cantidadDe(1), 2);
      expect(contenedor.read(subtotalCarritoProvider), 1798000);
      carrito
        ..restar(p)
        ..restar(p);
      expect(contenedor.read(carritoProvider), isEmpty);
    });

    test('se ajusta al catálogo nuevo: quita lo agotado y baja lo que ya no alcanza', () {
      carrito
        ..poner(producto(1, stock: 5), 4)
        ..poner(producto(2, stock: 5), 1);
      carrito.actualizarCon([producto(1, stock: 2, precio: 1500)]);
      final items = contenedor.read(carritoProvider);
      expect(items.single.producto.id, 1);
      expect(items.single.cantidad, 2);
      expect(items.single.producto.precio, 1500);
    });
  });

  group('Pedido contra entrega', () {
    late ApiFalsa api;
    late AlmacenFalso almacen;

    setUp(() {
      api = ApiFalsa()..agregarDireccion('casa', 'Cra 43 #84-20, Barranquilla');
      almacen = AlmacenFalso()..guardada = (tokenDePrueba(), Usuario.fromJson(usuarioJson()));
    });

    Future<void> abrir(WidgetTester tester) async {
      await tester.pumpWidget(appDePrueba(api, almacen));
      await tester.pumpAndSettle();
    }

    testWidgets('agrega desde la tienda, confirma y queda en Mis pedidos', (tester) async {
      await abrir(tester);
      expect(find.text('Ver carrito'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Agregar').first); // Ryzen 5 7600
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Agregar uno').first);
      await tester.pumpAndSettle();
      expect(find.text('2 productos'), findsOneWidget);

      await tester.tap(find.text('Ver carrito'));
      await tester.pumpAndSettle();
      expect(find.text('\$ 1.798.000'), findsOneWidget); // subtotal
      expect(find.text('\$ 8.000'), findsOneWidget); // envío = tarifa por entrega
      expect(find.text('\$ 1.806.000'), findsOneWidget); // total
      expect(find.text('Casa · Cra 43 #84-20'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Contra entrega'), findsOneWidget);
      expect(find.textContaining('Pagas al recibir tu pedido: \$ 1.806.000'), findsOneWidget);
      expect(find.text('El stock queda reservado al confirmar'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
      await tester.pumpAndSettle();
      expect(api.pedidos.single['total_a_pagar'], 1806000);
      expect(find.text('Pedido PED-2026-0001'), findsOneWidget);
      expect(find.text('Total a pagar'), findsOneWidget);
      expect(find.text('Contra entrega · Pagas al recibir tu pedido'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Mis pedidos'), findsOneWidget);
      expect(find.text('PED-2026-0001'), findsOneWidget);
      expect(find.text('Registrado'), findsOneWidget);
    });

    testWidgets('desde el detalle se elige la cantidad', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Ryzen 5 7600'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Agregar uno'));
      await tester.pump();
      await tester.tap(find.byTooltip('Agregar uno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar al carrito · \$ 2.697.000'));
      await tester.pumpAndSettle();
      expect(find.text('3 productos'), findsOneWidget);
    });

    testWidgets('si otro se llevó la última unidad, avisa y ajusta el carrito', (tester) async {
      await abrir(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar').last); // RAM: queda 1
      await tester.pumpAndSettle();
      api.catalogo.last['stock'] = 0; // otra persona la compró
      await tester.tap(find.text('Ver carrito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Stock insuficiente'), findsOneWidget);
      expect(find.text('Tu carrito está vacío.'), findsOneWidget);
      expect(api.pedidos, isEmpty);
    });

    testWidgets('un pedido registrado se puede cancelar y pasa a Anteriores', (tester) async {
      await abrir(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver carrito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
      await tester.pumpAndSettle();
      // Se espera a que se vaya el aviso «Pedido registrado», que tapa el botón de abajo.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar pedido'));
      await tester.pumpAndSettle();
      expect(api.pedidos.single['estado'], 'cancelado');
      expect(find.text('Este pedido se canceló'), findsOneWidget);
      expect(api.catalogo.first['stock'], 8); // el stock volvió

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('PED-2026-0001'), findsNothing);
      await tester.tap(find.text('Anteriores'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelado'), findsOneWidget);
    });
  });
}
