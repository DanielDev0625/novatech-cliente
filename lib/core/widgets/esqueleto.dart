import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tema/tema.dart';
import 'adaptable.dart';
import 'marca.dart';

/// Barra superior de la app del cliente: azul con las franjas de la marca debajo.
/// Con [etiqueta] muestra dos líneas (p. ej. «Entregar en» / «Casa · Cra 43 #84-20»), como en el diseño.
/// Con [alTocarTitulo] el título lleva una flecha ⌄ y se puede tocar (p. ej. para cambiar la dirección).
PreferredSizeWidget barraNovaTech({
  required String titulo,
  String? etiqueta,
  List<Widget>? acciones,
  VoidCallback? alTocarTitulo,
}) {
  final textoTitulo = Text(
    titulo,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: etiqueta != null ? 20 : 18, fontWeight: FontWeight.w600, color: Colors.white),
  );
  return AppBar(
    toolbarHeight: etiqueta != null ? 64.0 : kToolbarHeight,
    titleSpacing: etiqueta != null ? 20 : null,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (etiqueta != null)
          Text(etiqueta, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w400)),
        if (alTocarTitulo == null)
          textoTitulo
        else
          InkWell(
            onTap: alTocarTitulo,
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: textoTitulo),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
            ),
          ),
      ],
    ),
    actions: acciones,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(4),
      child: FranjaColores(ancho: double.infinity, alto: 4),
    ),
  );
}

/// Pantalla con encabezado, lista con jalar-para-recargar y un botón grande abajo.
class Esqueleto extends StatelessWidget {
  const Esqueleto({
    super.key,
    required this.titulo,
    required this.hijos,
    this.etiqueta,
    this.alRecargar,
    this.accionInferior,
    this.alTocarTitulo,
    this.acciones,
  });

  final String titulo;
  final String? etiqueta;
  final List<Widget> hijos;
  final Future<void> Function()? alRecargar;

  /// Botón grande fijo abajo (p. ej. «Cerrar sesión»).
  final Widget? accionInferior;

  final VoidCallback? alTocarTitulo;

  /// Botones a la derecha del encabezado (p. ej. la campana).
  final List<Widget>? acciones;

  @override
  Widget build(BuildContext context) {
    final lista = LayoutBuilder(
      builder: (context, limites) {
        final margen = math.max(16.0, (limites.maxWidth - anchoContenido) / 2);
        return ListView(
          padding: EdgeInsets.fromLTRB(margen, 12, margen, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: hijos,
        );
      },
    );
    final recargar = alRecargar;

    return Scaffold(
      appBar: barraNovaTech(
        titulo: titulo,
        etiqueta: etiqueta,
        alTocarTitulo: alTocarTitulo,
        acciones: [
          // Con mouse no se puede «jalar para recargar»: en la web hay botón.
          if (kIsWeb && recargar != null)
            IconButton(
              tooltip: 'Actualizar',
              onPressed: recargar,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ...?acciones,
        ],
      ),
      body: Column(
        children: [
          Expanded(child: recargar == null ? lista : RefreshIndicator(onRefresh: recargar, child: lista)),
          if (accionInferior != null)
            SafeArea(
              top: false,
              child: ContenidoCentrado(
                child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: accionInferior),
              ),
            ),
        ],
      ),
    );
  }
}

/// Una pestaña de la navegación inferior.
class Pestana {
  const Pestana(this.icono, this.iconoActivo, this.etiqueta);

  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
}

/// Navegación inferior del cliente (Tienda · Pedidos · Perfil): cada pestaña conserva su pantalla.
class ShellCliente extends StatelessWidget {
  const ShellCliente({super.key, required this.shell, required this.pestanas});

  final StatefulNavigationShell shell;
  final List<Pestana> pestanas;

  @override
  Widget build(BuildContext context) {
    // Tocar la pestaña activa vuelve a su pantalla inicial.
    void ir(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

    // Computador (web): menú lateral azul unido al encabezado, como en la app del personal.
    if (esEscritorio(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: ir,
              labelType: NavigationRailLabelType.all,
              backgroundColor: ColoresNovaTech.azul,
              indicatorColor: Colors.white.withValues(alpha: 0.18),
              selectedIconTheme: const IconThemeData(color: Colors.white),
              unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.7)),
              selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              leading: const Padding(
                padding: EdgeInsets.only(top: 14, bottom: 18),
                child: Tooltip(message: 'NovaTech', child: SimboloNovaTech(tamano: 38)),
              ),
              destinations: [
                for (final p in pestanas)
                  NavigationRailDestination(icon: Icon(p.icono), selectedIcon: Icon(p.iconoActivo), label: Text(p.etiqueta)),
              ],
            ),
            const VerticalDivider(width: 1, color: ColoresNovaTech.borde),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: ColoresNovaTech.borde))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: ir,
          destinations: [
            for (final p in pestanas)
              NavigationDestination(icon: Icon(p.icono), selectedIcon: Icon(p.iconoActivo), label: p.etiqueta),
          ],
        ),
      ),
    );
  }
}

/// «Camila Torres» → «CT».
String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  final primera = partes.first[0];
  final segunda = partes.length > 1 ? partes[1][0] : '';
  return (primera + segunda).toUpperCase();
}
