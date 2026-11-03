import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Convierte la posición del pin en una dirección escrita («Cra 43 #84-20, Barranquilla»).
/// Usa Nominatim de OpenStreetMap (gratis y sin llave; máximo una consulta por segundo,
/// por eso la pantalla solo pregunta cuando el mapa deja de moverse).
class Geocodificador {
  Geocodificador()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://nominatim.openstreetmap.org',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            // Nominatim pide identificar la app que consulta. En el navegador no se puede
            // cambiar el User-Agent (lo identifica la página que hace la consulta).
            headers: kIsWeb ? null : {'User-Agent': 'NovaTechCliente/1.0 (app de pedidos de NovaTech)'},
          ),
        );

  final Dio _dio;

  /// Dirección del punto, o null si no se encontró o no hay internet. Nunca lanza.
  Future<String?> direccionDe(double latitud, double longitud) async {
    try {
      final r = await _dio.get('/reverse', queryParameters: {
        'format': 'jsonv2',
        'lat': latitud,
        'lon': longitud,
        'zoom': 18,
        'addressdetails': 1,
        'accept-language': 'es',
      });
      final datos = r.data;
      if (datos is! Map || datos['address'] is! Map) return null;
      return textoDireccion(Map<String, dynamic>.from(datos['address'] as Map));
    } catch (_) {
      return null;
    }
  }
}

/// Arma «Cra 43 #84-20, Barranquilla» con las partes que devuelve Nominatim.
String? textoDireccion(Map<String, dynamic> partes) {
  String? leer(List<String> claves) {
    for (final c in claves) {
      final v = partes[c];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  final via = leer(['road', 'pedestrian', 'footway', 'residential', 'neighbourhood', 'suburb']);
  if (via == null) return null;
  final numero = leer(['house_number']);
  // En Colombia OSM suele llamar a la ciudad «Perímetro Urbano Barranquilla».
  final ciudad = leer(['city', 'town', 'village', 'municipality', 'county'])
      ?.replaceFirst(RegExp(r'^Per[ií]metro Urbano\s+', caseSensitive: false), '');

  final calle = StringBuffer(abreviarVia(via));
  if (numero != null) calle.write(numero.startsWith('#') ? ' $numero' : ' #$numero');
  return ciudad == null ? calle.toString() : '$calle, $ciudad';
}

/// «Carrera 43» → «Cra 43», «Avenida Calle 72» → «Av Calle 72», como se escribe en Colombia.
String abreviarVia(String via) {
  const abreviaturas = {
    'carrera': 'Cra',
    'avenida': 'Av',
    'diagonal': 'Dg',
    'transversal': 'Tv',
    'circular': 'Cir',
  };
  final partes = via.split(' ');
  final primera = abreviaturas[partes.first.toLowerCase()];
  if (primera == null) return via;
  return [primera, ...partes.skip(1)].join(' ');
}

final geocodificadorProvider = Provider<Geocodificador>((ref) => Geocodificador());
