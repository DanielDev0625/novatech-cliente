import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/cliente_api.dart';
import '../api/modelos.dart';
import 'almacen_seguro.dart';
import 'token.dart';

/// Estado de la sesión que ve toda la app.
class EstadoSesion {
  const EstadoSesion({this.restaurando = false, this.usuario, this.token, this.aviso});

  /// true mientras se revisa si quedó una sesión guardada (pantalla de carga).
  final bool restaurando;
  final Usuario? usuario;
  final String? token;

  /// Mensaje para mostrar en el acceso (por ejemplo, «Tu sesión terminó»).
  final String? aviso;

  bool get autenticado => usuario != null && token != null;
}

final almacenSeguroProvider = Provider<AlmacenSeguro>((ref) => AlmacenSeguro());

class SesionNotifier extends Notifier<EstadoSesion> {
  ClienteApi get _api => ref.read(clienteApiProvider);
  AlmacenSeguro get _almacen => ref.read(almacenSeguroProvider);

  @override
  EstadoSesion build() {
    _api.alNoAutorizado = _sesionVencida;
    // Mientras la persona elige cómo entrar, el servidor ya se va despertando.
    unawaited(_api.despertar());
    Future.microtask(restaurar);
    return const EstadoSesion(restaurando: true);
  }

  /// Las escrituras en el almacén seguro van en orden, para que borrar la sesión
  /// anterior nunca pise la que se acaba de guardar.
  Future<void> _cola = Future.value();

  Future<void> _enCola(Future<void> Function() operacion) =>
      _cola = _cola.then((_) => operacion()).then((_) {}, onError: (_) {});

  /// Al abrir la app: si quedó una sesión vigente, entra de inmediato con ella y
  /// el servidor la confirma en segundo plano.
  Future<void> restaurar() async {
    final guardada = await _almacen.leerSesion();
    if (guardada != null) {
      final (token, usuario) = guardada;
      final expira = expiracionDelToken(token);
      if (expira != null && expira.isAfter(DateTime.now()) && usuario.rol.esCliente) {
        _api.token = token;
        state = EstadoSesion(usuario: usuario, token: token);
        unawaited(_confirmarSesion(token));
        return;
      }
      await _enCola(_almacen.borrarSesion);
    }
    state = const EstadoSesion();
  }

  /// Pide el perfil para confirmar que la sesión sigue vigente. Si el servidor responde
  /// 401, el cliente HTTP cierra la sesión solo; sin red se sigue con la guardada.
  Future<void> _confirmarSesion(String token) async {
    try {
      final actual = await _api.perfil();
      if (state.token != token) return; // Se salió o entró otra persona mientras tanto.
      if (!actual.rol.esCliente) {
        await _limpiar();
        return;
      }
      final anterior = state.usuario;
      if (anterior == null || anterior.nombre != actual.nombre || anterior.usuario != actual.usuario) {
        state = EstadoSesion(usuario: actual, token: token);
        unawaited(_enCola(() => _almacen.guardarSesion(token, actual)));
      }
    } catch (_) {
      // Sin red por ahora: la sesión guardada sigue sirviendo.
    }
  }

  /// Entra con usuario y contraseña. Lanza [ErrorApi] con el mensaje del servidor.
  Future<void> iniciarSesion(String usuario, String password) async {
    await _entrarCon(await _api.iniciarSesion(usuario.trim().toLowerCase(), password));
  }

  /// Crea la cuenta y entra de una vez.
  Future<void> registrarse(String nombre, String usuario, String password) async {
    await _entrarCon(await _api.registrarse(nombre.trim(), usuario.trim().toLowerCase(), password));
  }

  Future<void> _entrarCon(Map<String, dynamic> datos) async {
    final token = datos['access_token'] as String;
    final persona = Usuario.fromJson(Map<String, dynamic>.from(datos['usuario'] as Map));
    if (!persona.rol.esCliente) {
      throw ErrorApi('Esa cuenta es del personal. Usa la app del personal de NovaTech.');
    }
    _api.token = token;
    // Primero se entra; guardar en el almacén seguro sigue en segundo plano.
    state = EstadoSesion(usuario: persona, token: token);
    await _enCola(() => _almacen.guardarSesion(token, persona));
  }

  /// Botón «Cerrar sesión».
  Future<void> cerrarSesion() async {
    await _limpiar();
  }

  void _sesionVencida() {
    _limpiar(aviso: 'Tu sesión terminó. Entra de nuevo.');
  }

  Future<void> _limpiar({String? aviso}) async {
    _api.token = null;
    state = EstadoSesion(aviso: aviso);
    await _enCola(_almacen.borrarSesion);
  }
}

final sesionProvider = NotifierProvider<SesionNotifier, EstadoSesion>(SesionNotifier.new);
