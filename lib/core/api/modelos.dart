import '../formato.dart';

/// Roles del sistema: los mismos que devuelve el backend. En esta app solo entra el cliente
/// («usuario» en el backend); los demás roles usan la app del personal.
enum Rol {
  usuario,
  operario,
  transportista,
  gerente,
  administrador;

  static Rol desde(String? valor) =>
      Rol.values.firstWhere((r) => r.name == valor, orElse: () => Rol.operario);

  bool get esCliente => this == Rol.usuario;
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.rol,
    required this.activo,
  });

  final int id;
  final String nombre;

  /// Nombre de usuario con el que entra.
  final String usuario;
  final Rol rol;
  final bool activo;

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        usuario: json['usuario'] as String,
        rol: Rol.desde(json['rol'] as String?),
        activo: json['activo'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'usuario': usuario,
        'rol': rol.name,
        'activo': activo,
      };
}

/// Tipo de dirección (los mismos valores que acepta el backend).
enum EtiquetaDireccion {
  casa('Casa'),
  oficina('Oficina'),
  otra('Otra');

  const EtiquetaDireccion(this.texto);
  final String texto;

  static EtiquetaDireccion desde(String? valor) =>
      values.firstWhere((e) => e.name == valor, orElse: () => EtiquetaDireccion.otra);
}

/// Dirección de entrega guardada por el cliente.
class Direccion {
  const Direccion({
    required this.id,
    required this.etiqueta,
    required this.texto,
    required this.latitud,
    required this.longitud,
    required this.indicaciones,
    required this.principal,
  });

  final int id;
  final EtiquetaDireccion etiqueta;

  /// «Cra 43 #84-20, Barranquilla».
  final String texto;
  final double latitud;
  final double longitud;

  /// Apartamento, portería… (opcional).
  final String? indicaciones;

  /// Los pedidos usan la dirección principal.
  final bool principal;

  /// «Cra 43 #84-20» (sin la ciudad), para encabezados cortos.
  String get textoCorto => texto.split(',').first.trim();

  factory Direccion.fromJson(Map<String, dynamic> json) => Direccion(
        id: json['id'] as int,
        etiqueta: EtiquetaDireccion.desde(json['etiqueta'] as String?),
        texto: json['texto'] as String,
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        indicaciones: json['indicaciones'] as String?,
        principal: json['principal'] as bool? ?? false,
      );
}

/// Producto tal como lo ve el cliente: sin costos y solo si tiene stock.
class Producto {
  const Producto({
    required this.id,
    required this.sku,
    required this.nombre,
    required this.marca,
    required this.categoria,
    required this.precio,
    required this.stock,
  });

  final int id;
  final String sku;
  final String nombre;
  final String? marca;
  final String categoria;
  final double precio;

  /// Unidades disponibles.
  final int stock;

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        id: json['id'] as int,
        sku: json['sku'] as String,
        nombre: json['nombre'] as String,
        marca: json['marca'] as String?,
        categoria: json['categoria'] as String,
        precio: (json['precio'] as num).toDouble(),
        stock: json['stock'] as int? ?? 0,
      );
}

/// Estados del pedido, en el orden en que avanzan (los mismos del backend).
enum EstadoPedido {
  registrado('Registrado'),
  alistando('Alistando'),
  enZonaEnvios('En zona de envíos'),
  recibidoTransportista('Recibido por transportista'),
  enRuta('En ruta'),
  entregado('Entregado'),
  cancelado('Cancelado');

  const EstadoPedido(this.etiqueta);
  final String etiqueta;

  /// Valor que usa el backend («en_zona_envios»).
  String get valor => switch (this) {
        EstadoPedido.enZonaEnvios => 'en_zona_envios',
        EstadoPedido.recibidoTransportista => 'recibido_transportista',
        EstadoPedido.enRuta => 'en_ruta',
        _ => name,
      };

  static EstadoPedido desde(String? valor) =>
      values.firstWhere((e) => e.valor == valor, orElse: () => EstadoPedido.registrado);

  /// Entregado o cancelado: ya no cambia.
  bool get terminado => this == EstadoPedido.entregado || this == EstadoPedido.cancelado;

  /// El cliente solo puede cancelar antes de que lo empiecen a alistar.
  bool get cancelable => this == EstadoPedido.registrado;

  /// Pasos que ve el cliente en el seguimiento (sin «cancelado»).
  static const recorrido = [
    registrado,
    alistando,
    enZonaEnvios,
    recibidoTransportista,
    enRuta,
    entregado,
  ];
}

