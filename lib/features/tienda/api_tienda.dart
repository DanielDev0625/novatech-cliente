import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/sesion/sesion.dart';
import '../../core/tema/tema.dart';

/// Catálogo completo (solo productos con stock). Se pide una vez y se filtra en el celular.
final catalogoProvider = FutureProvider<List<Producto>>((ref) async {
  ref.watch(sesionProvider.select((s) => s.token));
  final datos = await ref.read(clienteApiProvider).get('/catalogo') as List;
  return [for (final p in datos) Producto.fromJson(Map<String, dynamic>.from(p as Map))];
});

/// Categorías que tienen al menos un producto disponible, en el orden de la tienda.
List<String> categoriasCon(List<Producto> productos) {
  const orden = [
    'Procesadores',
    'Tarjetas gráficas',
    'Memoria RAM',
    'SSD',
    'Tarjetas madre',
    'Fuentes de poder',
    'Otros',
  ];
  final presentes = {for (final p in productos) p.categoria};
  return [
    for (final c in orden)
      if (presentes.contains(c)) c,
    for (final c in presentes.toList()..sort())
      if (!orden.contains(c)) c,
  ];
}

/// Nombre corto para las píldoras («Memoria RAM» → «RAM»).
String categoriaCorta(String categoria) => switch (categoria) {
      'Memoria RAM' => 'RAM',
      'Tarjetas gráficas' => 'Gráficas',
      'Fuentes de poder' => 'Fuentes',
      _ => categoria,
    };

/// Ícono y color de cada categoría (los acentos de la marca).
(IconData, Color) estiloCategoria(String categoria) => switch (categoria) {
      'Procesadores' => (Icons.memory, ColoresNovaTech.azul),
      'Tarjetas gráficas' => (Icons.monitor, ColoresNovaTech.verde),
      'Memoria RAM' => (Icons.view_week_outlined, ColoresNovaTech.naranja),
      'SSD' => (Icons.storage, ColoresNovaTech.azul),
      'Tarjetas madre' => (Icons.developer_board, ColoresNovaTech.verde),
      'Fuentes de poder' => (Icons.power, ColoresNovaTech.rojo),
      _ => (Icons.devices_other, ColoresNovaTech.textoSuave),
    };

/// Recuadro de color con el ícono de la categoría (en lugar de foto del producto).
class IconoCategoria extends StatelessWidget {
  const IconoCategoria({super.key, required this.categoria, this.alto = 64, this.tamano = 30});

  final String categoria;
  final double alto;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final (icono, color) = estiloCategoria(categoria);
    return Container(
      height: alto,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
      child: Center(child: Icon(icono, color: color, size: tamano)),
    );
  }
}
