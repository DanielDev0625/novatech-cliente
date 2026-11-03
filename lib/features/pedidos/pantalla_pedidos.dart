import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import '../notificaciones/pantalla_notificaciones.dart';
import 'api_pedidos.dart';

/// Pestaña elegida: true = «En curso», false = «Anteriores».
final verEnCursoProvider = StateProvider<bool>((ref) => true);

/// Pestaña «Mis pedidos»: en curso arriba (los más recientes primero) y anteriores aparte.
class PantallaPedidos extends ConsumerWidget {
  const PantallaPedidos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valor = ref.watch(misPedidosProvider);
    final enCurso = ref.watch(verEnCursoProvider);

    return Esqueleto(
      titulo: 'Mis pedidos',
      acciones: const [CampanaNotificaciones(), SizedBox(width: 4)],
      alRecargar: () => ref.refresh(misPedidosProvider.future),
      hijos: [
        Row(
          children: [
            for (final (texto, valorPestana) in const [('En curso', true), ('Anteriores', false)])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(texto),
                  selected: enCurso == valorPestana,
                  onSelected: (_) => ref.read(verEnCursoProvider.notifier).state = valorPestana,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        VistaAsync<List<PedidoResumen>>(
          valor: valor,
          alReintentar: () => ref.invalidate(misPedidosProvider),
          datos: (pedidos) {
            final visibles = pedidos.where((p) => p.estado.terminado != enCurso).toList();
            if (visibles.isEmpty) {
              return ListaVacia(
                icono: Icons.inventory_2_outlined,
                texto: enCurso
                    ? 'No tienes pedidos en curso. Elige tus componentes en la tienda.'
                    : 'Aquí verás tus pedidos entregados y cancelados.',
              );
            }
            return Column(children: [for (final p in visibles) TarjetaPedido(pedido: p)]);
          },
        ),
      ],
    );
  }
}

class TarjetaPedido extends StatelessWidget {
  const TarjetaPedido({super.key, required this.pedido});

  final PedidoResumen pedido;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final creado = p.creadoEn;
    final detalle = [
      p.unidades == 1 ? '1 producto' : '${p.unidades} productos',
      if (creado != null) diaRelativo(creado),
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          p.estado == EstadoPedido.enRuta ? '/pedidos/${p.id}/seguimiento' : '/pedidos/${p.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(p.codigo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  Insignia(texto: p.estado.etiqueta, color: colorEstado(p.estado)),
                ],
              ),
              const SizedBox(height: 2),
              Text(detalle, style: const TextStyle(color: ColoresNovaTech.textoSuave)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: Text(pesos(p.totalAPagar), style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(
                    p.estado == EstadoPedido.enRuta ? 'Seguir' : 'Ver',
                    style: const TextStyle(color: ColoresNovaTech.azul, fontWeight: FontWeight.w600),
                  ),
                  const Icon(Icons.chevron_right, color: ColoresNovaTech.azul, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
