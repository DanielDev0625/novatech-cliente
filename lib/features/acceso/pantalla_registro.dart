import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/cliente_api.dart';
import '../../core/sesion/sesion.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/esqueleto.dart';
import 'pantalla_acceso.dart';

/// Revisa los datos como lo hace el servidor, para avisar antes de enviarlos.
/// Devuelve el mensaje del primer problema, o null si todo está bien.
String? validarRegistro({
  required String nombre,
  required String usuario,
  required String password,
  required String confirmacion,
}) {
  if (nombre.trim().length < 2) return 'Escribe tu nombre.';
  final u = usuario.trim();
  if (u.length < 3 || u.length > 50) return 'El usuario debe tener entre 3 y 50 caracteres.';
  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(u)) {
    return 'El usuario solo puede llevar letras, números, punto, guion o guion bajo (sin espacios).';
  }
  if (password.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
  if (password.length > 72) return 'La contraseña es demasiado larga.';
  if (password != confirmacion) return 'Las contraseñas no coinciden.';
  return null;
}

/// «Crear cuenta»: nombre, usuario y contraseña. Al crearla se entra de una vez.
class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  final _nombre = TextEditingController();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _ocultar = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _usuario.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final problema = validarRegistro(
      nombre: _nombre.text,
      usuario: _usuario.text,
      password: _password.text,
      confirmacion: _confirmacion.text,
    );
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(sesionProvider.notifier).registrarse(_nombre.text, _usuario.text, _password.text);
      // Al entrar, el enrutador lleva a la tienda.
    } on ErrorApi catch (e) {
      if (mounted) setState(() => _error = e.codigo == 409 ? 'Ese usuario ya existe. Elige otro.' : e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void alternar() => setState(() => _ocultar = !_ocultar);

    return Scaffold(
      appBar: barraNovaTech(titulo: 'Crear cuenta'),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Con tu cuenta compras y sigues tus pedidos.',
                      style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nombre,
                      enabled: !_cargando,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(hintText: 'Nombre y apellido', prefixIcon: Icon(Icons.badge_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usuario,
                      enabled: !_cargando,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newUsername],
                      decoration: const InputDecoration(
                        hintText: 'Usuario',
                        helperText: 'Sin espacios, p. ej. camila.torres',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CampoContrasena(
                      controlador: _password,
                      habilitado: !_cargando,
                      ocultar: _ocultar,
                      alAlternar: alternar,
                      pista: 'Contraseña (mínimo 8 caracteres)',
                      nueva: true,
                    ),
                    const SizedBox(height: 12),
                    CampoContrasena(
                      controlador: _confirmacion,
                      habilitado: !_cargando,
                      ocultar: _ocultar,
                      alAlternar: alternar,
                      pista: 'Repite la contraseña',
                      nueva: true,
                      alEnviar: _crear,
                    ),
                    if (_error != null) ...[const SizedBox(height: 12), AvisoError(texto: _error!)],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _cargando ? null : _crear,
                      child: _cargando ? const CargandoBoton() : const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
