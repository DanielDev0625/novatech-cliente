# NovaTech Cliente

App del cliente de NovaTech para **Android, iOS y web**. El cliente **crea su cuenta** (nombre, usuario y
contraseña) y entra con usuario y contraseña, compra componentes de PC y sigue su pedido hasta
la puerta. Sigue `NovaTech_Diseno_de_interfaces.pdf` (versión 1.0), páginas 8 a 11.

| Fase | Estado | Qué trae |
|---|---|---|
| C1 | ✅ | Base (el `core/` de la app del personal) registro e ingreso con usuario y contraseña. |
| C2 | ✅ | Ubicación estilo Rappi (mapa con pin) y catálogo con stock. |
| C3 | ✅ | Carrito y pedido, con pago contra entrega. |
| C4 | ✅ | Seguimiento con mapa, notificaciones y QR de entrega. |
| Web | ✅ | La misma app en el navegador, con diseño de escritorio. |

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
| Tienda · Pedidos · Perfil | Navegación inferior. Perfil muestra nombre, usuario y «Cerrar sesión». |

- La sesión se guarda en el almacén seguro del celular y dura 30 días (`CLIENTE_TOKEN_DIAS` en el
  backend). Al abrir la app se entra directo y el servidor la confirma en segundo plano.
- Una cuenta del personal no puede entrar aquí (y un cliente no puede entrar en la app del personal).

## C2 · Ubicación y catálogo

| Pantalla | Qué hace |
|---|---|
| Tienda | Arriba «Entregar en · Casa · Cra 43 #84-20 ⌄» (toca para cambiarla). Píldoras Todo · Procesadores · Gráficas · RAM…, solo de categorías con productos. Tarjetas con ícono de la categoría, precio y unidades disponibles. Sin dirección, invita a agregarla. |
| Detalle de producto | Ícono grande, nombre, marca y categoría, precio, «N disponibles» y referencia. |
| Agregar dirección | Mapa de OpenStreetMap con el pin fijo en el centro: se mueve el mapa y la dirección se completa sola (Nominatim). Botón «mi ubicación» (GPS), «Corregir» para ajustar el texto o agregar el número, Casa · Oficina · Otra e indicaciones opcionales. La nueva queda como principal. |
| Mis direcciones | La principal arriba con su insignia; tocar otra la vuelve principal; ⋮ → «Usar como principal» o «Borrar». Máximo 10. |
| Perfil | Accesos a «Mis direcciones» y a «Permisos: ubicación» (abre los ajustes del celular). |

- La ubicación solo se pide en «Agregar dirección». Sin permiso o sin GPS el mapa arranca en el centro de Barranquilla.
- OpenStreetMap casi nunca trae el número de la casa en Colombia: si falta, la pantalla pide agregarlo con «Corregir».

## C3 · Carrito y pedido

**Pago contra entrega:** es la única forma de pago. El cliente no paga nada en la app; paga
productos + envío al recibir. **Envío:** es la tarifa por entrega que configura el administrador en
«Parámetros» ($8.000 por defecto); el transportista sigue ganando su comisión sobre esa tarifa.

| Pantalla | Qué hace |
|---|---|
| Tienda | «Agregar» en cada tarjeta (luego − n +) y la barra naranja «N productos · Ver carrito». |
| Detalle de producto | «Cantidad − 1 +» y «Agregar al carrito · $ …» (o «Actualizar carrito»). |
| Carrito | Productos con − / + (bajar de 1 lo quita), subtotal, envío, total y «Entregar en» (toca para cambiarla). |
| Confirmar pedido | Dirección y fecha máxima de llegada, productos, total con envío, **Pago: contra entrega** y «El stock queda reservado al confirmar». |
| Mis pedidos | «En curso» y «Anteriores», con código, estado, unidades, fecha y total a pagar. |
| Detalle del pedido | Recorrido de estados con su hora, productos, envío, total a pagar, pago y dirección. «Cancelar pedido» mientras siga «Registrado» (el stock vuelve a la tienda). |

- El carrito vive en el celular y nunca pasa de las unidades disponibles; se pone al día cada vez que llega el catálogo.
- Si al confirmar otra persona se llevó las últimas unidades, el servidor responde 409, la app avisa y ajusta el carrito.

