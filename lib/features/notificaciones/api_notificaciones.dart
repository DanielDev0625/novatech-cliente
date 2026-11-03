import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/sesion/sesion.dart';

/// Avisos de los últimos 30 días (el más nuevo primero).
final notificacionesProvider = FutureProvider<List<Notificacion>>((ref) async {
  ref.watch(sesionProvider.select((s) => s.token));
  final datos = await ref.read(clienteApiProvider).get('/notificaciones') as List;
  return [for (final n in datos) Notificacion.fromJson(Map<String, dynamic>.from(n as Map))];
});

/// Hasta qué aviso vio el cliente. Se guarda en el celular, por persona.
class VistasNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final usuario = ref.watch(sesionProvider.select((s) => s.usuario?.id));
    if (usuario == null) return 0;
    return ref.read(almacenSeguroProvider).ultimaNotificacionVista(usuario);
  }

  /// Marca como vistas todas hasta [id].
  Future<void> marcarHasta(int id) async {
    final usuario = ref.read(sesionProvider).usuario?.id;
    if (usuario == null || id <= (state.valueOrNull ?? 0)) return;
    state = AsyncData(id);
    await ref.read(almacenSeguroProvider).guardarNotificacionVista(usuario, id);
  }
}

final vistasProvider = AsyncNotifierProvider<VistasNotifier, int>(VistasNotifier.new);

/// Cuántos avisos no ha visto (para el punto rojo de la campana).
final sinLeerProvider = Provider<int>((ref) {
  final lista = ref.watch(notificacionesProvider).valueOrNull;
  final vista = ref.watch(vistasProvider).valueOrNull;
  if (lista == null || vista == null) return 0;
  return lista.where((n) => n.id > vista).length;
});
