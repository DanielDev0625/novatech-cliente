import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novatech_cliente/core/api/cliente_api.dart';
import 'package:novatech_cliente/core/api/modelos.dart';
import 'package:novatech_cliente/core/sesion/almacen_seguro.dart';
import 'package:novatech_cliente/core/sesion/sesion.dart';
import 'package:novatech_cliente/features/direcciones/geocodificador.dart';
import 'package:novatech_cliente/main.dart';

/// Token con vencimiento (la firma no importa: la revisa el servidor).
String tokenDePrueba({Duration dura = const Duration(days: 30)}) {
  String parte(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(dura).millisecondsSinceEpoch ~/ 1000;
  return '${parte({'alg': 'HS256'})}.${parte({'sub': '7', 'rol': 'usuario', 'exp': exp})}.firma';
}

Map<String, dynamic> usuarioJson({String usuario = 'camila.t', String rol = 'usuario', String nombre = 'Camila Torres'}) =>
    {'id': 7, 'nombre': nombre, 'usuario': usuario, 'rol': rol, 'activo': true};

Map<String, dynamic> productoJson(int id, String nombre, String categoria, num precio, int stock) => {
      'id': id,
      'sku': 'SKU-$id',
      'nombre': nombre,
      'marca': 'Marca$id',
      'categoria': categoria,
      'precio': precio,
      'stock': stock,
    };

class AlmacenFalso extends AlmacenSeguro {
  (String, Usuario)? guardada;

  @override
  Future<void> guardarSesion(String token, Usuario usuario) async => guardada = (token, usuario);

  @override
  Future<(String, Usuario)?> leerSesion() async => guardada;

  @override
  Future<void> borrarSesion() async => guardada = null;

  final vistas = <int, int>{};

  @override
  Future<int> ultimaNotificacionVista(int usuarioId) async => vistas[usuarioId] ?? 0;

  @override
  Future<void> guardarNotificacionVista(int usuarioId, int id) async => vistas[usuarioId] = id;
}

/// Servidor en memoria: cuentas, direcciones y catálogo.
class ApiFalsa extends ClienteApi {
  final cuentas = <String, String>{'camila.t': 'clave1234'};
  final registros = <String>[];
  String rol = 'usuario';

  final direcciones = <Map<String, dynamic>>[];
  int _siguiente = 1;
  final catalogo = <Map<String, dynamic>>[
    productoJson(1, 'Ryzen 5 7600', 'Procesadores', 899000, 8),
    productoJson(2, 'RTX 4060 8 GB', 'Tarjetas gráficas', 1649000, 2),
    productoJson(3, 'RAM DDR5 16 GB', 'Memoria RAM', 310000, 1),
  ];

  void agregarDireccion(String etiqueta, String texto, {bool principal = false}) {
    if (principal || direcciones.isEmpty) {
      for (final d in direcciones) {
        d['principal'] = false;
      }
      principal = true;
    }
    direcciones.add({
      'id': _siguiente++,
      'etiqueta': etiqueta,
      'texto': texto,
      'latitud': 10.99,
      'longitud': -74.8,
      'indicaciones': null,
      'principal': principal,
    });
  }

  /// Pedidos guardados (como los devuelve el servidor) y envío vigente.
  final pedidos = <Map<String, dynamic>>[];
  double costoEnvio = 8000;

  Map<String, dynamic> _producto(int id) => catalogo.firstWhere((p) => p['id'] == id);

  Map<String, dynamic> _crearPedido(Map<String, dynamic> datos) {
    final items = (datos['items'] as List).cast<Map<String, dynamic>>();
    for (final i in items) {
      final p = _producto(i['producto_id'] as int);
      if ((p['stock'] as int) < (i['cantidad'] as int)) {
        throw ErrorApi('Stock insuficiente de «${p['nombre']}»', 409);
      }
    }
    var total = 0.0;
    final lineas = <Map<String, dynamic>>[];
    for (final i in items) {
      final p = _producto(i['producto_id'] as int);
      final cantidad = i['cantidad'] as int;
      p['stock'] = (p['stock'] as int) - cantidad; // reserva
      final subtotal = (p['precio'] as num) * cantidad;
      total += subtotal;
      lineas.add({
        'producto_id': p['id'],
        'sku': p['sku'],
        'nombre': p['nombre'],
        'cantidad': cantidad,
        'precio_unitario': p['precio'],
        'subtotal': subtotal,
      });
    }
    final id = pedidos.length + 1;
    final pedido = <String, dynamic>{
      'id': id,
      'codigo': 'PED-2026-${id.toString().padLeft(4, '0')}',
      'estado': 'registrado',
      'cliente': null,
      'total': total,
      'costo_envio': costoEnvio,
      'total_a_pagar': total + costoEnvio,
      'metodo_pago': 'contra_entrega',
      'fecha_prometida': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      'creado_en': DateTime.now().toIso8601String(),
      'direccion': direcciones.firstWhere((d) => d['id'] == datos['direccion_id']),
      'lineas': lineas,
      'eventos': [
        {'estado': 'registrado', 'por': 'usuario', 'fecha': DateTime.now().toIso8601String()},
      ],
      'qr_entrega': 'qr-$id',
    };
    pedidos.add(pedido);
    _avisar(pedido, 'registrado');
    return pedido;
  }

  int _evento = 0;
  final notificaciones = <Map<String, dynamic>>[];

  /// Como si el personal moviera el pedido: cambia el estado y deja el aviso.
  void avanzar(int pedidoId, String estado, {double? latTransportista, double? lngTransportista, int? eta}) {
    final p = pedidos.firstWhere((p) => p['id'] == pedidoId);
    p['estado'] = estado;
    if (estado == 'entregado' || estado == 'cancelado') p['qr_entrega'] = null;
    (p['eventos'] as List).add({'estado': estado, 'por': 'operario', 'fecha': DateTime.now().toIso8601String()});
    _avisar(p, estado);
    seguimientos[pedidoId] = {
      'pedido_id': pedidoId,
      'codigo': p['codigo'],
      'estado': estado,
      'destino_latitud': 10.99,
      'destino_longitud': -74.8,
      'transportista_posicion': latTransportista == null
          ? null
          : {'latitud': latTransportista, 'longitud': lngTransportista, 'segundos_desde_actualizacion': 10},
      'parada': eta == null ? null : 2,
      'eta_minutos': eta,
    };
  }

  final seguimientos = <int, Map<String, dynamic>>{};

  void _avisar(Map<String, dynamic> p, String estado) {
    const titulos = {
      'registrado': 'Recibimos tu pedido',
      'alistando': 'Estamos alistando tu pedido',
      'en_ruta': 'Tu pedido va en camino',
      'entregado': 'Pedido entregado',
      'cancelado': 'Pedido cancelado',
    };
    notificaciones.insert(0, {
      'id': ++_evento,
      'pedido_id': p['id'],
      'codigo': p['codigo'],
      'estado': estado,
      'titulo': titulos[estado] ?? 'Tu pedido cambió',
      'texto': 'Detalle',
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic> _resumen(Map<String, dynamic> p) => {
        ...p,
        'unidades': (p['lineas'] as List).fold<int>(0, (s, l) => s + (l['cantidad'] as int)),
      };

  List<Map<String, dynamic>> _ordenadas() =>
      [...direcciones]..sort((a, b) => (b['principal'] ? 1 : 0) - (a['principal'] ? 1 : 0));

  @override
  Future<void> despertar() async {}

  @override
  Future<Usuario> perfil() async => Usuario.fromJson(usuarioJson());

  @override
  Future<dynamic> get(String ruta, {Map<String, dynamic>? parametros}) async => switch (ruta) {
        '/direcciones' => _ordenadas(),
        '/catalogo' => [for (final p in catalogo) if ((p['stock'] as int) > 0) p],
        '/pedidos/condiciones' => {'costo_envio': costoEnvio, 'plazo_entrega_dias': 2, 'metodo_pago': 'contra_entrega'},
        '/pedidos/mios' => [for (final p in pedidos.reversed) _resumen(p)],
        '/notificaciones' => notificaciones,
        _ when ruta.endsWith('/seguimiento') => seguimientos[int.parse(ruta.split('/')[2])] ??
            {
              'pedido_id': int.parse(ruta.split('/')[2]),
              'codigo': 'PED',
              'estado': pedidos.firstWhere((p) => p['id'] == int.parse(ruta.split('/')[2]))['estado'],
              'destino_latitud': 10.99,
              'destino_longitud': -74.8,
              'transportista_posicion': null,
              'parada': null,
              'eta_minutos': null,
            },
        _ when ruta.startsWith('/pedidos/') => pedidos.firstWhere((p) => p['id'] == int.parse(ruta.split('/')[2])),
        _ => throw ErrorApi('Ruta no simulada: $ruta'),
      };

  @override
  Future<dynamic> post(String ruta, {Object? datos, Map<String, dynamic>? parametros}) async {
    if (ruta == '/pedidos') return _crearPedido(datos! as Map<String, dynamic>);
    if (ruta.startsWith('/pedidos/') && ruta.endsWith('/cancelar')) {
      final p = pedidos.firstWhere((p) => p['id'] == int.parse(ruta.split('/')[2]));
      if (p['estado'] != 'registrado') throw ErrorApi('Ya no se puede cancelar', 409);
      for (final l in p['lineas'] as List) {
        final prod = _producto(l['producto_id'] as int);
        prod['stock'] = (prod['stock'] as int) + (l['cantidad'] as int);
      }
      p['estado'] = 'cancelado';
      _avisar(p, 'cancelado');
      return p;
    }
    if (ruta != '/direcciones') throw ErrorApi('Ruta no simulada: $ruta');
    final d = datos! as Map<String, dynamic>;
    agregarDireccion(d['etiqueta'] as String, d['texto'] as String, principal: d['principal'] as bool);
    return direcciones.last;
  }

  @override
  Future<dynamic> patch(String ruta, {Object? datos}) async {
    final id = int.parse(ruta.split('/')[2]);
    for (final d in direcciones) {
      d['principal'] = d['id'] == id;
    }
    return direcciones.firstWhere((d) => d['id'] == id);
  }

  @override
  Future<void> delete(String ruta) async {
    final id = int.parse(ruta.split('/')[2]);
    final eraPrincipal = direcciones.firstWhere((d) => d['id'] == id)['principal'] as bool;
    direcciones.removeWhere((d) => d['id'] == id);
    if (eraPrincipal && direcciones.isNotEmpty) direcciones.first['principal'] = true;
  }

  @override
  Future<Map<String, dynamic>> iniciarSesion(String usuario, String password) async {
    if (cuentas[usuario] != password) throw ErrorApi('Usuario o contraseña incorrectos', 401);
    return {'access_token': tokenDePrueba(), 'usuario': usuarioJson(usuario: usuario, rol: rol)};
  }

  @override
  Future<Map<String, dynamic>> registrarse(String nombre, String usuario, String password) async {
    if (cuentas.containsKey(usuario)) throw ErrorApi('Ese usuario ya existe', 409);
    cuentas[usuario] = password;
    registros.add('$nombre|$usuario');
    return {'access_token': tokenDePrueba(), 'usuario': usuarioJson(usuario: usuario, nombre: nombre)};
  }
}

class GeocodificadorFalso extends Geocodificador {
  @override
  Future<String?> direccionDe(double latitud, double longitud) async => 'Cra 43 #84-20, Barranquilla';
}

/// La app completa con el servidor, el almacén y el geocodificador falsos.
Widget appDePrueba(ApiFalsa api, AlmacenFalso almacen) => ProviderScope(
      overrides: [
        clienteApiProvider.overrideWithValue(api),
        almacenSeguroProvider.overrideWithValue(almacen),
        geocodificadorProvider.overrideWithValue(GeocodificadorFalso()),
      ],
      child: const NovaTechCliente(),
    );
