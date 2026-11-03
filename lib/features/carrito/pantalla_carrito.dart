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
import '../pedidos/api_pedidos.dart';
import '../tienda/api_tienda.dart';
import 'carrito.dart';
import 'widgets_carrito.dart';

/// «Carrito»: productos con − / +, subtotal, envío, total y dónde se entrega.
class PantallaCarrito extends ConsumerWidget {
  const PantallaCarrito({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(carritoProvider);
    final principal = ref.watch(direccionPrincipalProvider);
    final direccion = principal.valueOrNull;

    return Esqueleto(
      titulo: 'Carrito',
      alRecargar: () async {
        ref.invalidate(condicionesProvider);
        ref.invalidate(catalogoProvider);
        final catalogo = await ref.read(catalogoProvider.future);
        ref.read(carritoProvider.notifier).actualizarCon(catalogo);
      },
      accionInferior: items.isEmpty
          ? null
          : FilledButton(
              onPressed: direccion == null ? null : () => context.push('/carrito/confirmar'),
              child: const Text('Continuar'),
            ),
      hijos: items.isEmpty
          ? [
              const ListaVacia(icono: Icons.shopping_cart_outlined, texto: 'Tu carrito está vacío.'),
              OutlinedButton(onPressed: () => context.go('/tienda'), child: const Text('Ir a la tienda')),
            ]
          : [
              for (final i in items) _FilaItem(item: i),
              const SizedBox(height: 4),
              const ResumenMontos(),
              const SizedBox(height: 4),
              if (principal case AsyncData(value: null))
                const SinDireccion()
              else
                TarjetaEntrega(direccion: direccion, alTocar: () => context.push('/direcciones')),
            ],
    );
  }
}

class _FilaItem extends ConsumerWidget {
  const _FilaItem({required this.item});

  final ItemCarrito item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = item.producto;
    final carrito = ref.read(carritoProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(width: 48, child: IconoCategoria(categoria: p.categoria, alto: 48, tamano: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(pesos(p.precio), style: const TextStyle(color: ColoresNovaTech.textoSuave)),
                  if (item.cantidad >= p.stock)
                    Text(
                      p.stock == 1 ? 'Es la última unidad' : 'Son todas las disponibles',
                      style: const TextStyle(color: ColoresNovaTech.naranja, fontSize: 12),
                    ),
                ],
              ),
            ),
            ContadorCompacto(
              cantidad: item.cantidad,
              // Bajar de 1 quita el producto del carrito.
              alRestar: () => carrito.restar(p),
              alSumar: item.cantidad < p.stock ? () => carrito.sumar(p) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtotal, envío y total (el envío lo define el administrador).
class ResumenMontos extends ConsumerWidget {
  const ResumenMontos({super.key, this.textoTotal = 'Total'});

  final String textoTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = ref.watch(subtotalCarritoProvider);
    final condiciones = ref.watch(condicionesProvider);
    final envio = condiciones.valueOrNull?.costoEnvio;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            FilaMonto(etiqueta: 'Subtotal', valor: pesos(subtotal)),
            FilaMonto(
              etiqueta: 'Envío',
              valor: switch (condiciones) {
                AsyncData() => envio == 0 ? 'Gratis' : pesos(envio!),
                AsyncError() => 'Se calcula al confirmar',
                _ => '…',
              },
            ),
            const SizedBox(height: 4),
            FilaMonto(
              etiqueta: textoTotal,
              valor: envio == null ? pesos(subtotal) : pesos(subtotal + envio),
              fuerte: true,
            ),
          ],
        ),
      ),
    );
  }
}

class FilaMonto extends StatelessWidget {
  const FilaMonto({super.key, required this.etiqueta, required this.valor, this.fuerte = false});

  final String etiqueta;
  final String valor;
  final bool fuerte;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: fuerte ? 16 : 14,
      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w400,
      color: fuerte ? ColoresNovaTech.texto : ColoresNovaTech.textoSuave,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(valor, style: estilo.copyWith(color: ColoresNovaTech.texto)),
        ],
      ),
    );
  }
}

/// «📍 Entregar en · Casa · Cra 43 #84-20 ›».
class TarjetaEntrega extends StatelessWidget {
  const TarjetaEntrega({super.key, required this.direccion, this.alTocar});

  final Direccion? direccion;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final d = direccion;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: ColoresNovaTech.rojo),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Entregar en', style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13)),
                    Text(
                      d == null ? '…' : '${d.etiqueta.texto} · ${d.textoCorto}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (alTocar != null) const Icon(Icons.chevron_right, color: ColoresNovaTech.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}
