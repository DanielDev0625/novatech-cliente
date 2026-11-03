import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modelos.dart';
import '../../core/formato.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import '../pedidos/api_pedidos.dart';
import 'api_notificaciones.dart';

IconData iconoEstado(EstadoPedido e) => switch (e) {
      EstadoPedido.registrado => Icons.receipt_long_outlined,
      EstadoPedido.alistando => Icons.inventory_2_outlined,
      EstadoPedido.enZonaEnvios => Icons.outbox_outlined,
      EstadoPedido.recibidoTransportista => Icons.person_pin_circle_outlined,
      EstadoPedido.enRuta => Icons.local_shipping_outlined,
      EstadoPedido.entregado => Icons.check_circle_outline,
      EstadoPedido.cancelado => Icons.cancel_outlined,
    };

/// «Notificaciones»: un aviso por cada cambio de estado de tus pedidos.
/// Al abrirla, todos quedan como vistos.
class PantallaNotificaciones extends ConsumerStatefulWidget {
  const PantallaNotificaciones({super.key});

  @override
  ConsumerState<PantallaNotificaciones> createState() => _PantallaNotificacionesState();
}

class _PantallaNotificacionesState extends ConsumerState<PantallaNotificaciones> {
  /// Lo que no se había visto al abrir: se resalta mientras se está aquí.
  int? _vistaAlAbrir;

  @override
  Widget build(BuildContext context) {
    final valor = ref.watch(notificacionesProvider);
    _vistaAlAbrir ??= ref.watch(vistasProvider).valueOrNull;
    _marcar(valor.valueOrNull);

    return Esqueleto(
      titulo: 'Notificaciones',
      alRecargar: () => ref.refresh(notificacionesProvider.future),
      hijos: [
        VistaAsync<List<Notificacion>>(
          valor: valor,
          alReintentar: () => ref.invalidate(notificacionesProvider),
          datos: (lista) => lista.isEmpty
              ? const ListaVacia(
                  icono: Icons.notifications_none,
                  texto: 'Aquí te avisamos cada vez que tu pedido avance.',
                )
              : Column(
                  children: [
                    for (final n in lista) _TarjetaAviso(aviso: n, nueva: n.id > (_vistaAlAbrir ?? 1 << 30)),
                  ],
                ),
        ),
      ],
    );
  }

  void _marcar(List<Notificacion>? lista) {
    if (lista == null || lista.isEmpty) return;
    // Después del cuadro actual: no se cambia el estado mientras se dibuja.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(vistasProvider.notifier).marcarHasta(lista.first.id);
    });
  }
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso, required this.nueva});

  final Notificacion aviso;
  final bool nueva;

  @override
  Widget build(BuildContext context) {
    final n = aviso;
    final fecha = n.fecha;
    final hoy = fecha != null && soloFecha(fecha) == soloFecha(DateTime.now());
    final color = colorEstado(n.estado);
    return Card(
      color: nueva ? ColoresNovaTech.azul.withValues(alpha: 0.06) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pedidos/${n.pedidoId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconoEstado(n.estado), color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${n.codigo} · ${n.texto}', style: const TextStyle(color: ColoresNovaTech.textoSuave)),
                  ],
                ),
              ),
              if (fecha != null)
                Text(
                  hoy ? hora(fecha) : fechaCorta(fecha),
                  style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campana del encabezado con el número de avisos sin ver.
class CampanaNotificaciones extends ConsumerWidget {
  const CampanaNotificaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinLeer = ref.watch(sinLeerProvider);
    return IconButton(
      tooltip: sinLeer == 0 ? 'Notificaciones' : 'Notificaciones ($sinLeer nuevas)',
      onPressed: () => context.push('/notificaciones'),
      icon: Badge(
        isLabelVisible: sinLeer > 0,
        label: Text('$sinLeer'),
        backgroundColor: ColoresNovaTech.rojo,
        child: const Icon(Icons.notifications_outlined, color: Colors.white),
      ),
    );
  }
}
