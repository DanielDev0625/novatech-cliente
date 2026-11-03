import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import 'api_pedidos.dart';

/// «QR de entrega»: el transportista lo escanea para confirmar que recibiste el pedido.
class PantallaQr extends ConsumerWidget {
  const PantallaQr({super.key, required this.pedidoId});

  final int pedidoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valor = ref.watch(pedidoProvider(pedidoId));

    return Esqueleto(
      titulo: 'QR de entrega',
      alRecargar: () => ref.refresh(pedidoProvider(pedidoId).future),
      accionInferior: OutlinedButton(
        onPressed: () => context.canPop() ? context.pop() : context.go('/pedidos/$pedidoId/seguimiento'),
        child: const Text('Volver al seguimiento'),
      ),
      hijos: [
        VistaAsync<Pedido>(
          valor: valor,
          alReintentar: () => ref.invalidate(pedidoProvider(pedidoId)),
          datos: (p) {
            final qr = p.qrEntrega;
            if (qr == null) {
              return ListaVacia(
                icono: Icons.qr_code_2,
                texto: p.estado == EstadoPedido.entregado
                    ? 'Este pedido ya se entregó; el código dejó de servir.'
                    : 'Este pedido ya no tiene código de entrega.',
              );
            }
            return Column(
              children: [
                const Text(
                  'Muéstraselo al transportista al recibir',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 15),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ColoresNovaTech.borde),
                    ),
                    child: Semantics(
                      label: 'Código QR de entrega del pedido ${p.codigo}',
                      child: QrImageView(
                        data: qr,
                        size: 230,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ColoresNovaTech.marino),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: ColoresNovaTech.marino,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(p.codigo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Insignia(texto: 'Escanéalo solo con el transportista', color: ColoresNovaTech.naranja),
                const SizedBox(height: 8),
                const Text(
                  'No compartas este código por mensaje',
                  style: TextStyle(color: ColoresNovaTech.textoSuave),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pago contra entrega: ${pesos(p.totalAPagar)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
