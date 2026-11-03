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

  List<Map<String, dynamic>> _ordenadas() =>
      [...direcciones]..sort((a, b) => (b['principal'] ? 1 : 0) - (a['principal'] ? 1 : 0));

  @override
  Future<void> despertar() async {}

  @override
  Future<Usuario> perfil() async => Usuario.fromJson(usuarioJson());

  @override
  Future<dynamic> get(String ruta, {Map<String, dynamic>? parametros}) async => switch (ruta) {
        '/direcciones' => _ordenadas(),
        '/catalogo' => catalogo,
        _ => throw ErrorApi('Ruta no simulada: $ruta'),
      };

  @override
  Future<dynamic> post(String ruta, {Object? datos, Map<String, dynamic>? parametros}) async {
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
