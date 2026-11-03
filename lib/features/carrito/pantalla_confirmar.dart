import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import '../direcciones/api_direcciones.dart';
import '../pedidos/api_pedidos.dart';
import 'carrito.dart';
import 'pantalla_carrito.dart';

/// «Confirmar pedido»: dónde llega, qué lleva, cuánto se paga y cómo (contra entrega).
class PantallaConfirmar extends ConsumerStatefulWidget {
  const PantallaConfirmar({super.key});

  @override
  ConsumerState<PantallaConfirmar> createState() => _PantallaConfirmarState();
}

class _PantallaConfirmarState extends ConsumerState<PantallaConfirmar> {
  bool _enviando = false;

  Future<void> _confirmar(Direccion direccion) async {
    setState(() => _enviando = true);
    try {
      final pedido = await ref.read(accionesPedidosProvider).confirmar(direccion.id);
      if (!mounted) return;
      // Queda en «Pedidos» con el detalle del pedido recién hecho encima.
      context.go('/pedidos');
      context.push('/pedidos/${pedido.id}');
      mostrarMensaje(context, 'Pedido ${pedido.codigo} registrado');
    } on ErrorApi catch (e) {
      if (!mounted) return;
      final texto = e.codigo == 409 ? '${e.mensaje}. Ajustamos tu carrito a lo que hay disponible.' : e.mensaje;
      mostrarMensaje(context, texto, error: true);
      if (e.codigo == 409) context.pop(); // De vuelta al carrito para revisarlo.
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(carritoProvider);
    final direccion = ref.watch(direccionPrincipalProvider).valueOrNull;
    final condiciones = ref.watch(condicionesProvider);
    final subtotal = ref.watch(subtotalCarritoProvider);
    final unidades = ref.watch(unidadesCarritoProvider);
    final listo = items.isNotEmpty && direccion != null && condiciones.hasValue;

    return Esqueleto(
      titulo: 'Confirmar pedido',
      accionInferior: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: ColoresNovaTech.verde),
        onPressed: listo && !_enviando ? () => _confirmar(direccion) : null,
        child: _enviando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text('Confirmar pedido'),
      ),
      hijos: [
        VistaAsync<CondicionesPedido>(
          valor: condiciones,
          alReintentar: () => ref.invalidate(condicionesProvider),
          datos: (c) {
            final llega = DateTime.now().add(Duration(days: c.plazoDias));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Bloque(
                  titulo: 'Entrega en',
                  hijos: [
                    Text(
                      direccion == null
                          ? '…'
                          : [
                              '${direccion.etiqueta.texto} · ${direccion.textoCorto}',
                              if (direccion.indicaciones != null) direccion.indicaciones!,
                            ].join(' · '),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: ColoresNovaTech.textoSuave),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.plazoDias <= 0
                                ? 'Llega hoy'
                                : 'Llega a más tardar el ${fechaCorta(llega)}',
                            style: const TextStyle(color: ColoresNovaTech.textoSuave),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _Bloque(
                  titulo: unidades == 1 ? '1 producto' : '$unidades productos',
                  tituloFuerte: true,
                  hijos: [
                    Text(
                      items.map((i) => '${i.producto.nombre} ×${i.cantidad}').join(' · '),
                      style: const TextStyle(color: ColoresNovaTech.textoSuave),
                    ),
                    const SizedBox(height: 8),
                    FilaMonto(etiqueta: 'Productos', valor: pesos(subtotal)),
                    FilaMonto(etiqueta: 'Envío', valor: c.costoEnvio == 0 ? 'Gratis' : pesos(c.costoEnvio)),
                    FilaMonto(etiqueta: 'Total con envío', valor: pesos(subtotal + c.costoEnvio), fuerte: true),
                  ],
                ),
                _Bloque(
                  titulo: 'Pago',
                  hijos: [
                    const Row(
                      children: [
                        Icon(Icons.payments_outlined, color: ColoresNovaTech.verde),
                        SizedBox(width: 8),
                        Text(textoPago, style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$detallePago: ${pesos(subtotal + c.costoEnvio)}. No pagas nada ahora.',
                      style: const TextStyle(color: ColoresNovaTech.textoSuave),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Insignia(
                    texto: 'El stock queda reservado al confirmar',
                    color: ColoresNovaTech.azul,
                    icono: Icons.inventory_2_outlined,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.hijos, this.tituloFuerte = false});

  final String titulo;
  final bool tituloFuerte;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: tituloFuerte
                  ? const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)
                  : const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
            ),
            const SizedBox(height: 4),
            ...hijos,
          ],
        ),
      ),
    );
  }
}