/// Solo hay una forma de pago: contra entrega (se paga al recibir).
const textoPago = 'Contra entrega';
const detallePago = 'Pagas al recibir tu pedido';

/// Pedido en la lista «Mis pedidos».
class PedidoResumen {
  const PedidoResumen({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.totalAPagar,
    required this.unidades,
    required this.fechaPrometida,
    required this.creadoEn,
  });

  final int id;
  final String codigo;
  final EstadoPedido estado;

  /// Productos + envío: lo que se paga al recibir.
  final double totalAPagar;
  final int unidades;
  final DateTime? fechaPrometida;
  final DateTime? creadoEn;

  factory PedidoResumen.fromJson(Map<String, dynamic> json) => PedidoResumen(
        id: json['id'] as int,
        codigo: json['codigo'] as String,
        estado: EstadoPedido.desde(json['estado'] as String?),
        totalAPagar: ((json['total_a_pagar'] ?? json['total']) as num).toDouble(),
        unidades: json['unidades'] as int? ?? 0,
        fechaPrometida: leerFecha(json['fecha_prometida']),
        creadoEn: leerFecha(json['creado_en']),
      );
}

class LineaPedido {
  const LineaPedido({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  final int productoId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  factory LineaPedido.fromJson(Map<String, dynamic> json) => LineaPedido(
        productoId: json['producto_id'] as int,
        nombre: json['nombre'] as String,
        cantidad: json['cantidad'] as int,
        precioUnitario: (json['precio_unitario'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
      );
}

/// Un cambio de estado del pedido, con su hora.
class EventoPedido {
  const EventoPedido({required this.estado, required this.fecha});

  final EstadoPedido estado;
  final DateTime? fecha;

  factory EventoPedido.fromJson(Map<String, dynamic> json) => EventoPedido(
        estado: EstadoPedido.desde(json['estado'] as String?),
        fecha: leerFecha(json['fecha']),
      );
}

/// Pedido completo (detalle).
class Pedido {
  const Pedido({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.total,
    required this.costoEnvio,
    required this.totalAPagar,
    required this.fechaPrometida,
    required this.creadoEn,
    required this.direccion,
    required this.lineas,
    required this.eventos,
    required this.qrEntrega,
  });

  final int id;
  final String codigo;
  final EstadoPedido estado;

  /// Solo productos.
  final double total;
  final double costoEnvio;

  /// Productos + envío.
  final double totalAPagar;
  final DateTime? fechaPrometida;
  final DateTime? creadoEn;
  final Direccion direccion;
  final List<LineaPedido> lineas;
  final List<EventoPedido> eventos;

  /// Lo muestra el cliente al transportista (C4). Solo llega mientras el pedido está en curso.
  final String? qrEntrega;

  int get unidades => lineas.fold(0, (s, l) => s + l.cantidad);

  /// Hora en que el pedido llegó a [e], si ya pasó por ahí.
  DateTime? fechaDe(EstadoPedido e) {
    for (final ev in eventos.reversed) {
      if (ev.estado == e) return ev.fecha;
    }
    return null;
  }

  factory Pedido.fromJson(Map<String, dynamic> json) {
    final total = (json['total'] as num).toDouble();
    final envio = (json['costo_envio'] as num? ?? 0).toDouble();
    return Pedido(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      estado: EstadoPedido.desde(json['estado'] as String?),
      total: total,
      costoEnvio: envio,
      totalAPagar: (json['total_a_pagar'] as num? ?? total + envio).toDouble(),
      fechaPrometida: leerFecha(json['fecha_prometida']),
      creadoEn: leerFecha(json['creado_en']),
      direccion: Direccion.fromJson(Map<String, dynamic>.from(json['direccion'] as Map)),
      lineas: [
        for (final l in json['lineas'] as List) LineaPedido.fromJson(Map<String, dynamic>.from(l as Map)),
      ],
      eventos: [
        for (final e in json['eventos'] as List? ?? const []) EventoPedido.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      qrEntrega: json['qr_entrega'] as String?,
    );
  }
}

/// Lo que se muestra antes de confirmar: envío y plazo.
class CondicionesPedido {
  const CondicionesPedido({required this.costoEnvio, required this.plazoDias});

  final double costoEnvio;
  final int plazoDias;

  factory CondicionesPedido.fromJson(Map<String, dynamic> json) => CondicionesPedido(
        costoEnvio: (json['costo_envio'] as num).toDouble(),
        plazoDias: json['plazo_entrega_dias'] as int? ?? 2,
      );
}
