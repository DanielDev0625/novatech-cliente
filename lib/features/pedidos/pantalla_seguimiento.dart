import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/sesion/sesion.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import '../carrito/widgets_carrito.dart';
import 'api_pedidos.dart';
import 'pantalla_pedido.dart';

/// Cada cuánto se pide de nuevo la posición mientras la pantalla está abierta.
const intervaloSeguimiento = Duration(seconds: 15);

final seguimientoProvider = FutureProvider.autoDispose.family<Seguimiento, int>((ref, id) async {
  ref.watch(sesionProvider.select((s) => s.token));
  final datos = await ref.read(clienteApiProvider).get('/pedidos/$id/seguimiento');
  return Seguimiento.fromJson(Map<String, dynamic>.from(datos as Map));
});

/// «Pedido PED-0412»: mapa con el transportista y tu dirección, «Llega en N min»,
/// recorrido de estados y el botón del QR de entrega.
class PantallaSeguimiento extends ConsumerStatefulWidget {
  const PantallaSeguimiento({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  ConsumerState<PantallaSeguimiento> createState() => _PantallaSeguimientoState();
}

class _PantallaSeguimientoState extends ConsumerState<PantallaSeguimiento> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(intervaloSeguimiento, (_) => _refrescar());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _refrescar() async {
    // Ya entregado o cancelado: no hace falta seguir preguntando.
    if (ref.read(pedidoProvider(widget.pedidoId)).valueOrNull?.estado.terminado ?? false) {
      _reloj?.cancel();
      return;
    }
    ref.invalidate(seguimientoProvider(widget.pedidoId));
    ref.invalidate(pedidoProvider(widget.pedidoId));
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.pedidoId;
    final pedido = ref.watch(pedidoProvider(id));
    final seguimiento = ref.watch(seguimientoProvider(id));
    final p = pedido.valueOrNull;

    return Esqueleto(
      titulo: p == null ? 'Pedido' : 'Pedido ${p.codigo}',
      alRecargar: () async {
        ref.invalidate(seguimientoProvider(id));
        ref.invalidate(pedidoProvider(id));
        await ref.read(pedidoProvider(id).future);
      },
      accionInferior: p?.qrEntrega == null
          ? null
          : FilledButton.icon(
              style: estiloNaranja(),
              onPressed: () => context.push('/pedidos/$id/qr'),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Ver QR de entrega'),
            ),
      hijos: [
        VistaAsync<Seguimiento>(
          valor: seguimiento,
          alReintentar: () => ref.invalidate(seguimientoProvider(id)),
          datos: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(height: 240, child: MapaSeguimiento(seguimiento: s)),
              ),
              const SizedBox(height: 10),
              _Llegada(seguimiento: s, fechaPrometida: p?.fechaPrometida),
            ],
          ),
        ),
        if (p != null) RecorridoPedido(pedido: p),
      ],
    );
  }
}

/// Mapa con tu dirección (pin rojo) y, si va en ruta, el transportista (naranja) y la línea entre los dos.
class MapaSeguimiento extends StatelessWidget {
  const MapaSeguimiento({super.key, required this.seguimiento});

  final Seguimiento seguimiento;

  @override
  Widget build(BuildContext context) {
    final s = seguimiento;
    final destino = LatLng(s.destinoLatitud, s.destinoLongitud);
    final transportista = s.hayTransportista ? LatLng(s.transportistaLatitud!, s.transportistaLongitud!) : null;

    return FlutterMap(
      // Clave por posición: al moverse el transportista el mapa vuelve a encuadrar a los dos.
      key: ValueKey('${transportista?.latitude},${transportista?.longitude}'),
      options: MapOptions(
        initialCenter: destino,
        initialZoom: 16,
        initialCameraFit: transportista == null
            ? null
            : CameraFit.coordinates(coordinates: [destino, transportista], padding: const EdgeInsets.all(48)),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.novatech.novatech_cliente',
        ),
        if (transportista != null)
          PolylineLayer(
            polylines: [Polyline(points: [transportista, destino], color: ColoresNovaTech.azul, strokeWidth: 5)],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: destino,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_on, color: ColoresNovaTech.rojo, size: 40),
            ),
            if (transportista != null)
              Marker(
                point: transportista,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: ColoresNovaTech.naranja,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}

/// «Llega en 12 min · Hora estimada 4:48 p. m.», o en qué va si aún no sale.
class _Llegada extends StatelessWidget {
  const _Llegada({required this.seguimiento, required this.fechaPrometida});

  final Seguimiento seguimiento;
  final DateTime? fechaPrometida;

  @override
  Widget build(BuildContext context) {
    final s = seguimiento;
    final eta = s.etaMinutos;
    if (s.estado == EstadoPedido.enRuta && eta != null) {
      final llega = DateTime.now().add(Duration(minutes: eta));
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Llega en', style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13)),
                    Text(duracion(eta), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Hora estimada', style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13)),
                  Text(horaAmPm(llega), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final texto = switch (s.estado) {
      EstadoPedido.enRuta => 'Tu pedido va en camino. Pronto verás la hora estimada.',
      EstadoPedido.entregado => 'Tu pedido ya fue entregado.',
      EstadoPedido.cancelado => 'Este pedido se canceló.',
      _ when fechaPrometida != null =>
        'Aún no sale. Te avisamos cuando vaya en camino (llega a más tardar el ${fechaCorta(fechaPrometida!)}).',
      _ => 'Aún no sale. Te avisamos cuando vaya en camino.',
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(14), child: Text(texto)),
    );
  }
}
