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
