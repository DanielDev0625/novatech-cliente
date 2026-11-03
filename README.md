# NovaTech Cliente

App del cliente de NovaTech para **Android e iOS**. El cliente **crea su cuenta** (nombre, usuario y
contraseña) y entra con usuario y contraseña, compra componentes de PC y sigue su pedido hasta
la puerta. Sigue `NovaTech_Diseno_de_interfaces.pdf` (versión 1.0), páginas 8 a 11.

| Fase | Estado | Qué trae |
|---|---|---|
| C1 | ✅ | Base (el `core/` de la app del personal) registro e ingreso con usuario y contraseña. |
| C2 | ✅ | Ubicación estilo Rappi (mapa con pin) y catálogo con stock. |
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
| Tienda · Pedidos · Perfil | Navegación inferior. Pedidos es un marcador hasta C3; Perfil muestra nombre, usuario y «Cerrar sesión». |

- La sesión se guarda en el almacén seguro del celular y dura 30 días (`CLIENTE_TOKEN_DIAS` en el
  backend). Al abrir la app se entra directo y el servidor la confirma en segundo plano.
- Una cuenta del personal no puede entrar aquí (y un cliente no puede entrar en la app del personal).

## C2 · Ubicación y catálogo

| Pantalla | Qué hace |
|---|---|
| Tienda | Arriba «Entregar en · Casa · Cra 43 #84-20 ⌄» (toca para cambiarla). Píldoras Todo · Procesadores · Gráficas · RAM…, solo de categorías con productos. Tarjetas con ícono de la categoría, precio y unidades disponibles. Sin dirección, invita a agregarla. |
| Detalle de producto | Ícono grande, nombre, marca y categoría, precio, «N disponibles» y referencia. («Agregar al carrito» llega en C3.) |
| Agregar dirección | Mapa de OpenStreetMap con el pin fijo en el centro: se mueve el mapa y la dirección se completa sola (Nominatim). Botón «mi ubicación» (GPS), «Corregir» para ajustar el texto o agregar el número, Casa · Oficina · Otra e indicaciones opcionales. La nueva queda como principal. |
| Mis direcciones | La principal arriba con su insignia; tocar otra la vuelve principal; ⋮ → «Usar como principal» o «Borrar». Máximo 10. |
| Perfil | Accesos a «Mis direcciones» y a «Permisos: ubicación» (abre los ajustes del celular). |

- La ubicación solo se pide en «Agregar dirección». Sin permiso o sin GPS el mapa arranca en el centro de Barranquilla.
- OpenStreetMap casi nunca trae el número de la casa en Colombia: si falta, la pantalla pide agregarlo con «Corregir».

### Backend (repositorio NOVATECH-BACKEND)

| Ruta | Qué hace |
|---|---|
| `POST /auth/registro-cliente` | Crea la cuenta del cliente (nombre, usuario, contraseña) y entra. |
| `POST /auth/login-cliente` | Ingreso del cliente. Una cuenta del personal no puede entrar por aquí. |
| `GET /catalogo`, `GET/POST /direcciones`, `PATCH /direcciones/{id}/principal` | Ya existían (B3). |
| `DELETE /direcciones/{id}` | **Nuevo en C2.** Borra una dirección que no se haya usado en pedidos; si era la principal, pasa a serlo otra. |

Variable nueva: `CLIENTE_TOKEN_DIAS` (duración de la sesión del cliente, por defecto 30 días).

## Estructura

- `lib/core/`: copiado de la app del personal y adaptado al cliente: API (`api/`), sesión
  (`sesion/`, sin huella ni jornada), tema (encabezado azul), logo y
  componentes (`widgets/`), formato y caché.
- `lib/features/acceso/`: ingreso y registro.
- `lib/features/tienda/`: catálogo, píldoras y detalle.
- `lib/features/direcciones/`: mapa con pin, geocodificador y lista de direcciones.
- `lib/features/inicio/` y `lib/features/perfil/`: pedidos (marcador) y perfil.
