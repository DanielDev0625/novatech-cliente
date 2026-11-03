import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/modelos.dart';
import '../../core/tema/tema.dart';
import '../pedidos/api_pedidos.dart';
import 'api_notificaciones.dart';

/// Cada cuánto se revisan los avisos mientras la app está abierta.
const intervaloAvisos = Duration(seconds: 45);

/// Mientras la app está abierta revisa los avisos cada [intervaloAvisos]. Cuando llega uno
/// nuevo (p. ej. «Tu pedido va en camino») lo muestra abajo y pone al día «Mis pedidos».
class VigilanteAvisos extends ConsumerStatefulWidget {
  const VigilanteAvisos({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VigilanteAvisos> createState() => _VigilanteAvisosState();
}

class _VigilanteAvisosState extends ConsumerState<VigilanteAvisos> with WidgetsBindingObserver {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reloj = Timer.periodic(intervaloAvisos, (_) => _revisar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloj?.cancel();
    super.dispose();
  }

  /// Al volver a la app se revisa de una vez.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _revisar();
  }

  void _revisar() => ref.invalidate(notificacionesProvider);

  void _avisar(Notificacion n) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: ColoresNovaTech.marino,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text('${n.titulo} · ${n.codigo}'),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () => GoRouter.of(context).push(
            n.estado == EstadoPedido.enRuta ? '/pedidos/${n.pedidoId}/seguimiento' : '/pedidos/${n.pedidoId}',
          ),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Notificacion>>>(notificacionesProvider, (anterior, actual) {
      final antes = anterior?.valueOrNull;
      final ahora = actual.valueOrNull;
      // La primera carga no avisa nada: solo lo que llega después.
      if (antes == null || ahora == null || ahora.isEmpty) return;
      final maximoAntes = antes.isEmpty ? 0 : antes.first.id;
      final nuevas = ahora.where((n) => n.id > maximoAntes).toList();
      if (nuevas.isEmpty) return;
      ref.invalidate(misPedidosProvider);
      for (final n in nuevas) {
        ref.invalidate(pedidoProvider(n.pedidoId));
      }
      // Registrar y cancelar los hace el mismo cliente: ya lo vio, no hace falta el aviso.
      final deOtros = nuevas.where((n) => n.estado != EstadoPedido.registrado && n.estado != EstadoPedido.cancelado);
      if (deOtros.isNotEmpty) _avisar(deOtros.first);
    });
    // Mantiene viva la lista para que la campana tenga su número desde el inicio.
    ref.watch(sinLeerProvider);
    return widget.child;
  }
}
