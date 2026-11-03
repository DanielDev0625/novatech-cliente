import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/cliente_api.dart';
import '../../core/api/modelos.dart';
import '../../core/tema/tema.dart';
import '../../core/ubicacion.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import '../../core/widgets/vista_async.dart';
import 'api_direcciones.dart';
import 'geocodificador.dart';

/// Centro de Barranquilla: donde arranca el mapa si no hay GPS.
const centroPorDefecto = LatLng(10.9878, -74.7889);

IconData iconoEtiqueta(EtiquetaDireccion e) => switch (e) {
      EtiquetaDireccion.casa => Icons.home_outlined,
      EtiquetaDireccion.oficina => Icons.apartment_outlined,
      EtiquetaDireccion.otra => Icons.place_outlined,
    };

/// «Agregar dirección»: el pin queda fijo en el centro y se mueve el mapa debajo.
/// La dirección escrita se completa sola al soltar el mapa.
class PantallaAgregarDireccion extends ConsumerStatefulWidget {
  const PantallaAgregarDireccion({super.key});

  @override
  ConsumerState<PantallaAgregarDireccion> createState() => _PantallaAgregarDireccionState();
}

class _PantallaAgregarDireccionState extends ConsumerState<PantallaAgregarDireccion> {
  final _mapa = MapController();
  final _indicaciones = TextEditingController();

  LatLng _centro = centroPorDefecto;
  String? _texto;
  bool _buscando = true;
  bool _moviendo = false;
  bool _guardando = false;
  bool _corregidaAMano = false;
  EtiquetaDireccion _etiqueta = EtiquetaDireccion.casa;
  Timer? _espera;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Mientras el GPS responde (o se acepta el permiso) ya se busca el centro de la ciudad.
      _buscarDireccion();
      _irAMiUbicacion(primeraVez: true);
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    _indicaciones.dispose();
    _mapa.dispose();
    super.dispose();
  }

  Future<void> _irAMiUbicacion({bool primeraVez = false}) async {
    final punto = await ubicacionActual();
    if (!mounted) return;
    if (punto == null) {
      // Sin GPS se queda en el centro de la ciudad; solo se avisa si la persona lo pidió.
      if (!primeraVez) {
        mostrarMensaje(context, 'No pudimos ver tu ubicación. Revisa el permiso o mueve el mapa.', error: true);
      }
      return;
    }
    _centro = LatLng(punto.latitud, punto.longitud);
    _mapa.move(_centro, 17);
    _buscarDireccion();
  }

  void _alMoverMapa(MapEvent evento) {
    if (evento is MapEventMoveStart || evento is MapEventMove) {
      if (!_moviendo) setState(() => _moviendo = true);
    }
    if (evento is MapEventMoveEnd || evento is MapEventFlingAnimationEnd) {
      setState(() => _moviendo = false);
      _centro = evento.camera.center;
      // Se espera un momento antes de preguntar (y solo una vez por movimiento).
      _espera?.cancel();
      _espera = Timer(const Duration(milliseconds: 700), _buscarDireccion);
    }
  }

  Future<void> _buscarDireccion() async {
    final consulta = ++_consulta;
    setState(() => _buscando = true);
    final texto = await ref.read(geocodificadorProvider).direccionDe(_centro.latitude, _centro.longitude);
    if (!mounted || consulta != _consulta) return; // Llegó una consulta más nueva.
    setState(() {
      _buscando = false;
      _corregidaAMano = false;
      _texto = texto;
    });
  }

  Future<void> _corregir() async {
    final controlador = TextEditingController(text: _texto ?? '');
    final nuevo = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Corregir dirección'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej.: Cra 43 #84-20, Barranquilla'),
          onSubmitted: (v) => Navigator.pop(contexto, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(contexto, controlador.text),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    controlador.dispose();
    if (nuevo == null || nuevo.trim().isEmpty) return;
    setState(() {
      _texto = nuevo.trim();
      _corregidaAMano = true;
    });
  }

  Future<void> _confirmar() async {
    final texto = _texto;
    if (texto == null || texto.length < 5) {
      mostrarMensaje(context, 'Escribe la dirección tocando «Corregir».', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref.read(accionesDireccionesProvider).agregar(
            etiqueta: _etiqueta,
            texto: texto,
            latitud: _centro.latitude,
            longitud: _centro.longitude,
            indicaciones: _indicaciones.text,
            // La que se acaba de agregar es donde se quiere recibir, como en las apps de domicilios.
            principal: true,
          );
      if (mounted) context.pop();
    } on ErrorApi catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// La dirección encontrada no trae «#84-20» (pasa a menudo en OpenStreetMap).
  bool get _faltaNumero => !_buscando && !_moviendo && _texto != null && !_texto!.contains('#');

  @override
  Widget build(BuildContext context) {
    final listo = _texto != null && !_buscando && !_moviendo;

    return Scaffold(
      appBar: barraNovaTech(titulo: 'Agregar dirección'),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapa,
                  options: MapOptions(
                    initialCenter: centroPorDefecto,
                    initialZoom: 15,
                    onMapEvent: _alMoverMapa,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.novatech.novatech_cliente',
                    ),
                    const SimpleAttributionWidget(source: Text('OpenStreetMap')),
                  ],
                ),
                // Pin fijo en el centro: la punta marca el lugar exacto.
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(0, _moviendo ? -30 : -22),
                      child: const Icon(Icons.location_on, size: 48, color: ColoresNovaTech.rojo),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: ColoresNovaTech.azul.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 28,
                  child: FloatingActionButton.small(
                    heroTag: 'mi-ubicacion',
                    tooltip: 'Ir a mi ubicación',
                    backgroundColor: Colors.white,
                    foregroundColor: ColoresNovaTech.azul,
                    onPressed: _irAMiUbicacion,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _corregidaAMano ? 'Dirección (corregida)' : 'Dirección (se completa sola)',
                                style: const TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              if (_buscando || _moviendo)
                                const Text('Buscando la dirección…', style: TextStyle(fontWeight: FontWeight.w700))
                              else
                                Text(
                                  _texto ?? 'No encontramos la dirección de este punto',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                _faltaNumero ? 'Agrega el número de la casa con «Corregir»' : 'Mueve el pin si hace falta',
                                style: TextStyle(
                                  color: _faltaNumero ? ColoresNovaTech.naranja : ColoresNovaTech.textoSuave,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(onPressed: _corregir, child: const Text('Corregir')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in EtiquetaDireccion.values)
                      ChoiceChip(
                        avatar: Icon(
                          iconoEtiqueta(e),
                          size: 18,
                          color: e == _etiqueta ? Colors.white : ColoresNovaTech.texto,
                        ),
                        label: Text(e.texto),
                        selected: e == _etiqueta,
                        onSelected: (_) => setState(() => _etiqueta = e),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _indicaciones,
                  maxLength: 255,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Apartamento, portería (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                onPressed: listo && !_guardando ? _confirmar : null,
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Confirmar dirección'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro para usar cuando todavía no hay direcciones (tienda y lista).
class SinDireccion extends StatelessWidget {
  const SinDireccion({super.key});

  @override
  Widget build(BuildContext context) {
    return TarjetaAviso(
      icono: Icons.add_location_alt_outlined,
      texto: '¿Dónde te entregamos? Agrega tu dirección',
      color: ColoresNovaTech.azul,
      onTap: () => context.push('/direcciones/agregar'),
    );
  }
}
