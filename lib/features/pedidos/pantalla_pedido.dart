import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import '../carrito/pantalla_carrito.dart';
import '../carrito/widgets_carrito.dart';
import 'api_pedidos.dart';

/// Detalle del pedido: en qué va, qué lleva, cuánto se paga al recibir y dónde.
/// Mientras está en curso lleva al mapa de seguimiento y al QR de entrega.
class PantallaPedido extends ConsumerWidget {
  const PantallaPedido({super.key, required this.pedidoId});

  final int pedidoId;

  Future<void> _cancelar(BuildContext context, WidgetRef ref, Pedido pedido) async {
    final ok = await confirmar(
      context,
      titulo: 'Cancelar pedido',
      texto: '¿Cancelar ${pedido.codigo}? Los productos vuelven a la tienda.',
      aceptar: 'Cancelar pedido',
    );
    if (!ok) return;
    try {
      await ref.read(accionesPedidosProvider).cancelar(pedido.id);
      if (context.mounted) mostrarMensaje(context, 'Pedido cancelado');
    } on ErrorApi catch (e) {
      if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
      ref.invalidate(pedidoProvider(pedido.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valor = ref.watch(pedidoProvider(pedidoId));
    final pedido = valor.valueOrNull;

    return Esqueleto(
      titulo: pedido == null ? 'Pedido' : 'Pedido ${pedido.codigo}',
      alRecargar: () => ref.refresh(pedidoProvider(pedidoId).future),
      accionInferior: pedido != null && pedido.estado.cancelable
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresNovaTech.rojo,
                side: const BorderSide(color: ColoresNovaTech.rojo),
              ),
              onPressed: () => _cancelar(context, ref, pedido),
              child: const Text('Cancelar pedido'),
            )
          : null,
      hijos: [
        VistaAsync<Pedido>(
          valor: valor,
          alReintentar: () => ref.invalidate(pedidoProvider(pedidoId)),
          datos: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecorridoPedido(pedido: p),
              if (!p.estado.terminado) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/pedidos/${p.id}/seguimiento'),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Seguir en el mapa'),
                      ),
                    ),
                    if (p.qrEntrega != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: estiloNaranja(),
                          onPressed: () => context.push('/pedidos/${p.id}/qr'),
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('QR de entrega'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
              ],
              _Productos(pedido: p),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: ColoresNovaTech.verde),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.estado == EstadoPedido.entregado
                              ? 'Pagado contra entrega'
                              : p.estado == EstadoPedido.cancelado
                                  ? 'No se cobró nada'
                                  : '$textoPago · $detallePago',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TarjetaEntrega(direccion: p.direccion),
            ],
          ),
        ),
      ],
    );
  }
}

/// Recorrido del pedido con puntos: verde lo hecho, azul donde va, gris lo que falta.
class RecorridoPedido extends StatelessWidget {
  const RecorridoPedido({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final llega = p.fechaPrometida;
    if (p.estado == EstadoPedido.cancelado) {
      return const TarjetaAviso(
        icono: Icons.cancel_outlined,
        texto: 'Este pedido se canceló',
        color: ColoresNovaTech.rojo,
      );
    }
    final actual = EstadoPedido.recorrido.indexOf(p.estado);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!p.estado.terminado && llega != null) ...[
              Text(
                'Llega a más tardar el ${fechaCorta(llega)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
            ],
            for (final (i, e) in EstadoPedido.recorrido.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < actual || (i == actual && e == EstadoPedido.entregado)
                            ? ColoresNovaTech.verde
                            : i == actual
                                ? ColoresNovaTech.azul
                                : ColoresNovaTech.borde,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.etiqueta,
                        style: TextStyle(
                          fontWeight: i == actual ? FontWeight.w700 : FontWeight.w400,
                          color: i <= actual ? ColoresNovaTech.texto : ColoresNovaTech.textoSuave,
                        ),
                      ),
                    ),
                    if (p.fechaDe(e) case final fecha?)
                      Text(fechaHora(fecha), style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Productos extends StatelessWidget {
  const _Productos({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.unidades == 1 ? '1 producto' : '${p.unidades} productos',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            for (final l in p.lineas)
              FilaMonto(etiqueta: '${l.nombre} ×${l.cantidad}', valor: pesos(l.subtotal)),
            FilaMonto(etiqueta: 'Envío', valor: p.costoEnvio == 0 ? 'Gratis' : pesos(p.costoEnvio)),
            const SizedBox(height: 4),
            FilaMonto(
              etiqueta: p.estado == EstadoPedido.entregado ? 'Total pagado' : 'Total a pagar',
              valor: pesos(p.totalAPagar),
              fuerte: true,
            ),
          ],
        ),
      ),
    );
  }
}
