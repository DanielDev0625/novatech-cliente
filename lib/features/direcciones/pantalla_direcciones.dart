import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import 'api_direcciones.dart';
import 'pantalla_agregar_direccion.dart';

/// Máximo que acepta el servidor.
const maxDirecciones = 10;

/// «Mis direcciones»: la principal arriba; el menú ⋮ permite elegirla o borrarla.
class PantallaDirecciones extends ConsumerWidget {
  const PantallaDirecciones({super.key});

  Future<void> _ejecutar(BuildContext context, Future<void> Function() accion, String hecho) async {
    try {
      await accion();
      if (context.mounted) mostrarMensaje(context, hecho);
    } on ErrorApi catch (e) {
      if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valor = ref.watch(direccionesProvider);
    final acciones = ref.read(accionesDireccionesProvider);
    final lista = valor.valueOrNull ?? const <Direccion>[];

    return Esqueleto(
      titulo: 'Mis direcciones',
      alRecargar: () => ref.refresh(direccionesProvider.future),
      accionInferior: FilledButton.icon(
        onPressed: lista.length >= maxDirecciones ? null : () => context.push('/direcciones/agregar'),
        icon: const Icon(Icons.add),
        label: const Text('Agregar dirección'),
      ),
      hijos: [
        VistaAsync<List<Direccion>>(
          valor: valor,
          alReintentar: () => ref.invalidate(direccionesProvider),
          datos: (direcciones) {
            if (direcciones.isEmpty) return const SinDireccion();
            return Column(
              children: [
                for (final d in direcciones)
                  _TarjetaDireccion(
                    direccion: d,
                    alElegir: () => _ejecutar(
                      context,
                      () => acciones.marcarPrincipal(d.id),
                      'Tus pedidos llegarán a ${d.etiqueta.texto.toLowerCase()}',
                    ),
                    alBorrar: () async {
                      final ok = await confirmar(
                        context,
                        titulo: 'Borrar dirección',
                        texto: '¿Borrar «${d.etiqueta.texto} · ${d.textoCorto}»?',
                        aceptar: 'Borrar',
                      );
                      if (ok && context.mounted) {
                        await _ejecutar(context, () => acciones.borrar(d.id), 'Dirección borrada');
                      }
                    },
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Los pedidos usan tu dirección principal',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

enum _Opcion { principal, borrar }

class _TarjetaDireccion extends StatelessWidget {
  const _TarjetaDireccion({required this.direccion, required this.alElegir, required this.alBorrar});

  final Direccion direccion;
  final VoidCallback alElegir;
  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context) {
    final d = direccion;
    final detalle = [d.textoCorto, if (d.indicaciones != null) d.indicaciones!].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tocar una dirección que no es la principal la vuelve principal.
        onTap: d.principal ? null : alElegir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Icon(iconoEtiqueta(d.etiqueta), color: ColoresNovaTech.azul, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(d.etiqueta.texto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (d.principal) ...[
                          const SizedBox(width: 8),
                          const Insignia(texto: 'Principal', color: ColoresNovaTech.verde),
                        ],
                      ],
                    ),
                    Text(detalle, style: const TextStyle(color: ColoresNovaTech.textoSuave)),
                  ],
                ),
              ),
              PopupMenuButton<_Opcion>(
                tooltip: 'Opciones',
                icon: const Icon(Icons.more_vert),
                onSelected: (o) => o == _Opcion.principal ? alElegir() : alBorrar(),
                itemBuilder: (_) => [
                  if (!d.principal)
                    const PopupMenuItem(value: _Opcion.principal, child: Text('Usar como principal')),
                  const PopupMenuItem(value: _Opcion.borrar, child: Text('Borrar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
