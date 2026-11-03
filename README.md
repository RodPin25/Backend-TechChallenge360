# ShopCart — Backend API

Backend robusto, desacoplado y seguro para la plataforma de comercio electrónico **ShopCart** (Tech Challenge 360 - Grupo Pentandra). Diseñado con arquitectura en capas orientada al dominio, validación estricta de datos, concurrencia pesimista en inventario para evitar sobreventa, checkout atómico e idempotente, y persistencia gobernada **exclusivamente mediante Procedimientos Almacenados en Microsoft SQL Server**.

---

## Tabla de Contenidos
1. [Contexto y Reglas de Negocio](#contexto-y-reglas-de-negocio)
2. [Migraciones de Base de Datos (migrations/)](#migraciones-de-base-de-datos-migrations)
3. [Variables de Entorno (.env y .env.example)](#variables-de-entorno-env-y-envexample)
4. [Arquitectura del Sistema](#arquitectura-del-sistema)
5. [Estructura del Proyecto](#estructura-del-proyecto)
6. [Documentación Interactiva de la API (Swagger / OpenAPI 3.0)](#documentación-interactiva-de-la-api-swagger--openapi-30)
7. [Módulos y Endpoints de la API](#módulos-y-endpoints-de-la-api)
8. [Manejo de Errores y Seguridad](#manejo-de-errores-y-seguridad)
9. [Instalación y Puesta en Marcha](#instalación-y-puesta-en-marcha)


---

## Contexto y Reglas de Negocio

* **Moneda Base:** Quetzales guatemaltecos (`GTQ`).
* **Tratamiento Fiscal:** IVA del 12% incluido en todos los precios del catálogo y desglosado en pedidos (`Monto / 1.12`).
* **Precisión Numérica:** Uso estricto de `DECIMAL(12,2)` para precios, totales y descuentos. Prohibido el uso de flotantes binarios (`FLOAT`/`REAL`).
* **Acceso a Datos:** Exclusivamente vía Stored Procedures fuertemente tipados. El backend no ejecuta consultas dinámicas (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) en el código.
* **Control de Concurrencia y Sobreventa:**
  - Las variantes aplican bloqueo pesimista en base de datos (`UPDLOCK, ROWLOCK`).
  - Las reservas temporales en checkout tienen un TTL estricto de 15 minutos.
  - El stock disponible real se calcula dinámicamente como:  
    $$\text{StockDisponible} = \text{StockFisico} - \sum(\text{ReservasActivasVigentes})$$
* **Checkout Atómico e Idempotente:** Soportado con `IdempotencyKey` para evitar cargos duplicados o consumo repetido de stock.
* **Auditoría e Inmutabilidad:** Tabla `Bitacora` protegida por trigger contra operaciones `UPDATE` y `DELETE`. Toda entidad comercial implementa desactivación lógica (*soft delete*).

---

## Migraciones de Base de Datos (`migrations/`)

Los scripts SQL están diseñados para ejecutarse en **Microsoft SQL Server 2019 o superior**. Para garantizar un orden determinista y evitar scripts monolíticos, el esquema, la lógica y los datos iniciales de base de datos se organizan en 11 archivos secuenciales:

| Orden | Archivo | Responsabilidad / Descripción Resumida |
| :---: | :--- | :--- |
| **01** | `01_Tablas.sql` | **DDL y Esquema Relacional:** Crea la base de datos `ShopCartDB` y sus 21 tablas relacionales, llaves primarias, llaves foráneas, restricciones `CHECK` (precios y existencias no negativas, porcentajes válidos) e índices de cobertura. |
| **02** | `02_funciones.sql` | **Funciones Definidas por el Usuario (UDF):** Implementa `FU_Inventario_StockDisponible` (cálculo en tiempo real de stock físico menos reservas activas) y `FU_Finanzas_DesgloseIVA` (desglose de base imponible e IVA del 12%). |
| **03** | `03_sp_usuarios_direcciones.sql` | **Módulo de Usuarios y Direcciones (RF-01):** Registro de clientes con hash bcrypt, consulta por correo para login, perfil `/me`, administración de usuarios/roles por Admin, y CRUD de direcciones asegurando una única dirección principal por usuario. |
| **04** | `04_sp_catalogo_productos.sql` | **Módulo de Catálogo y Variantes (RF-02):** Categorías jerárquicas, productos y variantes con atributos dinámicos (color, talla, etc.), consulta multi-recordset de detalle de producto, listado paginado con filtros y desactivación lógica con auditoría. |
| **05** | `05_sp_inventario_kardex.sql` | **Módulo de Inventario y Kardex (RF-03, RF-06):** Bloqueo pesimista (`UPDLOCK, ROWLOCK`) para reservas temporales con TTL de 15 minutos, proceso batch de liberación de reservas expiradas, ajustes manuales de almacén y trazabilidad auditable en Kardex (`ENTRADA`, `SALIDA`, `VENTA`, `DEVOLUCION`). |
| **06** | `06_sp_carrito_compras.sql` | **Módulo de Carrito de Compras (RF-04):** Gestión de carritos activos para usuarios autenticados e invitados (`SessionToken`), validación automática de cantidades contra stock disponible en tiempo real, y fusión atómica (*merge*) del carrito de invitado al iniciar sesión. |
| **07** | `07_sp_cupones_promociones.sql` | **Módulo de Cupones y Promociones (RF-05):** Motor de validación de cupones (verificación de vigencia, tope de usos totales, límite de uso por cliente, subtotal mínimo y categoría aplicable) y cálculo de descuentos de tipo `PORCENTAJE` o `MONTO_FIJO`. |
| **08** | `08_sp_checkout_pedidos.sql` | **Módulo de Checkout y Pedidos (RF-06, RF-07):** Procedimiento transaccional de checkout con `IdempotencyKey`, congelación de precios unitarios e IVA al momento de la compra, consumo de cupones y confirmación de reservas. Incluye el ciclo de vida de pedidos y reversión automática de stock ante cancelaciones. |
| **09** | `09_sp_devoluciones.sql` | **Módulo de Devoluciones (RF-07):** Registro de solicitudes de devoluciones totales o parciales por ítem respetando topes comprados, aprobación transaccional con reingreso automático de existencias físicas a `Variantes` y generación del asiento `'DEVOLUCION'` en `Kardex`. |
| **10** | `10_vistas_dashboard_auditoria.sql` | **Vistas Analíticas y Auditoría (RF-08, RF-09):** Trigger de inmutabilidad `TR_Bitacora_InsteadOfUpdateDelete` (prohíbe alteración/borrado de auditoría), vistas analíticas de ventas netas por período, ventas por categoría, top productos, carritos abandonados y procedimientos de reportería ejecutiva. |
| **11** | `11_semillas.sql` | **Semillas y Datos Iniciales:** Carga de datos base (roles, usuarios administrador/operador/clientes con hashes bcrypt, direcciones guatemaltecas, categorías, productos, variantes con stock, asientos iniciales en `Kardex` y cupones de descuento). Idempotente. |

> **Nota de Ejecución:** Los archivos deben ejecutarse en SQL Server en orden estricto de numeración (del `01` al `11`) o de forma automática ejecutando `npm run migrate`.

---

## Variables de Entorno (`.env` y `.env.example`)

La configuración del sistema se centraliza en variables de entorno validadas al inicio de la aplicación mediante **Zod** en `src/config/env.ts`.

Para configurar el entorno local:
```bash
cp .env.example .env
```

A continuación se detalla cada una de las variables requeridas en `.env.example`:

### 1. Configuración General de la Aplicación
| Variable | Tipo / Valores | Valor por Defecto | Descripción |
| :--- | :---: | :---: | :--- |
| `NODE_ENV` | `development` \| `production` \| `test` | `development` | Ambiente de ejecución del backend. En producción optimiza respuestas y omite detalles internos de errores. |
| `API_PORT` | Número entero positivo | `3000` | Puerto TCP en el que el servidor HTTP Express escuchará peticiones entrantes. |

### 2. Base de Datos Microsoft SQL Server (2019+)
| Variable | Tipo / Formato | Ejemplo | Descripción |
| :--- | :---: | :---: | :--- |
| `DB_HOST` | String (Host o IP) | `localhost` | Dirección de red del servidor SQL Server (local, contenedor Docker o IP de servidor). |
| `DB_PORT` | Número entero | `1433` | Puerto del motor de SQL Server. |
| `DB_USER` | String | `sa` | Usuario de base de datos con permisos de ejecución de Stored Procedures y DDL. |
| `DB_PASSWORD` | String | `TuPassword123!` | Contraseña del usuario de base de datos. |
| `DB_NAME` | String | `ShopCartDB` | Nombre de la base de datos creada por la migración `01_Tablas.sql`. |

### 3. Conexión a Redis
| Variable | Tipo / Formato | Valor por Defecto | Descripción |
| :--- | :---: | :---: | :--- |
| `REDIS_HOST` | String (Host o IP) | `localhost` | Host del servidor Redis utilizado para caché y gestión de listas negras de tokens. |
| `REDIS_PORT` | Número entero | `6379` | Puerto de conexión a la instancia de Redis. |
| `REDIS_PASSWORD` | String (Opcional) | `""` | Contraseña de autenticación de Redis (dejar vacío si no requiere contraseña en desarrollo local). |

### 4. Seguridad y Autenticación JWT
| Variable | Tipo / Formato | Valor Recomendado | Descripción |
| :--- | :---: | :---: | :--- |
| `JWT_SECRET` | String (Mín. 16 caracteres) | `CLAVE_SECRETA_ACCESS_TOKEN_SEGURA` | Clave criptográfica para firmar los Access Tokens de corta duración. |
| `JWT_EXPIRES_IN` | String (formato tiempo) | `15m` | Tiempo de validez del Access Token (ej. `15m` para 15 minutos). |
| `JWT_REFRESH_SECRET`| String (Mín. 16 caracteres) | `CLAVE_SECRETA_REFRESH_TOKEN_SEGURA`| Clave secreta independiente para firmar y validar Refresh Tokens. |
| `JWT_REFRESH_EXPIRES_IN`| String (formato tiempo) | `7d` | Tiempo de expiración del Refresh Token (ej. `7d` para 7 días). |

### 5. Constantes de Negocio
| Variable | Tipo / Formato | Valor por Defecto | Descripción |
| :--- | :---: | :---: | :--- |
| `IVA_RATE` | Decimal | `0.12` | Tasa de Impuesto al Valor Agregado del 12% aplicable en Guatemala (GTQ). |
| `RESERVATION_TTL_MINUTES` | Número entero positivo | `15` | Tiempo límite en minutos antes de que una reserva de inventario en checkout expire y deba liberarse. |

---

## Arquitectura del Sistema

El backend implementa una arquitectura en capas desacoplada con flujo unidireccional:

```
[ Petición HTTP ]
       ↓
[ Middlewares ] ──── (Helmet, CORS, JWT Auth, RBAC, Validación Zod)
       ↓
[ Controllers ] ──── (Manejo de Request/Response y códigos de estado HTTP)
       ↓
[ Services ] ─────── (Reglas de negocio puras, cálculos y orquestación)
       ↓
[ Repositories ] ─── (Única capa que interactúa con la DB mediante pool mssql)
       ↓
[ SQL Server SPs ] ─ (Stored Procedures transaccionales y fuertemente tipados)
```

### Principios Fundamentales:
* **Separación de Responsabilidades:** Los controladores no contienen lógica de base de datos ni validación de esquemas; los repositorios son los únicos autorizados a llamar a `mssql.Request().execute()`.
* **Seguridad y Validación Temprana:** Todo payload, parámetro de URL o query string es verificado por Zod antes de alcanzar la capa de controladores.
* **Control de Transacciones en DB:** Las operaciones de inventario, checkout y devoluciones delegan su atomicidad a bloques `BEGIN TRANSACTION ... COMMIT` en T-SQL con aislamiento `READ COMMITTED` y bloqueos `UPDLOCK, ROWLOCK`.

---

## Estructura del Proyecto

```text
ShopCart-Backend/
├── migrations/                     # Scripts SQL ordenados determinísticamente (00 a 11)
│   ├── 00_run_all.sql              # Script maestro SQLCMD para ejecución completa
│   ├── 01_Tablas.sql               # Esquema de 21 tablas relacionales, constraints e índices
│   ├── 02_funciones.sql            # UDFs de stock disponible y desglose de IVA
│   ├── 03_sp_usuarios_direcciones.sql
│   ├── 04_sp_catalogo_productos.sql
│   ├── 05_sp_inventario_kardex.sql
│   ├── 06_sp_carrito_compras.sql
│   ├── 07_sp_cupones_promociones.sql
│   ├── 08_sp_checkout_pedidos.sql
│   ├── 09_sp_devoluciones.sql
│   ├── 10_vistas_dashboard_auditoria.sql
│   └── 11_semillas.sql             # Semillas iniciales (roles, usuarios, catálogo, kardex, cupones)
├── src/
│   ├── app.ts                      # Configuración de Express, middlewares, Swagger y montaje de rutas
│   ├── server.ts                   # Punto de entrada HTTP y arranque del pool DB/Redis (con fallback)
│   ├── scripts/
│   │   └── runMigrations.ts        # Runner automatizado de migraciones secuenciales en TypeScript
│   ├── config/                     # Clientes de infraestructura, variables de entorno y OpenAPI
│   │   ├── db.ts                   # Conexión y pool global de Microsoft SQL Server
│   │   ├── env.ts                  # Validación de variables con Zod
│   │   ├── redis.ts                # Conexión a Redis para caché y tokens (tolerante a fallos)
│   │   └── swagger.ts              # Especificación OpenAPI 3.0.3 e interfaz Swagger UI
│   ├── controllers/                # Controladores HTTP por módulo de negocio
│   │   ├── auth.controller.ts
│   │   ├── catalog.controller.ts
│   │   ├── cart.controller.ts
│   │   ├── coupons.controller.ts
│   │   ├── inventory.controller.ts
│   │   ├── orders.controller.ts
│   │   └── reports.controller.ts
│   ├── core/                       # Núcleo compartido de la aplicación
│   │   ├── constants/              # Roles, estados de pedido, tipos de Kardex, errores
│   │   ├── errors/                 # Jerarquía AppError y traducción de errores SQL (500XX)
│   │   ├── schemas/                # Contratos y DTOs de validación con Zod (auth, catalog, cart, coupons, inventory, orders, reports)
│   │   └── types/                  # Interfaces y definiciones TypeScript de dominio
│   ├── middlewares/                # Interceptores y filtros de seguridad
│   │   ├── auth.middleware.ts      # Verificación y extracción de JWT
│   │   ├── errorHandler.ts         # Middleware global de captura de errores y 404
│   │   ├── role.middleware.ts      # Control de acceso basado en roles (RBAC)
│   │   └── validate.middleware.ts  # Validación genérica de schemas Zod (body, params, query)
│   ├── repositories/               # Acceso a datos exclusivo mediante Stored Procedures
│   │   ├── auth.repository.ts
│   │   ├── catalog.repository.ts
│   │   ├── cart.repository.ts
│   │   ├── coupons.repository.ts
│   │   ├── inventory.repository.ts
│   │   ├── orders.repository.ts
│   │   └── reports.repository.ts
│   ├── routes/                     # Definición de rutas modularizadas
│   │   ├── auth.routes.ts          # /api/auth, /api/users, /api/addresses
│   │   ├── catalog.routes.ts       # /api/catalog
│   │   ├── cart.routes.ts          # /api/cart
│   │   ├── coupons.routes.ts       # /api/coupons
│   │   ├── inventory.routes.ts     # /api/inventory
│   │   ├── orders.routes.ts        # /api/orders, /api/returns
│   │   └── reports.routes.ts       # /api/reports, /api/audit
│   └── services/                   # Lógica de negocio y orquestación
│       ├── auth.service.ts
│       ├── catalog.service.ts
│       ├── cart.service.ts
│       ├── coupons.service.ts
│       ├── inventory.service.ts
│       ├── orders.service.ts
│       └── reports.service.ts
├── .env.example                    # Plantilla de variables de entorno requeridas
├── package.json                    # Dependencias y scripts de ejecución
├── tsconfig.json                   # Configuración del compilador TypeScript en modo estricto
└── README.md                       # Documentación técnica general
```

---

## Documentación Interactiva de la API (Swagger / OpenAPI 3.0)

El backend incluye documentación interactiva **OpenAPI 3.0.3 (Swagger UI)** integrada directamente en el servidor, sin necesidad de herramientas externas.

Una vez iniciado el servidor (por defecto en el puerto `3000`), la documentación está disponible en:

* **Interfaz Interactiva (Swagger UI):**  
  👉 **`http://localhost:3000/api/docs`**
* **Especificación OpenAPI 3.0 en formato JSON:**  
  👉 **`http://localhost:3000/api/docs.json`**

### ¿Cómo probar endpoints protegidos desde Swagger UI?
1. Abre `http://localhost:3000/api/docs` en tu navegador.
2. Dirígete a la sección **Auth** $\rightarrow$ `POST /auth/login` (o `POST /auth/register`), presiona **Try it out** y ejecuta la petición con tus credenciales.
3. Copia el valor de `accessToken` devuelto en la respuesta JSON.
4. Haz clic en el botón **Authorize** (ubicado en la esquina superior derecha de Swagger UI), pega el token en el campo `bearerAuth` y presiona **Authorize**.
5. La sesión queda persistida en el navegador (`persistAuthorization: true`) y podrás probar cualquier endpoint protegido según el rol del usuario (`Cliente`, `Operador` o `Administrador`).

---

## Módulos y Endpoints de la API

### 1. Verificación de Salud y Documentación
* `GET /api/health` — Comprobación del estado operativo de la API (*Público*).
* `GET /api/docs` — Interfaz gráfica interactiva Swagger UI (*Público*).
* `GET /api/docs.json` — Especificación OpenAPI 3.0.3 en JSON (*Público*).

### 2. Autenticación y Perfil (`/api/auth`)
* `POST /api/auth/register` — Registro de clientes (`nombreCompleto`, `correo`, `password`, `telefono`) (*Público*).
* `POST /api/auth/login` — Autenticación con credenciales, emite Access Token y Refresh Token (*Público*).
* `POST /api/auth/refresh` — Renovación y rotación de Access Token mediante Refresh Token (*Público*).
* `POST /api/auth/logout` — Cierre de sesión y revocación de Refresh Token (*Público / Autenticado*).
* `GET /api/auth/me` — Consulta del perfil y dirección principal del usuario en sesión (*Cliente, Operador, Admin*).
* `PUT /api/auth/me` — Actualización de datos del perfil y contraseña (*Cliente, Operador, Admin*).

### 3. Administración de Usuarios y Roles (`/api/users`)
* `GET /api/users/roles` — Listado de roles disponibles en el sistema (*Admin*).
* `GET /api/users` — Listado paginado de usuarios con filtros por rol, estado y búsqueda (*Admin*).
* `POST /api/users` — Creación de usuarios con rol asignado por un Administrador (*Admin*).
* `PATCH /api/users/:idUsuario/status` — Activación/desactivación lógica de usuarios o cambio de rol (*Admin*).

### 4. Direcciones de Entrega (`/api/addresses`)
* `GET /api/addresses` — Listado de direcciones activas del usuario en sesión (*Cliente, Operador, Admin*).
* `POST /api/addresses` — Registro de nueva dirección de entrega (*Cliente, Operador, Admin*).
* `PUT /api/addresses/:idDireccion` — Edición de datos de una dirección propia protegida contra IDOR (*Cliente, Operador, Admin*).
* `PATCH /api/addresses/:idDireccion/principal` — Establece dirección como principal única (*Cliente, Operador, Admin*).
* `DELETE /api/addresses/:idDireccion` — Desactivación lógica de dirección propia (*Cliente, Operador, Admin*).

### 5. Catálogo de Productos y Variantes (`/api/catalog`)
* `GET /api/catalog/categories` — Listado de categorías con caché Redis (*Público*).
* `POST /api/catalog/categories` — Creación de categorías (*Admin*).
* `PUT /api/catalog/categories/:idCategoria` — Actualización de categorías (*Admin*).
* `GET /api/catalog/products` — Listado de productos con paginación server-side, filtro por categoría, búsqueda, disponibilidad y rango de precio (*Público*).
* `GET /api/catalog/products/:idProducto` — Consulta multi-recordset de producto con sus variantes, stock disponible real y atributos (*Público*).
* `POST /api/catalog/products` — Creación de nuevo producto (*Admin*).
* `PUT /api/catalog/products/:idProducto` — Actualización de información de producto (*Admin*).
* `PATCH /api/catalog/products/:idProducto/status` — Desactivación lógica de producto sin borrado físico (*Admin*).
* `POST /api/catalog/products/:idProducto/variants` — Creación de variante con SKU único, precio y stock inicial asentado en Kardex (*Admin*).
* `PUT /api/catalog/variants/:idVariante` — Actualización de variante y registro automático de variación de precio en `HistorialPrecios` (*Admin*).
* `POST /api/catalog/variants/:idVariante/attributes` — Asignación o edición de atributo dinámico (ej. Talla, Color) a variante (*Admin*).
* `DELETE /api/catalog/variants/:idVariante/attributes/:idVarianteAtributo` — Remoción de atributo (*Admin*).
* `GET /api/catalog/price-history` — Consulta de auditoría de historial de variaciones de precios (*Admin*).

### 6. Carrito de Compras (`/api/cart`)
* `GET /api/cart` — Consulta del carrito activo, desglose de IVA (12%) y totales para usuario autenticado o invitado vía header `x-guest-token` / query `tokenInvitado` (*Público / Autenticado*).
* `POST /api/cart/items` — Agrega o incrementa un ítem validando existencias disponibles en tiempo real (*Público / Autenticado*).
* `PUT /api/cart/items/:idVariante` — Fija la cantidad exacta de un ítem en el carrito (*Público / Autenticado*).
* `DELETE /api/cart/items/:idVariante` — Remueve un ítem específico del carrito (*Público / Autenticado*).
* `DELETE /api/cart` — Vacía por completo el carrito activo (*Público / Autenticado*).
* `POST /api/cart/merge` — Fusiona el carrito de invitado con el carrito del usuario autenticado respetando el stock disponible (*Autenticado*).

### 7. Inventario y Kardex (`/api/inventory`)
* `GET /api/inventory/stock` — Consulta paginada de existencias físicas, reservadas, disponibles y conciliación contra Kardex (*Operador, Admin*).
* `GET /api/inventory/kardex` — Consulta cronológica paginada de movimientos de almacén (*Operador, Admin*).
* `POST /api/inventory/adjustments` — Registro de ajustes manuales (`AJUSTE_ENTRADA` / `AJUSTE_SALIDA`) con motivo obligatorio y asiento en Kardex (*Operador, Admin*).
* `POST /api/inventory/reservations/release-expired` — Ejecución de barrido de liberación de reservas con TTL vencido (*Operador, Admin*).
* `POST /api/inventory/reservations` — Reserva temporal (15 min) de una variante con bloqueo pesimista (*Público / Autenticado*).
* `POST /api/inventory/reservations/cart` — Reserva atómica en lote (15 min) de todos los ítems de un carrito al iniciar checkout (*Público / Autenticado*).
* `POST /api/inventory/reservations/release` — Liberación manual anticipada de reservas activas (*Público / Autenticado*).

### 8. Cupones y Promociones (`/api/coupons`)
* `POST /api/coupons/validate` — Valida vigencia, límites de uso, monto mínimo y categoría de un cupón frente al carrito activo y devuelve el descuento calculado (*Público / Autenticado*).
* `GET /api/coupons` — Listado paginado de cupones con filtros (*Admin*).
* `GET /api/coupons/:idCupon` — Detalle de cupón e historial de usos por cliente/pedido (*Admin*).
* `POST /api/coupons` — Creación de cupón (`PORCENTAJE` o `MONTO_FIJO`) (*Admin*).
* `PUT /api/coupons/:idCupon` — Actualización de reglas y límites de un cupón (*Admin*).
* `PATCH /api/coupons/:idCupon/status` — Activación o desactivación lógica de cupón (*Admin*).

### 9. Checkout y Gestión de Pedidos (`/api/orders`)
* `POST /api/orders/checkout` — **Checkout atómico e idempotente** (`Idempotency-Key` en header o `idempotencyKey` en body): congela precios unitarios, valida y consume cupón, descuenta stock con bloqueo pesimista, genera movimientos `VENTA` en Kardex, confirma reservas y crea el pedido (*Autenticado*).
* `GET /api/orders` — Listado paginado de pedidos con filtros por estado, cliente y fechas (aislado automáticamente por rol) (*Cliente, Operador, Admin*).
* `GET /api/orders/:idPedido` — Detalle completo del pedido (encabezado, líneas con precios congelados, pagos e historial cronológico de estados) (*Cliente, Operador, Admin*).
* `PATCH /api/orders/:idPedido/status` — Transición de estado del pedido (`PENDIENTE` $\rightarrow$ `PAGADO` $\rightarrow$ `EN_PREPARACION` $\rightarrow$ `ENVIADO` $\rightarrow$ `ENTREGADO` / `CANCELADO`) con reintegro automático al Kardex en caso de cancelación (*Cliente para cancelar antes de envío, Operador, Admin*).

### 10. Devoluciones y Reintegros (`/api/returns`)
* `GET /api/returns` — Listado paginado de solicitudes de devolución (*Cliente, Operador, Admin*).
* `GET /api/returns/:idDevolucion` — Detalle de devolución y monto neto de reintegro (*Cliente, Operador, Admin*).
* `POST /api/returns` — Solicitud de devolución total o parcial por línea de pedido en estado `ENTREGADO`, validando no superar la cantidad vendida (*Cliente, Operador, Admin*).
* `PATCH /api/returns/:idDevolucion/resolve` — Aprobación (`APROBADA`) o rechazo (`RECHAZADA`) de devolución; al aprobar, reintegra atómicamente el stock a `Variantes` y registra el movimiento `'DEVOLUCION'` en `Kardex` (*Operador, Admin*).

### 11. Dashboard Ejecutivo, Reportes y Bitácora (`/api/reports` y `/api/audit`)
* `GET /api/reports/kpis` — Tarjetas de KPIs ejecutivos (venta neta descontando devoluciones, pedidos completados, ticket promedio y carritos abandonados) (*Admin*).
* `GET /api/reports/sales-by-period` — Serie de ventas netas en GTQ y número de pedidos agrupados por `DIA`, `SEMANA` o `MES` (*Admin*).
* `GET /api/reports/sales-by-category` — Ventas netas por categoría y porcentaje de participación (*Admin*).
* `GET /api/reports/top-products` — Top 10 productos más vendidos del período (*Admin*).
* `GET /api/reports/abandoned-carts` — Listado paginado de carritos abandonados según umbral de minutos de inactividad (*Admin*).
* `GET /api/audit` — Consulta paginada y filtrada por módulo, acción, usuario y fechas de la `Bitacora` inmutable (*Admin*).

---

## Manejo de Errores y Seguridad

### 1. Traducción Automática de Errores T-SQL (`mapSqlError`)
La aplicación captura excepciones lanzadas por SQL Server mediante `;THROW 500XX, 'Mensaje', 1;` y las traduce a instancias normalizadas de `AppError`:
* **50000 - 50999:** Errores de regla de negocio personalizados (Stock insuficiente, cupón inválido o expirado, transición ilegal de estados de pedidos). Se convierten en respuestas HTTP `400 Bad Request`, `403 Forbidden`, `404 Not Found` o `409 Conflict`.
* **2601 / 2627:** Violación de unicidad `UNIQUE` (correos, códigos de cupones o SKUs duplicados) mapeados a `409 Conflict`.
* **547:** Violación de integridad referencial o restricciones `CHECK` mapeadas a `400 Bad Request`.

### 2. Estructura de Respuesta de Error
Todas las respuestas de error siguen un estándar unificado:
```json
{
  "success": false,
  "error": {
    "code": "ERR_STOCK_INSUFICIENTE",
    "message": "Existencias insuficientes para la variante solicitada."
  }
}
```

### 3. Medidas de Seguridad
* **Helmet:** Configuración de cabeceras HTTP seguras para mitigar XSS, clickjacking y MIME-sniffing.
* **CORS:** Control estricto de orígenes autorizados para consumo web.
* **Protección contra Inyecciones SQL:** Imposibilidad técnica de SQL Injection gracias a la prohibición total de consultas en cadena y uso exclusivo de parámetros fuertemente tipados en llamadas a Stored Procedures.
* **Bcrypt:** Algoritmo robusto con salt rounds para el almacenamiento seguro de contraseñas.
* **Inmutabilidad de Auditoría:** Disparador en base de datos que bloquea cualquier intento de manipulación o borrado en `dbo.Bitacora`.

---

## Instalación y Puesta en Marcha

### Prerrequisitos
* **Node.js:** Versión 20 LTS o 24 LTS recomendada.
* **Microsoft SQL Server:** 2019 o superior con autenticación SQL habilitada.
* **Redis:** 6.x o superior *(Opcional en desarrollo local: si Redis no está activo, el backend aplica degradación elegante y continúa operando directamente contra SQL Server)*.
* **Gestor de Paquetes:** `npm`.

### Paso 1: Clonar el repositorio e instalar dependencias
```bash
git clone <URL_DEL_REPOSITORIO>
cd ShopCart-Backend
npm install
```

### Paso 2: Configurar las variables de entorno
Crea tu archivo `.env` a partir de la plantilla y edita las credenciales correspondientes a tu entorno (asegúrate de colocar valores reales en `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET` y `JWT_REFRESH_SECRET`):
```bash
cp .env.example .env
```

### Paso 3: Ejecutar las migraciones y semillas en SQL Server

Tienes a tu disposición tres métodos para ejecutar el esquema completo y los datos iniciales:

#### Opción A: Runner automatizado en Node.js (Recomendado)
Ejecuta el script integrado que se conecta a SQL Server usando las credenciales de tu `.env`, verifica la base de datos `ShopCartDB` y procesa secuencialmente todos los lotes `GO`:
```bash
npm run migrate
```

#### Opción B: Script maestro con SQLCMD / SSMS
Si prefieres ejecutar directamente en el motor de base de datos usando la herramienta de línea de comandos `sqlcmd`:
```bash
sqlcmd -S localhost -U sa -P TuPassword -i migrations/00_run_all.sql
```
*(En SQL Server Management Studio, abre `migrations/00_run_all.sql` y habilita el menú **Query > SQLCMD Mode** antes de ejecutar).*

#### Opción C: Ejecución manual secuencial
Abre tu cliente SQL preferido (SSMS o Azure Data Studio) y corre los scripts en este orden exacto:
1. `01_Tablas.sql`
2. `02_funciones.sql`
3. `03_sp_usuarios_direcciones.sql`
4. `04_sp_catalogo_productos.sql`
5. `05_sp_inventario_kardex.sql`
6. `06_sp_carrito_compras.sql`
7. `07_sp_cupones_promociones.sql`
8. `08_sp_checkout_pedidos.sql`
9. `09_sp_devoluciones.sql`
10. `10_vistas_dashboard_auditoria.sql`
11. `11_semillas.sql`

---

### Paso 4: Ejecutar el Backend después de las Migraciones

Una vez que la base de datos `ShopCartDB` tiene todas las tablas, funciones, vistas, procedimientos almacenados y semillas cargadas:

#### 1. Ejecutar en Modo Desarrollo (con recarga automática `tsx watch`):
Ideal para desarrollo y pruebas locales:
```bash
npm run dev
```

#### 2. Compilar y Ejecutar en Modo Producción:
Compila el código TypeScript en modo estricto (`strict: true`) hacia la carpeta `dist/` y levanta el servidor con Node.js:
```bash
npm run build
npm start
```

#### 3. Verificar que el Servidor está Corriendo:
Al arrancar verás en consola la confirmación de conexión a SQL Server (y Redis si está disponible):
```text
[SQL] Conectado a la base de datos SQL Server
[SERVER] Servidor escuchando en http://localhost:3000 (development)
```

Puedes comprobar el estado del servidor y explorar la documentación interactiva en:
* **Health Check:**  
  ```bash
  curl http://localhost:3000/api/health
  ```
* **Documentación Swagger UI (Navegador):**  
  Abre **`http://localhost:3000/api/docs`** para visualizar y probar interactivamente todos los endpoints de la API.
* **Especificación OpenAPI JSON:**  
  Disponible en **`http://localhost:3000/api/docs.json`**.

  ---
  # AI FREE ZONE
  Ésta esta una pequeña nota para el evaluador. Este proyecto tuvo presencia de agentes de inteligencia aritificial que me ayudaron a escribir código y redactar la documentación.
  Los agentes utilizados fueron:
  1. `db-engineer` para los scripts de bases de datos.
  2. `ts-engineer` para todo lo relacionado a la escritura de TypeScript

  Con esto dicho es importante resaltar que **la arquitectura del proyecto y el diseño de bases de datos fueron diseñados por mi persona**, también fui el encargado de ir guiando y corrigiendo a los agentes. Con esto dicho espero que mi proyecto cumpla con las críterios de evaluación sufucientes para poder
  continuar en la siguiente fase :)

