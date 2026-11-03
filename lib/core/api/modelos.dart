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
