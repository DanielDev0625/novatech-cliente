import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modelos.dart';
import '../../core/tema/tema.dart';
import 'carrito.dart';

/// Botón naranja de la marca (agregar, ver carrito), como en el diseño.
ButtonStyle estiloNaranja() => FilledButton.styleFrom(
      backgroundColor: ColoresNovaTech.naranja,
      foregroundColor: Colors.white,
    );

/// Contador compacto «− 2 +» para tarjetas y filas del carrito.
class ContadorCompacto extends StatelessWidget {
  const ContadorCompacto({super.key, required this.cantidad, required this.alRestar, required this.alSumar});

  final int cantidad;
  final VoidCallback? alRestar;

  /// null cuando ya no hay más unidades disponibles.
  final VoidCallback? alSumar;

  @override
  Widget build(BuildContext context) {
    Widget boton(IconData icono, String ayuda, VoidCallback? accion) => SizedBox(
          width: 34,
          height: 34,
          child: IconButton(
            tooltip: ayuda,
            padding: EdgeInsets.zero,
            onPressed: accion,
            style: IconButton.styleFrom(
              side: const BorderSide(color: ColoresNovaTech.borde),
              backgroundColor: Colors.white,
            ),
            icon: Icon(icono, size: 18),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        boton(Icons.remove, 'Quitar uno', alRestar),
        SizedBox(
          width: 32,
          child: Text(
            '$cantidad',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        boton(Icons.add, 'Agregar uno', alSumar),
      ],
    );
  }
}

/// En la tarjeta de la tienda: «Agregar» y, cuando ya está en el carrito, el contador.
class AgregarProducto extends ConsumerWidget {
  const AgregarProducto({super.key, required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cantidad = ref.watch(carritoProvider.select(
      (items) => items.where((i) => i.producto.id == producto.id).fold(0, (s, i) => s + i.cantidad),
    ));
    final carrito = ref.read(carritoProvider.notifier);
    if (cantidad == 0) {
      return SizedBox(
        height: 36,
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36), padding: EdgeInsets.zero),
          onPressed: () => carrito.sumar(producto),
          child: const Text('Agregar', style: TextStyle(fontSize: 14)),
        ),
      );
    }
    return Center(
      child: ContadorCompacto(
        cantidad: cantidad,
        alRestar: () => carrito.restar(producto),
        alSumar: cantidad < producto.stock ? () => carrito.sumar(producto) : null,
      ),
    );
  }
}

/// Barra naranja «🛒 2 productos · Ver carrito». No se muestra con el carrito vacío.
class BarraCarrito extends ConsumerWidget {
  const BarraCarrito({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unidades = ref.watch(unidadesCarritoProvider);
    if (unidades == 0) return const SizedBox.shrink();
    return FilledButton(
      style: estiloNaranja(),
      onPressed: () => context.push('/carrito'),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 20),
          const SizedBox(width: 8),
          Text(
            unidades == 1 ? '1 producto' : '$unidades productos',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          const Text('Ver carrito'),
        ],
      ),
    );
  }
}