## C4 · Seguimiento, QR y notificaciones

| Pantalla | Qué hace |
|---|---|
| Seguimiento | Mapa con tu dirección (pin rojo) y, mientras va en ruta, el transportista (naranja) y la línea entre los dos. «Llega en 12 min · Hora estimada 4:48 p. m.» y el recorrido de estados. Se actualiza cada 15 s. |
| QR de entrega | El código que escanea el transportista para confirmar la entrega, con el monto a pagar contra entrega. Deja de servir al entregar. |
| Notificaciones | Un aviso por cada cambio de estado (alistando, en camino, entregado…). La campana del encabezado cuenta los nuevos. |
| Detalle del pedido | «Seguir en el mapa» y «QR de entrega» mientras el pedido está en curso. En Mis pedidos, los que van en ruta abren directo el mapa («Seguir»). |

- Con la app abierta se revisan los avisos cada 45 s (y al volver a la app). Si el pedido avanzó,
  aparece abajo «Tu pedido va en camino · Ver» y «Mis pedidos» se pone al día.
- No hay notificaciones push con la app cerrada (eso necesitaría Firebase Cloud Messaging).

## Versión web

La misma app corre en el navegador. En pantallas anchas usa menú lateral azul con el logo,
contenido centrado y el acceso con el panel de la marca; en el celular se ve igual que la app.

```
flutter run -d chrome          # probar en el navegador
flutter build web --release    # genera build/web
cd build/web && npx vercel deploy --prod
```

- El proyecto de Vercel es `novatech-cliente` (ya está vinculado en `build/web/.vercel`). No conectar
  el repositorio de Git: Vercel no tiene Flutter para compilar.
- `web/vercel.json` devuelve `index.html` en cualquier ruta (direcciones limpias como `/pedidos/12`).
- El GPS pide permiso al navegador y solo funciona con **https** (o en `localhost`). Hay botón
  «Actualizar» en cada pantalla porque con mouse no se puede jalar hacia abajo.

### Backend (repositorio NOVATECH-BACKEND)

| Ruta | Qué hace |
|---|---|
| `POST /auth/registro-cliente` | Crea la cuenta del cliente (nombre, usuario, contraseña) y entra. |
| `POST /auth/login-cliente` | Ingreso del cliente. Una cuenta del personal no puede entrar por aquí. |
| `GET /catalogo`, `GET/POST /direcciones`, `PATCH /direcciones/{id}/principal` | Ya existían (B3). |
| `GET /pedidos/condiciones` | **Nuevo en C3.** Envío (tarifa por entrega), plazo en días y forma de pago (`contra_entrega`). |
| `POST /pedidos`, `GET /pedidos/mios`, `GET /pedidos/{id}`, `POST /pedidos/{id}/cancelar` | Ya existían; en C3 guardan el envío del pedido (`costo_envio`) y devuelven `total_a_pagar` y `metodo_pago`. La columna `costo_envio` se agrega sola al arrancar. |
| `GET /pedidos/{id}/seguimiento` | Ya existía (B5): posición del transportista y minutos estimados. |
| `GET /notificaciones` | **Nuevo en C4.** Avisos de los últimos 30 días, uno por cada cambio de estado de tus pedidos. |
| `DELETE /direcciones/{id}` | **Nuevo en C2.** Borra una dirección que no se haya usado en pedidos; si era la principal, pasa a serlo otra. |

Variable nueva: `CLIENTE_TOKEN_DIAS` (duración de la sesión del cliente, por defecto 30 días).

## Estructura

- `lib/core/`: copiado de la app del personal y adaptado al cliente: API (`api/`), sesión
  (`sesion/`, sin huella ni jornada), tema (encabezado azul), logo y
  componentes (`widgets/`), formato y caché.
- `lib/features/acceso/`: ingreso y registro.
- `lib/features/tienda/`: catálogo, píldoras y detalle.
- `lib/features/direcciones/`: mapa con pin, geocodificador y lista de direcciones.
- `lib/features/carrito/`: estado del carrito, carrito y confirmación.
- `lib/features/pedidos/`: mis pedidos, detalle, seguimiento con mapa y QR.
- `lib/features/notificaciones/`: avisos, campana y revisión periódica.
- `lib/features/perfil/`: perfil.
