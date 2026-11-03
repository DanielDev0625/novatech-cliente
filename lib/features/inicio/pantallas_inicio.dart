import 'package:flutter/material.dart';

import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';

/// Pestaña «Tienda». El catálogo con stock y la dirección de entrega llegan en la fase C2.
class PantallaTienda extends StatelessWidget {
  const PantallaTienda({super.key});

  @override
  Widget build(BuildContext context) {
    return const Esqueleto(
      titulo: 'Tienda',
      hijos: [
        ListaVacia(
          icono: Icons.storefront_outlined,
          texto: 'Muy pronto verás aquí el catálogo de componentes con su stock.',
        ),
      ],
    );
  }
}

/// Pestaña «Pedidos». El carrito y los pedidos llegan en la fase C3.
class PantallaPedidos extends StatelessWidget {
  const PantallaPedidos({super.key});

  @override
  Widget build(BuildContext context) {
    return const Esqueleto(
      titulo: 'Mis pedidos',
      hijos: [
        ListaVacia(
          icono: Icons.inventory_2_outlined,
          texto: 'Aquí verás tus pedidos y podrás seguirlos hasta tu puerta.',
        ),
      ],
    );
  }
}
