import 'package:flutter/material.dart';

import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';

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
