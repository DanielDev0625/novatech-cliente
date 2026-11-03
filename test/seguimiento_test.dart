import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novatech_cliente/core/api/modelos.dart';
import 'package:novatech_cliente/core/formato.dart';
import 'package:novatech_cliente/features/notificaciones/vigilante.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'apoyo.dart';

void main() {
  test('hora al estilo del diseño', () {
    expect(horaAmPm(DateTime(2026, 11, 3, 16, 48)), '4:48 p. m.');
    expect(horaAmPm(DateTime(2026, 11, 3, 0, 5)), '12:05 a. m.');
    expect(horaAmPm(DateTime(2026, 11, 3, 12, 0)), '12:00 p. m.');
  });

  group('Seguimiento, QR y notificaciones', () {
    late ApiFalsa api;
    late AlmacenFalso almacen;

    setUp(() {
      api = ApiFalsa()..agregarDireccion('casa', 'Cra 43 #84-20, Barranquilla');
      almacen = AlmacenFalso()..guardada = (tokenDePrueba(), Usuario.fromJson(usuarioJson()));
    });

    Future<void> hacerPedido(WidgetTester tester) async {
      await tester.pumpWidget(appDePrueba(api, almacen));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver carrito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5)); // se va el aviso «Pedido registrado»
      await tester.pumpAndSettle();
    }

    testWidgets('en ruta: mapa con «Llega en», QR de entrega y monto a pagar', (tester) async {
      await hacerPedido(tester);
      api.avanzar(1, 'en_ruta', latTransportista: 10.98, lngTransportista: -74.79, eta: 12);

      await tester.tap(find.text('Seguir en el mapa'));
      await tester.pumpAndSettle();
      expect(find.text('Llega en'), findsOneWidget);
      expect(find.text('12 min'), findsOneWidget);
      expect(find.text('Hora estimada'), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping), findsOneWidget); // el transportista en el mapa

      await tester.tap(find.text('Ver QR de entrega'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Escanéalo solo con el transportista'), findsOneWidget);
      expect(find.text('Pago contra entrega: \$ 907.000'), findsOneWidget);

      await tester.tap(find.text('Volver al seguimiento'));
      await tester.pumpAndSettle();
      expect(find.text('Llega en'), findsOneWidget);
    });

    testWidgets('antes de salir el seguimiento explica que aún no va en camino', (tester) async {
      await hacerPedido(tester);
      await tester.tap(find.text('Seguir en el mapa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aún no sale'), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping), findsNothing);
    });

    testWidgets('la campana cuenta los avisos nuevos y al abrirlos quedan vistos', (tester) async {
      await hacerPedido(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notificaciones (1 nuevas)'), findsOneWidget);

      await tester.tap(find.byTooltip('Notificaciones (1 nuevas)'));
      await tester.pumpAndSettle();
      expect(find.text('Recibimos tu pedido'), findsOneWidget);
      expect(almacen.vistas[7], 1);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notificaciones'), findsOneWidget);
    });

    testWidgets('mientras la app está abierta avisa cuando el pedido avanza', (tester) async {
      await hacerPedido(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      api.avanzar(1, 'en_ruta', latTransportista: 10.98, lngTransportista: -74.79, eta: 9);
      await tester.pump(intervaloAvisos);
      await tester.pumpAndSettle();
      expect(find.text('Tu pedido va en camino · PED-2026-0001'), findsOneWidget);
      expect(find.text('En ruta'), findsOneWidget); // «Mis pedidos» al día

      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(find.text('9 min'), findsOneWidget);
    });

    testWidgets('entregado: ya no hay QR y el total figura como pagado', (tester) async {
      await hacerPedido(tester);
      api.avanzar(1, 'entregado');
      await tester.pageBack();
      await tester.pump(intervaloAvisos); // la revisión periódica trae el cambio
      await tester.pumpAndSettle();
      expect(find.text('Pedido entregado · PED-2026-0001'), findsOneWidget);
      await tester.tap(find.text('Anteriores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PED-2026-0001'));
      await tester.pumpAndSettle();
      expect(find.text('Total pagado'), findsOneWidget);
      expect(find.text('Pagado contra entrega'), findsOneWidget);
      expect(find.text('QR de entrega'), findsNothing);
      expect(find.text('Seguir en el mapa'), findsNothing);
    });
  });
}
