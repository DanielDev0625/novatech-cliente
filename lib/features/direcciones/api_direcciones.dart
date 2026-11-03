import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/sesion/sesion.dart';

/// Direcciones del cliente (la principal primero, como las ordena el servidor).
/// Se vuelven a pedir al cambiar la sesión: otra persona nunca ve las de la anterior.
final direccionesProvider = FutureProvider<List<Direccion>>((ref) async {
  ref.watch(sesionProvider.select((s) => s.token));
  final datos = await ref.read(clienteApiProvider).get('/direcciones') as List;
  return [for (final d in datos) Direccion.fromJson(Map<String, dynamic>.from(d as Map))];
});

/// La dirección donde se entregan los pedidos (null si aún no hay ninguna).
final direccionPrincipalProvider = Provider<AsyncValue<Direccion?>>((ref) {
  return ref.watch(direccionesProvider).whenData((lista) {
    for (final d in lista) {
      if (d.principal) return d;
    }
    return lista.isEmpty ? null : lista.first;
  });
});

/// Acciones sobre las direcciones. Cada una refresca la lista al terminar.
class AccionesDirecciones {
  AccionesDirecciones(this._ref);

  final Ref _ref;
  ClienteApi get _api => _ref.read(clienteApiProvider);

  Future<void> agregar({
    required EtiquetaDireccion etiqueta,
    required String texto,
    required double latitud,
    required double longitud,
    String? indicaciones,
    bool principal = false,
  }) async {
    await _api.post('/direcciones', datos: {
      'etiqueta': etiqueta.name,
      'texto': texto.trim(),
      'latitud': latitud,
      'longitud': longitud,
      'indicaciones': (indicaciones ?? '').trim().isEmpty ? null : indicaciones!.trim(),
      'principal': principal,
    });
    _ref.invalidate(direccionesProvider);
  }

  Future<void> marcarPrincipal(int id) async {
    await _api.patch('/direcciones/$id/principal');
    _ref.invalidate(direccionesProvider);
  }

  Future<void> borrar(int id) async {
    await _api.delete('/direcciones/$id');
    _ref.invalidate(direccionesProvider);
  }
}

final accionesDireccionesProvider = Provider<AccionesDirecciones>((ref) => AccionesDirecciones(ref));
