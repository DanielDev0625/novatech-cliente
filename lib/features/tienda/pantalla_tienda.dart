import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import '../direcciones/api_direcciones.dart';
import '../direcciones/pantalla_agregar_direccion.dart';
import 'api_tienda.dart';

/// Categoría elegida en las píldoras (null = «Todo»). Se conserva al cambiar de pestaña.
final categoriaElegidaProvider = StateProvider<String?>((ref) => null);

/// Pestaña «Tienda»: dirección de entrega arriba, píldoras de categoría y productos con stock.
class PantallaTienda extends ConsumerWidget {
  const PantallaTienda({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final principal = ref.watch(direccionPrincipalProvider);
    final catalogo = ref.watch(catalogoProvider);
    final elegida = ref.watch(categoriaElegidaProvider);

    final direccion = principal.valueOrNull;
    final titulo = switch (principal) {
      AsyncData(value: null) => 'Agrega tu dirección',
      AsyncError() => 'Elige tu dirección',
      _ when direccion != null => '${direccion.etiqueta.texto} · ${direccion.textoCorto}',
      _ => '…',
    };

    return Esqueleto(
      etiqueta: 'Entregar en',
      titulo: titulo,
      alTocarTitulo: () => context.push(direccion == null ? '/direcciones/agregar' : '/direcciones'),
      alRecargar: () async {
        ref.invalidate(direccionesProvider);
        ref.invalidate(catalogoProvider);
        await ref.read(catalogoProvider.future);
      },
      hijos: [
        if (principal case AsyncData(value: null)) ...[const SinDireccion(), const SizedBox(height: 8)],
        VistaAsync<List<Producto>>(
          valor: catalogo,
          alReintentar: () => ref.invalidate(catalogoProvider),
          datos: (productos) {
            if (productos.isEmpty) {
              return const ListaVacia(
                icono: Icons.storefront_outlined,
                texto: 'Por ahora no hay productos disponibles. Vuelve pronto.',
              );
            }
            final categorias = categoriasCon(productos);
            // Si la categoría elegida se quedó sin productos, se vuelve a «Todo».
            final filtro = categorias.contains(elegida) ? elegida : null;
            final visibles = filtro == null ? productos : productos.where((p) => p.categoria == filtro).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PildorasCategoria(
                  categorias: categorias,
                  elegida: filtro,
                  alElegir: (c) => ref.read(categoriaElegidaProvider.notifier).state = c,
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 230,
                    mainAxisExtent: 196,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: visibles.length,
                  itemBuilder: (_, i) => TarjetaProducto(producto: visibles[i]),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PildorasCategoria extends StatelessWidget {
  const _PildorasCategoria({required this.categorias, required this.elegida, required this.alElegir});

  final List<String> categorias;
  final String? elegida;
  final ValueChanged<String?> alElegir;

  @override
  Widget build(BuildContext context) {
    Widget pildora(String texto, String? valor) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(texto),
            selected: elegida == valor,
            onSelected: (_) => alElegir(valor),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          pildora('Todo', null),
          for (final c in categorias) pildora(categoriaCorta(c), c),
        ],
      ),
    );
  }
}

/// Tarjeta del producto en la tienda; al tocarla se abre el detalle.
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({super.key, required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/tienda/producto/${p.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconoCategoria(categoria: p.categoria),
              const SizedBox(height: 8),
              Text(
                p.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.2),
              ),
              const Spacer(),
              Text(pesos(p.precio), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                p.stock == 1 ? 'Última unidad' : '${p.stock} disponibles',
                style: TextStyle(
                  fontSize: 12,
                  color: p.stock <= 3 ? ColoresNovaTech.naranja : ColoresNovaTech.verde,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
