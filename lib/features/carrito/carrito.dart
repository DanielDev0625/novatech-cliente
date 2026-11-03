import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/modelos.dart';
import '../../core/sesion/sesion.dart';

/// Un producto del carrito con la cantidad elegida.
class ItemCarrito {
  const ItemCarrito(this.producto, this.cantidad);

  final Producto producto;
  final int cantidad;

  double get subtotal => producto.precio * cantidad;
}

/// Carrito del cliente. Vive en el celular hasta confirmar el pedido; al cambiar
/// de sesión se vacía (otra persona nunca ve el carrito de la anterior).
/// La cantidad nunca pasa de las unidades disponibles.
class CarritoNotifier extends Notifier<List<ItemCarrito>> {
  @override
  List<ItemCarrito> build() {
    ref.watch(sesionProvider.select((s) => s.token));
    return const [];
  }

  int cantidadDe(int productoId) {
    for (final i in state) {
      if (i.producto.id == productoId) return i.cantidad;
    }
    return 0;
  }

  /// Deja [cantidad] unidades del producto (0 lo quita). Respeta el stock.
  void poner(Producto producto, int cantidad) {
    final limitada = cantidad.clamp(0, producto.stock);
    final sinEste = [for (final i in state) if (i.producto.id != producto.id) i];
    if (limitada == 0) {
      state = sinEste;
      return;
    }
    final indice = state.indexWhere((i) => i.producto.id == producto.id);
    final nuevo = ItemCarrito(producto, limitada);
    if (indice < 0) {
      state = [...state, nuevo];
    } else {
      state = [...state]..[indice] = nuevo;
    }
  }

  void sumar(Producto producto, [int cuantas = 1]) => poner(producto, cantidadDe(producto.id) + cuantas);

  void restar(Producto producto) => poner(producto, cantidadDe(producto.id) - 1);

  /// Pone al día precios y stock con el catálogo recién traído; quita lo que ya no hay.
  void actualizarCon(List<Producto> catalogo) {
    final porId = {for (final p in catalogo) p.id: p};
    final nuevo = <ItemCarrito>[];
    for (final i in state) {
      final p = porId[i.producto.id];
      if (p == null) continue;
      final cantidad = i.cantidad.clamp(0, p.stock);
      if (cantidad > 0) nuevo.add(ItemCarrito(p, cantidad));
    }
    state = nuevo;
  }

  void vaciar() => state = const [];
}

final carritoProvider = NotifierProvider<CarritoNotifier, List<ItemCarrito>>(CarritoNotifier.new);

/// Unidades en el carrito (para la barra «N productos · Ver carrito»).
final unidadesCarritoProvider = Provider<int>(
  (ref) => ref.watch(carritoProvider).fold(0, (s, i) => s + i.cantidad),
);

/// Suma de los productos (sin envío).
final subtotalCarritoProvider = Provider<double>(
  (ref) => ref.watch(carritoProvider).fold(0.0, (s, i) => s + i.subtotal),
);
