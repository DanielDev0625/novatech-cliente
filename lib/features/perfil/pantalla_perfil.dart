import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/sesion/sesion.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';

/// Pestaña «Perfil»: con qué cuenta entró la persona y «Cerrar sesión».
class PantallaPerfil extends ConsumerWidget {
  const PantallaPerfil({super.key});

  Future<void> _salir(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(context, titulo: 'Cerrar sesión', texto: '¿Quieres cerrar tu sesión?', aceptar: 'Salir');
    if (ok) await ref.read(sesionProvider.notifier).cerrarSesion();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider.select((s) => s.usuario));
    if (usuario == null) return const SizedBox.shrink();

    return Esqueleto(
      titulo: 'Perfil',
      accionInferior: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: ColoresNovaTech.rojo,
          side: const BorderSide(color: ColoresNovaTech.rojo),
        ),
        onPressed: () => _salir(context, ref),
        child: const Text('Cerrar sesión'),
      ),
      hijos: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: ColoresNovaTech.azul.withValues(alpha: 0.12),
                  child: Text(
                    iniciales(usuario.nombre),
                    style: const TextStyle(color: ColoresNovaTech.azul, fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usuario.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('@${usuario.usuario}', style: const TextStyle(color: ColoresNovaTech.textoSuave)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.place_outlined),
          title: const Text('Mis direcciones'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/direcciones'),
        ),
        const Divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notificaciones'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/notificaciones'),
        ),
        const Divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Permisos: ubicación'),
          trailing: const Icon(Icons.chevron_right),
          // Abre los ajustes de la app en el celular para darlo o quitarlo.
          onTap: Geolocator.openAppSettings,
        ),
        const Divider(),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'La app solo usa tu ubicación para elegir la dirección. No pide cámara ni archivos.',
            style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
