import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import '../carrito/carrito.dart';
import '../carrito/widgets_carrito.dart';
import 'api_tienda.dart';

/// Detalle de un producto: categoría, marca, precio y unidades disponibles.
/// Abajo se elige la cantidad y se agrega al carrito.
class PantallaProducto extends ConsumerStatefulWidget {
  const PantallaProducto({super.key, required this.productoId});

  final int productoId;

  @override
  ConsumerState<PantallaProducto> createState() => _PantallaProductoState();
}

class _PantallaProductoState extends ConsumerState<PantallaProducto> {
  /// Cantidad elegida; empieza en lo que ya hay en el carrito (o 1).
  late int _cantidad = math.max(1, ref.read(carritoProvider.notifier).cantidadDe(widget.productoId));

  void _agregar(Producto producto) {
    final yaEstaba = ref.read(carritoProvider.notifier).cantidadDe(producto.id) > 0;
    ref.read(carritoProvider.notifier).poner(producto, _cantidad);
    mostrarMensaje(context, yaEstaba ? 'Carrito actualizado' : 'Agregado al carrito');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final productoId = widget.productoId;
    final catalogo = ref.watch(catalogoProvider);
    final producto = catalogo.valueOrNull?.where((p) => p.id == productoId).firstOrNull;
    final enCarrito = ref.watch(carritoProvider.select(
      (items) => items.any((i) => i.producto.id == productoId),
    ));
    final cantidad = producto == null ? _cantidad : _cantidad.clamp(1, producto.stock);

    return Esqueleto(
      titulo: producto?.categoria ?? 'Producto',
      accionInferior: producto == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Cantidad', style: TextStyle(fontSize: 15))),
                    ContadorCompacto(
                      cantidad: cantidad,
                      alRestar: cantidad > 1 ? () => setState(() => _cantidad = cantidad - 1) : null,
                      alSumar: cantidad < producto.stock ? () => setState(() => _cantidad = cantidad + 1) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(
                  style: estiloNaranja(),
                  onPressed: () {
                    _cantidad = cantidad;
                    _agregar(producto);
                  },
                  child: Text(
                    '${enCarrito ? 'Actualizar carrito' : 'Agregar al carrito'} · ${pesos(producto.precio * cantidad)}',
                  ),
                ),
              ],
            ),
      alRecargar: () => ref.refresh(catalogoProvider.future),
      hijos: [
        VistaAsync<List<Producto>>(
          valor: catalogo,
          alReintentar: () => ref.invalidate(catalogoProvider),
          datos: (_) => producto == null
              ? const ListaVacia(
                  icono: Icons.remove_shopping_cart_outlined,
                  texto: 'Este producto ya no está disponible.',
                )
              : _Detalle(producto: producto),
        ),
      ],
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final subtitulo = [if (p.marca != null && p.marca!.isNotEmpty) p.marca!, p.categoria].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconoCategoria(categoria: p.categoria, alto: 170, tamano: 76),
        const SizedBox(height: 16),
        Text(p.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitulo, style: const TextStyle(color: ColoresNovaTech.textoSuave)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(pesos(p.precio), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            Insignia(
              texto: p.stock == 1 ? 'Última unidad' : '${p.stock} disponibles',
              color: p.stock <= 3 ? ColoresNovaTech.naranja : ColoresNovaTech.verde,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Fila(etiqueta: 'Referencia', valor: p.sku),
                if (p.marca != null && p.marca!.isNotEmpty) _Fila(etiqueta: 'Marca', valor: p.marca!),
                _Fila(etiqueta: 'Categoría', valor: p.categoria),
                const _Fila(etiqueta: 'Entrega', valor: 'A domicilio, a tu dirección principal'),
                const _Fila(etiqueta: 'Pago', valor: '$textoPago · $detallePago'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(etiqueta, style: const TextStyle(color: ColoresNovaTech.textoSuave)),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}
