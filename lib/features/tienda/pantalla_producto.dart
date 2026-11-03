import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import 'api_tienda.dart';

/// Detalle de un producto: categoría, marca, precio y unidades disponibles.
/// (El botón «Agregar al carrito» llega con el carrito, en la fase C3.)
class PantallaProducto extends ConsumerWidget {
  const PantallaProducto({super.key, required this.productoId});

  final int productoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);
    final producto = catalogo.valueOrNull?.where((p) => p.id == productoId).firstOrNull;

    return Esqueleto(
      titulo: producto?.categoria ?? 'Producto',
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
