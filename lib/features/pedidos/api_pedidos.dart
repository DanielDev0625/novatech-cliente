import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/sesion/sesion.dart';
import '../../core/tema/tema.dart';
import '../carrito/carrito.dart';
import '../notificaciones/api_notificaciones.dart';
import '../tienda/api_tienda.dart';

/// Envío y plazo vigentes (los configura el administrador).
final condicionesProvider = FutureProvider<CondicionesPedido>((ref) async {
  ref.watch(sesionProvider.select((s) => s.token));
  final datos = await ref.read(clienteApiProvider).get('/pedidos/condiciones');
  return CondicionesPedido.fromJson(Map<String, dynamic>.from(datos as Map));
});

/// Pedidos del cliente, del más reciente al más antiguo.
final misPedidosProvider = FutureProvider<List<PedidoResumen>>((ref) async {
  ref.watch(sesionProvider.select((s) => s.token));
  final datos = await ref.read(clienteApiProvider).get('/pedidos/mios') as List;
  return [for (final p in datos) PedidoResumen.fromJson(Map<String, dynamic>.from(p as Map))];
});

final pedidoProvider = FutureProvider.autoDispose.family<Pedido, int>((ref, id) async {
  ref.watch(sesionProvider.select((s) => s.token));
  final datos = await ref.read(clienteApiProvider).get('/pedidos/$id');
  return Pedido.fromJson(Map<String, dynamic>.from(datos as Map));
});

class AccionesPedidos {
  AccionesPedidos(this._ref);

  final Ref _ref;
  ClienteApi get _api => _ref.read(clienteApiProvider);

  /// Confirma el carrito como pedido a [direccionId]. El servidor reserva el stock.
  /// Si sale bien vacía el carrito; si falta stock, trae el catálogo de nuevo.
  Future<Pedido> confirmar(int direccionId) async {
    final items = _ref.read(carritoProvider);
    try {
      final datos = await _api.post('/pedidos', datos: {
        'direccion_id': direccionId,
        'items': [
          for (final i in items) {'producto_id': i.producto.id, 'cantidad': i.cantidad},
        ],
      });
      final pedido = Pedido.fromJson(Map<String, dynamic>.from(datos as Map));
      _ref.read(carritoProvider.notifier).vaciar();
      _ref.invalidate(misPedidosProvider);
      _ref.invalidate(notificacionesProvider);
      _ref.invalidate(catalogoProvider);
      return pedido;
    } on ErrorApi catch (e) {
      // 409: otro cliente se llevó las últimas unidades; se ajusta el carrito al stock real.
      if (e.codigo == 409) {
        _ref.invalidate(catalogoProvider);
        final catalogo = await _ref.read(catalogoProvider.future);
        _ref.read(carritoProvider.notifier).actualizarCon(catalogo);
      }
      rethrow;
    }
  }

  Future<void> cancelar(int pedidoId) async {
    await _api.post('/pedidos/$pedidoId/cancelar');
    _ref.invalidate(misPedidosProvider);
    _ref.invalidate(pedidoProvider(pedidoId));
    _ref.invalidate(catalogoProvider);
    _ref.invalidate(notificacionesProvider);
  }
}

final accionesPedidosProvider = Provider<AccionesPedidos>((ref) => AccionesPedidos(ref));

/// Color de la insignia de cada estado (como en el diseño).
Color colorEstado(EstadoPedido e) => switch (e) {
      EstadoPedido.registrado => ColoresNovaTech.naranja,
      EstadoPedido.alistando => ColoresNovaTech.naranja,
      EstadoPedido.enZonaEnvios => ColoresNovaTech.azul,
      EstadoPedido.recibidoTransportista => ColoresNovaTech.azul,
      EstadoPedido.enRuta => ColoresNovaTech.azul,
      EstadoPedido.entregado => ColoresNovaTech.verde,
      EstadoPedido.cancelado => ColoresNovaTech.rojo,
    };
