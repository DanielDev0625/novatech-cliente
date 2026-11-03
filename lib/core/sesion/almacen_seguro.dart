import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/modelos.dart';

/// Guarda la sesión en el almacén seguro del celular (Android Keystore / llavero de iOS).
class AlmacenSeguro {
  AlmacenSeguro()
      : _almacen = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _almacen;

  static const _kToken = 'token';
  static const _kUsuario = 'usuario_json';

  Future<void> guardarSesion(String token, Usuario usuario) async {
    await _almacen.write(key: _kToken, value: token);
    await _almacen.write(key: _kUsuario, value: jsonEncode(usuario.toJson()));
  }

  Future<(String, Usuario)?> leerSesion() async {
    final token = await _almacen.read(key: _kToken);
    final json = await _almacen.read(key: _kUsuario);
    if (token == null || json == null) return null;
    try {
      final usuario = Usuario.fromJson(jsonDecode(json) as Map<String, dynamic>);
      return (token, usuario);
    } catch (_) {
      return null;
    }
  }

  Future<void> borrarSesion() async {
    await _almacen.delete(key: _kToken);
    await _almacen.delete(key: _kUsuario);
  }
}
