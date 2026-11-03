import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/acceso/pantalla_acceso.dart';
import '../../features/acceso/pantalla_registro.dart';
import '../../features/carrito/pantalla_carrito.dart';
import '../../features/carrito/pantalla_confirmar.dart';
import '../../features/direcciones/pantalla_agregar_direccion.dart';
import '../../features/direcciones/pantalla_direcciones.dart';
import '../../features/notificaciones/pantalla_notificaciones.dart';
import '../../features/notificaciones/vigilante.dart';
import '../../features/pedidos/pantalla_pedido.dart';
import '../../features/pedidos/pantalla_qr.dart';
import '../../features/pedidos/pantalla_seguimiento.dart';
import '../../features/pedidos/pantalla_pedidos.dart';
import '../../features/perfil/pantalla_perfil.dart';
import '../../features/tienda/pantalla_producto.dart';
import '../../features/tienda/pantalla_tienda.dart';
import '../sesion/sesion.dart';
import '../widgets/esqueleto.dart';
import '../widgets/pantalla_cargando.dart';

/// Avisa al enrutador cada vez que cambia la sesión, para que revise a dónde debe ir.
class _RefrescoPorSesion extends ChangeNotifier {
  _RefrescoPorSesion(Ref ref) {
    ref.listen<EstadoSesion>(sesionProvider, (anterior, actual) => notifyListeners());
  }
}

const rutaInicio = '/tienda';

/// Decide a dónde ir según la sesión:
///  - sin sesión solo se ven las pantallas de acceso (/acceso…);
///  - con sesión no se vuelve al acceso: se va a la tienda.
String? redireccionPorSesion(EstadoSesion sesion, String ruta) {
  if (sesion.restaurando) return ruta == '/cargando' ? null : '/cargando';
  final enAcceso = ruta == '/acceso' || ruta.startsWith('/acceso/');
  if (!sesion.autenticado) return enAcceso ? null : '/acceso';
  if (enAcceso || ruta == '/cargando') return rutaInicio;
  return null;
}

GoRoute _ruta(String path, Widget pantalla) => GoRoute(path: path, builder: (c, e) => pantalla);

int _id(GoRouterState estado) => int.tryParse(estado.pathParameters['id'] ?? '') ?? -1;

final routerProvider = Provider<GoRouter>((ref) {
  final refresco = _RefrescoPorSesion(ref);
  ref.onDispose(refresco.dispose);

  return GoRouter(
    initialLocation: '/cargando',
    refreshListenable: refresco,
    redirect: (context, estado) => redireccionPorSesion(ref.read(sesionProvider), estado.matchedLocation),
    routes: [
      _ruta('/cargando', const PantallaCargando()),
      _ruta('/acceso', const PantallaAcceso()),
      _ruta('/acceso/registro', const PantallaRegistro()),

      // ---- Pantallas que se abren encima de las pestañas (sin navegación inferior) ----
      _ruta('/direcciones', const PantallaDirecciones()),
      _ruta('/direcciones/agregar', const PantallaAgregarDireccion()),
      GoRoute(
        path: '/tienda/producto/:id',
        builder: (c, e) => PantallaProducto(productoId: _id(e)),
      ),
      _ruta('/carrito', const PantallaCarrito()),
      _ruta('/carrito/confirmar', const PantallaConfirmar()),
      GoRoute(
        path: '/pedidos/:id',
        builder: (c, e) => PantallaPedido(pedidoId: _id(e)),
      ),
      GoRoute(
        path: '/pedidos/:id/seguimiento',
        builder: (c, e) => PantallaSeguimiento(pedidoId: _id(e)),
      ),
      GoRoute(
        path: '/pedidos/:id/qr',
        builder: (c, e) => PantallaQr(pedidoId: _id(e)),
      ),
      _ruta('/notificaciones', const PantallaNotificaciones()),

      // ---- Pestañas del cliente ----
      StatefulShellRoute.indexedStack(
        builder: (context, estado, shell) => VigilanteAvisos(
          child: ShellCliente(
            shell: shell,
            pestanas: const [
              Pestana(Icons.storefront_outlined, Icons.storefront, 'Tienda'),
              Pestana(Icons.inventory_2_outlined, Icons.inventory_2, 'Pedidos'),
              Pestana(Icons.person_outline, Icons.person, 'Perfil'),
            ],
          ),
        ),
        branches: [
          StatefulShellBranch(routes: [_ruta('/tienda', const PantallaTienda())]),
          StatefulShellBranch(routes: [_ruta('/pedidos', const PantallaPedidos())]),
          StatefulShellBranch(routes: [_ruta('/perfil', const PantallaPerfil())]),
        ],
      ),
    ],
  );
});
