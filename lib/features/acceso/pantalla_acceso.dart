import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/cliente_api.dart';
import '../../core/sesion/sesion.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/componentes.dart';
import '../../core/widgets/marca.dart';

/// Primera pantalla del cliente: entrar con usuario y contraseña, o crear la cuenta.
class PantallaAcceso extends ConsumerStatefulWidget {
  const PantallaAcceso({super.key});

  @override
  ConsumerState<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends ConsumerState<PantallaAcceso> {
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _ocultar = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final usuario = _usuario.text.trim();
    final password = _password.text;
    if (usuario.isEmpty || password.isEmpty) {
      setState(() => _error = 'Escribe tu usuario y tu contraseña.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(sesionProvider.notifier).iniciarSesion(usuario, password);
      // Si entró, el enrutador cambia de pantalla solo.
    } on ErrorApi catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mensaje = _error ?? ref.watch(sesionProvider.select((s) => s.aviso));

    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: MediaQuery.paddingOf(context).top),
          const FranjaColores(ancho: double.infinity, alto: 5),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: LogoNovaTech.vertical(alto: 120)),
                        const SizedBox(height: 8),
                        const Text(
                          'Componentes de PC a tu puerta',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ColoresNovaTech.textoSuave, fontSize: 15),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _usuario,
                          enabled: !_cargando,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(hintText: 'Usuario', prefixIcon: Icon(Icons.person_outline)),
                        ),
                        const SizedBox(height: 12),
                        CampoContrasena(
                          controlador: _password,
                          habilitado: !_cargando,
                          ocultar: _ocultar,
                          alAlternar: () => setState(() => _ocultar = !_ocultar),
                          alEnviar: _entrar,
                        ),
                        if (mensaje != null) ...[const SizedBox(height: 12), AvisoError(texto: mensaje)],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _cargando ? null : _entrar,
                          child: _cargando ? const CargandoBoton() : const Text('Iniciar sesión'),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '¿Es tu primera compra?',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ColoresNovaTech.textoSuave),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _cargando ? null : () => context.push('/acceso/registro'),
                          child: const Text('Crear cuenta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                'Al continuar aceptas los términos y la política de privacidad',
                textAlign: TextAlign.center,
                style: TextStyle(color: ColoresNovaTech.textoSuave.withValues(alpha: 0.85), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de contraseña con el botón de mostrar u ocultar.
class CampoContrasena extends StatelessWidget {
  const CampoContrasena({
    super.key,
    required this.controlador,
    required this.ocultar,
    required this.alAlternar,
    this.habilitado = true,
    this.alEnviar,
    this.pista = 'Contraseña',
    this.nueva = false,
  });

  final TextEditingController controlador;
  final bool ocultar;
  final VoidCallback alAlternar;
  final bool habilitado;
  final VoidCallback? alEnviar;
  final String pista;

  /// true en el registro (el celular puede sugerir una contraseña segura).
  final bool nueva;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      enabled: habilitado,
      obscureText: ocultar,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: alEnviar != null ? TextInputAction.done : TextInputAction.next,
      autofillHints: [nueva ? AutofillHints.newPassword : AutofillHints.password],
      onSubmitted: alEnviar == null ? null : (_) => alEnviar!(),
      decoration: InputDecoration(
        hintText: pista,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: alAlternar,
        ),
      ),
    );
  }
}

/// Ruedita blanca dentro de un botón mientras carga.
class CargandoBoton extends StatelessWidget {
  const CargandoBoton({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
}
