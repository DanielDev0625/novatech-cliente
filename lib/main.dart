import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/rutas/rutas.dart';
import 'core/tema/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NovaTechCliente()));
}

/// App del cliente de NovaTech: entra con su cuenta, compra
/// componentes de PC y sigue su pedido hasta la puerta.
class NovaTechCliente extends ConsumerWidget {
  const NovaTechCliente({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'NovaTech',
      debugShowCheckedModeBanner: false,
      theme: TemaNovaTech.claro(),
      routerConfig: router,
    );
  }
}
