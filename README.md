# NovaTech Cliente

App del cliente de NovaTech para **Android e iOS**. El cliente **crea su cuenta** (nombre, usuario y
contraseña) y entra con usuario y contraseña, compra componentes de PC y sigue su pedido hasta
la puerta. Sigue `NovaTech_Diseno_de_interfaces.pdf` (versión 1.0), páginas 8 a 11.

| Fase | Estado | Qué trae |
|---|---|---|
| C1 | ✅ | Base (el `core/` de la app del personal) registro e ingreso con usuario y contraseña. |
| C2 | — | Ubicación estilo Rappi y catálogo con stock. |
| C3 | — | Carrito y pedido. |
| C4 | — | Seguimiento con mapa, notificaciones y QR de entrega. |

## Correr la app

```
flutter pub get
flutter test
flutter run
```

Por defecto usa el backend publicado (`https://novatech-backend.vercel.app`). Para probar contra tu
computador desde el emulador Android, agrega `--dart-define=API_URL=http://10.0.2.2:8000`.

## C1 · Acceso

| Pantalla | Qué hace |
|---|---|
| Acceso | Logo, usuario y contraseña, **Iniciar sesión** y **Crear cuenta**. |
| Crear cuenta | Nombre, usuario (sin espacios) y contraseña dos veces (mínimo 8). Se revisa antes de enviar y al crearla se entra de una vez. |
| Tienda · Pedidos · Perfil | Navegación inferior. Tienda y Pedidos son marcadores hasta C2 y C3; Perfil muestra nombre, usuario y «Cerrar sesión». |

- La sesión se guarda en el almacén seguro del celular y dura 30 días (`CLIENTE_TOKEN_DIAS` en el
  backend). Al abrir la app se entra directo y el servidor la confirma en segundo plano.
- Una cuenta del personal no puede entrar aquí (y un cliente no puede entrar en la app del personal).

### Backend (repositorio NOVATECH-BACKEND)

| Ruta | Qué hace |
|---|---|
| `POST /auth/registro-cliente` | Crea la cuenta del cliente (nombre, usuario, contraseña) y entra. |
| `POST /auth/login-cliente` | Ingreso del cliente. Una cuenta del personal no puede entrar por aquí. |

Variable nueva: `CLIENTE_TOKEN_DIAS` (duración de la sesión del cliente, por defecto 30 días).

## Estructura

- `lib/core/`: copiado de la app del personal y adaptado al cliente: API (`api/`), sesión
  (`sesion/`, sin huella ni jornada), tema (encabezado azul), logo y
  componentes (`widgets/`), formato y caché.
- `lib/features/acceso/`: ingreso y registro.
- `lib/features/inicio/` y `lib/features/perfil/`: pestañas.
