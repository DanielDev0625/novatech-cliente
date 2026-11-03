import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'modelos.dart';

class ConfigApi {
  ConfigApi._();

  /// Dirección del backend. Para probar contra tu computador (emulador Android):
  ///   flutter run --dart-define=API_URL=http://10.0.2.2:8000
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://novatech-backend.vercel.app',
  );
}

/// Error ya traducido a un mensaje que se le puede mostrar a la persona.
class ErrorApi implements Exception {
  ErrorApi(this.mensaje, [this.codigo]);

  final String mensaje;
  final int? codigo;

  @override
  String toString() => mensaje;
}

ErrorApi errorDesde(Object error) {
  if (error is ErrorApi) return error;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ErrorApi(
          'No se pudo conectar con el servidor. Revisa tu internet e inténtalo de nuevo.',
        );
      default:
        break;
    }
    final codigo = error.response?.statusCode;
    final datos = error.response?.data;
    if (datos is Map && datos['detail'] != null) {
      final detalle = datos['detail'];
      if (detalle is String) return ErrorApi(detalle, codigo);
      if (detalle is Map && detalle['mensaje'] is String) {
        return ErrorApi(detalle['mensaje'] as String, codigo);
      }
      if (detalle is List) {
        // Validaciones propias del servidor (p. ej. «Usuario inválido»).
        final primero = detalle.isNotEmpty ? detalle.first : null;
        final texto = primero is Map ? primero['msg'] : null;
        if (texto is String && texto.startsWith('Value error, ')) {
          return ErrorApi(texto.substring('Value error, '.length), codigo);
        }
        return ErrorApi('Revisa los datos ingresados.', codigo);
      }
    }
    if (codigo == 503) {
      return ErrorApi(
        'El servidor no está disponible por ahora. Inténtalo en un momento.',
        codigo,
      );
    }
    final textoCodigo = codigo?.toString() ?? 'sin código';
    return ErrorApi('Ocurrió un error inesperado ($textoCodigo).', codigo);
  }
  return ErrorApi('Ocurrió un error inesperado.');
}

/// Cliente HTTP del backend. Pone el token en cada petición y avisa cuando
/// el servidor responde 401 (sesión vencida o cerrada).
class ClienteApi {
  ClienteApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ConfigApi.baseUrl,
          // El primer llamado a Vercel puede tardar un poco (arranque en frío).
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opciones, manejador) {
          final actual = token;
          // Una petición puede traer su propio token (p. ej. el aviso de salida).
          if (actual != null && !opciones.headers.containsKey('Authorization')) {
            opciones.headers['Authorization'] = 'Bearer $actual';
          }
          manejador.next(opciones);
        },
        onError: (error, manejador) {
          final sinSesion = error.requestOptions.extra['sinSesion'] == true;
          // Solo cuenta si la petición iba con la sesión actual (no con una anterior).
          final conSesionActual = token != null &&
              error.requestOptions.headers['Authorization'] == 'Bearer $token';
          if (error.response?.statusCode == 401 && conSesionActual && !sinSesion) {
            alNoAutorizado?.call();
          }
          manejador.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  /// Token de sesión actual (lo asigna la sesión).
  String? token;

  /// Se llama cuando el servidor dice que la sesión ya no sirve.
  void Function()? alNoAutorizado;

  // ---- Métodos genéricos (los usarán las pantallas de las fases siguientes) ----

  Future<dynamic> get(String ruta, {Map<String, dynamic>? parametros}) async {
    try {
      final r = await _dio.get(ruta, queryParameters: parametros);
      return r.data;
    } on DioException catch (e) {
      throw errorDesde(e);
    }
  }

  Future<dynamic> post(
    String ruta, {
    Object? datos,
    Map<String, dynamic>? parametros,
  }) async {
    try {
      final r = await _dio.post(ruta, data: datos, queryParameters: parametros);
      return r.data;
    } on DioException catch (e) {
      throw errorDesde(e);
    }
  }

  Future<dynamic> put(String ruta, {Object? datos}) async {
    try {
      final r = await _dio.put(ruta, data: datos);
      return r.data;
    } on DioException catch (e) {
      throw errorDesde(e);
    }
  }

  Future<dynamic> patch(String ruta, {Object? datos}) async {
    try {
      final r = await _dio.patch(ruta, data: datos);
      return r.data;
    } on DioException catch (e) {
      throw errorDesde(e);
    }
  }

  Future<void> delete(String ruta) async {
    try {
      await _dio.delete(ruta);
    } on DioException catch (e) {
      throw errorDesde(e);
    }
  }

  // ---- Sesión del cliente (C1): cuenta propia con usuario y contraseña ----

  Future<Map<String, dynamic>> _postSinSesion(String ruta, Map<String, dynamic> datos) async {
    try {
      final r = await _dio.post(ruta, data: datos, options: Options(extra: {'sinSesion': true}));
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw errorDesde(e);
    }
  }

  /// Entra con usuario y contraseña. Devuelve token y usuario.
  Future<Map<String, dynamic>> iniciarSesion(String usuario, String password) =>
      _postSinSesion('/auth/login-cliente', {'usuario': usuario, 'password': password});

  /// Crea la cuenta del cliente y entra. Devuelve token y usuario.
  Future<Map<String, dynamic>> registrarse(String nombre, String usuario, String password) =>
      _postSinSesion('/auth/registro-cliente', {'nombre': nombre, 'usuario': usuario, 'password': password});

  Future<Usuario> perfil() async {
    final datos = await get('/auth/perfil');
    return Usuario.fromJson(Map<String, dynamic>.from(datos as Map));
  }

  /// Despierta el servidor (Vercel apaga las funciones que no se usan). Se llama al
  /// abrir la app para que el ingreso no cargue con ese arranque. Nunca falla.
  Future<void> despertar() async {
    try {
      await _dio.get(
        '/salud',
        options: Options(extra: {'sinSesion': true}, receiveTimeout: const Duration(seconds: 15)),
      );
    } catch (_) {
      // Si no responde, el ingreso lo intentará igual.
    }
  }
}

final clienteApiProvider = Provider<ClienteApi>((ref) => ClienteApi());
