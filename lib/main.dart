import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/rutas/rutas.dart';
import 'core/tema/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // En la web, direcciones limpias (/pedidos/12) en lugar de /#/pedidos/12.
  usePathUrlStrategy();
  runApp(const ProviderScope(child: NovaTechCliente()));
}

/// En la web también se arrastran las listas con el mouse (p. ej. las píldoras de categoría).
class _DesplazamientoConMouse extends MaterialScrollBehavior {
  const _DesplazamientoConMouse();

  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse};
}

/// App del cliente de NovaTech: entra con su cuenta, compra
/// componentes de PC y sigue su pedido hasta la puerta. Corre en Android, iOS y la web.
class NovaTechCliente extends ConsumerWidget {
  const NovaTechCliente({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'NovaTech',
      debugShowCheckedModeBanner: false,
      theme: TemaNovaTech.claro(),
      scrollBehavior: const _DesplazamientoConMouse(),
      routerConfig: router,
    );
  }
}
