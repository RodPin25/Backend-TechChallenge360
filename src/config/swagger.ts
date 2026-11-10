// src/config/swagger.ts
import { Router, type Request, type Response } from 'express';

export const openApiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'ShopCart API — Tech Challenge 360',
    version: '1.0.0',
    description:
      'API RESTful de comercio electrónico en Quetzales (GTQ) con IVA del 12% incluido, acceso exclusivo mediante Stored Procedures en Microsoft SQL Server 2019+, concurrencia con bloqueos pesimistas, reservas temporales (TTL 15 min), checkout atómico e idempotente, Kardex y Bitácora inmutable.',
  },
  servers: [
    {
      url: '/api',
      description: 'Servidor local (/api)',
    },
  ],
  tags: [
    { name: 'Health', description: 'Estado de salud del servicio' },
    { name: 'Auth', description: 'RF-01: Registro, Login, Refresh Token y Perfil (/me)' },
    { name: 'Users', description: 'RF-01: Administración de Usuarios y Roles (Solo Admin)' },
    { name: 'Addresses', description: 'RF-01: Direcciones de Entrega del Cliente' },
    { name: 'Catalog', description: 'RF-02: Categorías, Productos, Variantes, Atributos e Historial de Precios' },
    { name: 'Inventory', description: 'RF-03, RF-06: Existencias, Kardex, Ajustes y Reservas Temporales' },
    { name: 'Cart', description: 'RF-04: Carrito de Compras (Usuarios e Invitados) y Fusión de Sesión' },
    { name: 'Coupons', description: 'RF-05: Cupones de Descuento y Validación en Carrito' },
    { name: 'Orders', description: 'RF-06, RF-07: Checkout Atómico e Idempotente y Ciclo de Vida de Pedidos' },
    { name: 'Returns', description: 'RF-07, RF-03: Solicitud y Resolución de Devoluciones con Reintegro a Kardex' },
    { name: 'Reports', description: 'RF-08: Dashboard Ejecutivo, Ventas, Top Productos y Carritos Abandonados' },
    { name: 'Audit', description: 'RF-09: Consulta de Bitácora Inmutable (Solo Admin)' },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'Ingrese el accessToken JWT obtenido en /api/auth/login o /api/auth/register',
      },
    },
    parameters: {
      GuestTokenHeader: {
        in: 'header',
        name: 'x-guest-token',
        required: false,
        schema: { type: 'string' },
        description: 'Token de sesión para carrito o reservas de visitante invitado sin cuenta',
      },
      IdempotencyKeyHeader: {
        in: 'header',
        name: 'Idempotency-Key',
        required: false,
        schema: { type: 'string', example: 'chk-20261102-unique-001' },
        description: 'Llave única de idempotencia (8 a 64 caracteres) para evitar cobros o pedidos duplicados',
      },
    },
    schemas: {
      ErrorResponse: {
        type: 'object',
        properties: {
          success: { type: 'boolean', example: false },
          error: {
            type: 'object',
            properties: {
              code: { type: 'string', example: 'ERR_VALIDACION' },
              message: { type: 'string', example: 'Descripción legible del error.' },
            },
          },
        },
      },
    },
  },
  paths: {
    // ========================================================================
    // HEALTH
    // ========================================================================
    '/health': {
      get: {
        tags: ['Health'],
        summary: 'Verificar estado del servidor',
        responses: {
          '200': { description: 'API activa y respondiendo correctamente' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 1: AUTH (/api/auth)
    // ========================================================================
    '/auth/register': {
      post: {
        tags: ['Auth'],
        summary: 'Registrar nuevo cliente (SP_Usuarios_RegistrarCliente)',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['correo', 'password', 'nombreCompleto'],
                properties: {
                  correo: { type: 'string', format: 'email', example: 'cliente@ejemplo.com' },
                  password: { type: 'string', minLength: 8, example: 'Password123!' },
                  nombreCompleto: { type: 'string', example: 'Juan Pérez' },
                  telefono: { type: 'string', example: '5555-1234' },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Cliente registrado y tokens emitidos' },
          '400': { description: 'Datos inválidos' },
          '409': { description: 'El correo ya está registrado' },
        },
      },
    },
    '/auth/login': {
      post: {
        tags: ['Auth'],
        summary: 'Iniciar sesión (SP_Usuarios_ObtenerPorCorreo)',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['correo', 'password'],
                properties: {
                  correo: { type: 'string', format: 'email', example: 'admin@shopcart.gt' },
                  password: { type: 'string', example: 'Admin123!' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Autenticación exitosa (devuelve accessToken y refreshToken)' },
          '401': { description: 'Credenciales inválidas' },
          '403': { description: 'Usuario desactivado' },
        },
      },
    },
    '/auth/refresh': {
      post: {
        tags: ['Auth'],
        summary: 'Rotar Refresh Token y obtener nuevo Access Token',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['refreshToken'],
                properties: {
                  refreshToken: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Par de tokens renovado exitosamente' },
          '401': { description: 'Refresh token expirado o revocado' },
        },
      },
    },
    '/auth/logout': {
      post: {
        tags: ['Auth'],
        summary: 'Cerrar sesión y revocar Refresh Token',
        requestBody: {
          required: false,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  refreshToken: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Sesión cerrada exitosamente' },
        },
      },
    },
    '/auth/me': {
      get: {
        tags: ['Auth'],
        summary: 'Obtener perfil del usuario autenticado (SP_Usuarios_ObtenerPerfilPorID)',
        security: [{ bearerAuth: [] }],
        responses: {
          '200': { description: 'Perfil y dirección principal del usuario' },
          '401': { description: 'No autenticado' },
        },
      },
      put: {
        tags: ['Auth'],
        summary: 'Actualizar perfil del usuario autenticado (SP_Usuarios_ActualizarPerfil)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['nombreCompleto'],
                properties: {
                  nombreCompleto: { type: 'string', example: 'Juan Pérez Actualizado' },
                  telefono: { type: 'string', example: '5555-9999' },
                  password: { type: 'string', minLength: 8, example: 'NuevaClave123!' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Perfil actualizado' },
          '401': { description: 'No autenticado' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 1.1: USERS (/api/users) - SOLO ADMIN
    // ========================================================================
    '/users': {
      get: {
        tags: ['Users'],
        summary: 'Listar usuarios con paginación y filtros (SP_Usuarios_ListarUsuarios)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 10 } },
          { in: 'query', name: 'idRol', schema: { type: 'integer' } },
          { in: 'query', name: 'activo', schema: { type: 'boolean' } },
          { in: 'query', name: 'busqueda', schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Lista paginada de usuarios' },
          '403': { description: 'Requiere rol Administrador' },
        },
      },
      post: {
        tags: ['Users'],
        summary: 'Crear usuario con rol específico (SP_Usuarios_CrearUsuarioPorAdmin)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idRol', 'correo', 'password', 'nombreCompleto'],
                properties: {
                  idRol: { type: 'integer', example: 2, description: '1=Admin, 2=Operador, 3=Cliente' },
                  correo: { type: 'string', format: 'email', example: 'operador@shopcart.gt' },
                  password: { type: 'string', minLength: 8, example: 'Operador123!' },
                  nombreCompleto: { type: 'string', example: 'María Operadora' },
                  telefono: { type: 'string', example: '4444-1111' },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Usuario creado exitosamente' },
          '403': { description: 'Requiere rol Administrador' },
        },
      },
    },
    '/users/roles': {
      get: {
        tags: ['Users'],
        summary: 'Listar catálogo de roles (SP_Usuarios_ListarRoles)',
        security: [{ bearerAuth: [] }],
        responses: {
          '200': { description: 'Roles del sistema' },
        },
      },
    },
    '/users/{idUsuario}/status': {
      patch: {
        tags: ['Users'],
        summary: 'Activar/desactivar usuario o cambiar su rol (SP_Usuarios_CambiarEstadoActivo)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idUsuario', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['activo'],
                properties: {
                  activo: { type: 'boolean', example: false },
                  idRol: { type: 'integer', example: 2 },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Estado del usuario actualizado' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 1.2: ADDRESSES (/api/addresses)
    // ========================================================================
    '/addresses': {
      get: {
        tags: ['Addresses'],
        summary: 'Listar direcciones activas del usuario autenticado (SP_Direcciones_ListarPorUsuario)',
        security: [{ bearerAuth: [] }],
        responses: {
          '200': { description: 'Lista de direcciones del cliente' },
        },
      },
      post: {
        tags: ['Addresses'],
        summary: 'Crear dirección de entrega (SP_Direcciones_Crear)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['direccionLinea', 'municipio', 'departamento'],
                properties: {
                  direccionLinea: { type: 'string', example: '6a Avenida 10-25 Zona 10' },
                  municipio: { type: 'string', example: 'Guatemala' },
                  departamento: { type: 'string', example: 'Guatemala' },
                  codigoPostal: { type: 'string', example: '01010' },
                  referencia: { type: 'string', example: 'Edificio Plaza, Nivel 4' },
                  esPrincipal: { type: 'boolean', default: true },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Dirección creada exitosamente' },
        },
      },
    },
    '/addresses/{idDireccion}': {
      put: {
        tags: ['Addresses'],
        summary: 'Actualizar dirección propia (SP_Direcciones_Actualizar)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idDireccion', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['direccionLinea', 'municipio', 'departamento'],
                properties: {
                  direccionLinea: { type: 'string' },
                  municipio: { type: 'string' },
                  departamento: { type: 'string' },
                  codigoPostal: { type: 'string' },
                  referencia: { type: 'string' },
                  esPrincipal: { type: 'boolean' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Dirección actualizada' },
          '403': { description: 'No pertenece al usuario autenticado' },
        },
      },
      delete: {
        tags: ['Addresses'],
        summary: 'Desactivar dirección propia (SP_Direcciones_Desactivar)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idDireccion', required: true, schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Dirección desactivada' },
        },
      },
    },
    '/addresses/{idDireccion}/principal': {
      patch: {
        tags: ['Addresses'],
        summary: 'Marcar dirección como principal (SP_Direcciones_EstablecerPrincipal)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idDireccion', required: true, schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Dirección principal actualizada' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 2: CATALOG (/api/catalog)
    // ========================================================================
    '/catalog/categories': {
      get: {
        tags: ['Catalog'],
        summary: 'Listar categorías con caché Redis (SP_Catalogo_ListarCategorias)',
        parameters: [
          { in: 'query', name: 'soloActivas', schema: { type: 'boolean', default: true } },
        ],
        responses: {
          '200': { description: 'Listado de categorías' },
        },
      },
      post: {
        tags: ['Catalog'],
        summary: 'Crear categoría (SP_Catalogo_CrearCategoria - Solo Admin)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['nombreCategoria'],
                properties: {
                  nombreCategoria: { type: 'string', example: 'Electrónica' },
                  descripcion: { type: 'string', example: 'Dispositivos y accesorios electrónicos' },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Categoría creada e invalidación de caché ejecutada' },
        },
      },
    },
    '/catalog/categories/{idCategoria}': {
      put: {
        tags: ['Catalog'],
        summary: 'Actualizar categoría (SP_Catalogo_ActualizarCategoria - Solo Admin)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idCategoria', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['nombreCategoria'],
                properties: {
                  nombreCategoria: { type: 'string' },
                  descripcion: { type: 'string' },
                  activo: { type: 'boolean', default: true },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Categoría actualizada' },
        },
      },
    },
    '/catalog/products': {
      get: {
        tags: ['Catalog'],
        summary: 'Listar productos con filtros, búsqueda y paginación server-side (SP_Catalogo_ListarProductos)',
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 12 } },
          { in: 'query', name: 'busqueda', schema: { type: 'string' } },
          { in: 'query', name: 'idCategoria', schema: { type: 'integer' } },
          { in: 'query', name: 'precioMinimo', schema: { type: 'number' } },
          { in: 'query', name: 'precioMaximo', schema: { type: 'number' } },
          { in: 'query', name: 'soloDisponibles', schema: { type: 'boolean', default: false } },
          { in: 'query', name: 'soloActivos', schema: { type: 'boolean', default: true } },
          {
            in: 'query',
            name: 'ordenarPor',
            schema: {
              type: 'string',
              enum: ['PRECIO_ASC', 'PRECIO_DESC', 'NOMBRE_ASC', 'NOMBRE_DESC', 'RECIENTES'],
              default: 'RECIENTES',
            },
          },
        ],
        responses: {
          '200': { description: 'Página de productos con rango de precios y disponibilidad real' },
        },
      },
      post: {
        tags: ['Catalog'],
        summary: 'Crear producto maestro (SP_Catalogo_CrearProducto - Solo Admin)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idCategoria', 'nombreProducto'],
                properties: {
                  idCategoria: { type: 'integer', example: 1 },
                  nombreProducto: { type: 'string', example: 'Camisa Oxford Clásica' },
                  descripcion: { type: 'string', example: '100% algodón peinado' },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Producto creado exitosamente' },
        },
      },
    },
    '/catalog/products/{idProducto}': {
      get: {
        tags: ['Catalog'],
        summary: 'Obtener detalle de producto con variantes, atributos y galería de imágenes (SP_Catalogo_ObtenerDetalleProducto)',
        parameters: [
          { in: 'path', name: 'idProducto', required: true, schema: { type: 'integer' } },
          { in: 'query', name: 'incluirInactivos', schema: { type: 'boolean', default: false } },
        ],
        responses: {
          '200': { description: 'Producto, variantes con StockDisponible, atributos y galería de imágenes' },
          '404': { description: 'Producto no encontrado' },
        },
      },
      put: {
        tags: ['Catalog'],
        summary: 'Actualizar producto (SP_Catalogo_ActualizarProducto - Solo Admin)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idProducto', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idCategoria', 'nombreProducto'],
                properties: {
                  idCategoria: { type: 'integer' },
                  nombreProducto: { type: 'string' },
                  descripcion: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Producto actualizado' },
        },
      },
    },
    '/catalog/products/{idProducto}/status': {
      patch: {
        tags: ['Catalog'],
        summary: 'Desactivar o reactivar producto sin borrado físico (SP_Catalogo_CambiarEstadoProducto)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idProducto', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['activo'],
                properties: {
                  activo: { type: 'boolean', example: false },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Estado del producto actualizado' },
        },
      },
    },
    '/catalog/products/{idProducto}/variants': {
      post: {
        tags: ['Catalog'],
        summary: 'Crear variante de producto con SKU único y stock inicial en Kardex (SP_Catalogo_CrearVariante)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idProducto', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['sku', 'nombreVariante', 'precio'],
                properties: {
                  sku: { type: 'string', example: 'CAM-OXF-AZUL-M' },
                  nombreVariante: { type: 'string', example: 'Azul - Talla M' },
                  precio: { type: 'number', example: 299.0 },
                  stockInicial: { type: 'integer', default: 10 },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Variante creada y stock inicial asentado en Kardex' },
        },
      },
    },
    '/catalog/variants/{idVariante}': {
      put: {
        tags: ['Catalog'],
        summary: 'Actualizar variante y auditar cambio de precio en HistorialPrecios (SP_Catalogo_ActualizarVariante)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['sku', 'nombreVariante', 'precio'],
                properties: {
                  sku: { type: 'string', example: 'CAM-OXF-AZUL-M' },
                  nombreVariante: { type: 'string', example: 'Azul - Talla M' },
                  precio: { type: 'number', example: 325.0 },
                  activo: { type: 'boolean', default: true },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Variante actualizada' },
        },
      },
    },
    '/catalog/variants/{idVariante}/attributes': {
      post: {
        tags: ['Catalog'],
        summary: 'Crear o actualizar atributo de variante (SP_Catalogo_GuardarAtributoVariante)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['clave', 'valor'],
                properties: {
                  clave: { type: 'string', example: 'Talla' },
                  valor: { type: 'string', example: 'M' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Atributo guardado' },
        },
      },
    },
    '/catalog/variants/{idVariante}/attributes/{idVarianteAtributo}': {
      delete: {
        tags: ['Catalog'],
        summary: 'Desactivar atributo de variante (borrado lógico - SP_Catalogo_EliminarAtributoVariante)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
          { in: 'path', name: 'idVarianteAtributo', required: true, schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Atributo desactivado exitosamente (eliminación lógica)' },
        },
      },
    },
    '/catalog/variants/{idVariante}/images/upload': {
      post: {
        tags: ['Catalog'],
        summary: 'Subir archivo de imagen física local para una variante (multipart/form-data - SP_Catalogo_AgregarImagenVariante)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'multipart/form-data': {
              schema: {
                type: 'object',
                required: ['file'],
                properties: {
                  file: {
                    type: 'string',
                    format: 'binary',
                    description: 'Archivo de imagen en formato JPEG, PNG o WebP (máx. 5 MB)',
                  },
                  esPrincipal: {
                    type: 'boolean',
                    default: false,
                    description: 'Indica si esta imagen debe ser la portada principal de la variante',
                  },
                  orden: {
                    type: 'integer',
                    description: 'Posición ordinal en el carrusel/galería',
                  },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Imagen subida al disco local y asociada exitosamente a la variante' },
          '400': { description: 'Archivo inválido o tamaño excedido' },
        },
      },
    },
    '/catalog/variants/{idVariante}/images': {
      post: {
        tags: ['Catalog'],
        summary: 'Asociar imagen por URL directa a una variante (SP_Catalogo_AgregarImagenVariante)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['urlImagen'],
                properties: {
                  urlImagen: { type: 'string', example: 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600' },
                  esPrincipal: { type: 'boolean', default: false },
                  orden: { type: 'integer', example: 1 },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Imagen asociada a la variante' },
        },
      },
    },
    '/catalog/variants/{idVariante}/images/{idVarianteImagen}/primary': {
      patch: {
        tags: ['Catalog'],
        summary: 'Establecer imagen como principal de la variante (SP_Catalogo_EstablecerImagenPrincipalVariante)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
          { in: 'path', name: 'idVarianteImagen', required: true, schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Imagen establecida como principal de la variante' },
        },
      },
    },
    '/catalog/variants/{idVariante}/images/{idVarianteImagen}': {
      delete: {
        tags: ['Catalog'],
        summary: 'Desactivar imagen de variante (borrado lógico - SP_Catalogo_EliminarImagenVariante)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
          { in: 'path', name: 'idVarianteImagen', required: true, schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Imagen de variante desactivada exitosamente' },
        },
      },
    },
    '/catalog/price-history': {
      get: {
        tags: ['Catalog'],
        summary: 'Consultar historial de cambios de precios (SP_Catalogo_ObtenerHistorialPrecios)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'idVariante', schema: { type: 'integer' } },
          { in: 'query', name: 'idProducto', schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Historial de precios por variante/producto' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 3: INVENTORY (/api/inventory)
    // ========================================================================
    '/inventory/stock': {
      get: {
        tags: ['Inventory'],
        summary: 'Listar existencias y conciliación contra Kardex (SP_Inventario_ListarExistencias)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 20 } },
          { in: 'query', name: 'idCategoria', schema: { type: 'integer' } },
          { in: 'query', name: 'busqueda', schema: { type: 'string' } },
          { in: 'query', name: 'soloBajoStock', schema: { type: 'boolean', default: false } },
          { in: 'query', name: 'umbralBajoStock', schema: { type: 'integer', default: 5 } },
        ],
        responses: {
          '200': { description: 'Existencias físicas, reservadas, disponibles y suma del Kardex' },
        },
      },
    },
    '/inventory/kardex': {
      get: {
        tags: ['Inventory'],
        summary: 'Consultar movimientos del Kardex (SP_Inventario_ConsultarKardex)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 20 } },
          { in: 'query', name: 'idVariante', schema: { type: 'integer' } },
          { in: 'query', name: 'idProducto', schema: { type: 'integer' } },
          {
            in: 'query',
            name: 'tipoMovimiento',
            schema: {
              type: 'string',
              enum: ['VENTA', 'AJUSTE_ENTRADA', 'AJUSTE_SALIDA', 'DEVOLUCION'],
            },
          },
          { in: 'query', name: 'fechaInicio', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'fechaFin', schema: { type: 'string', format: 'date-time' } },
        ],
        responses: {
          '200': { description: 'Historial paginado del Kardex' },
        },
      },
    },
    '/inventory/adjustments': {
      post: {
        tags: ['Inventory'],
        summary: 'Registrar ajuste manual de inventario con motivo obligatorio (SP_Inventario_RegistrarAjuste)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idVariante', 'tipoMovimiento', 'cantidad', 'motivo'],
                properties: {
                  idVariante: { type: 'integer', example: 1 },
                  tipoMovimiento: {
                    type: 'string',
                    enum: ['AJUSTE_ENTRADA', 'AJUSTE_SALIDA'],
                    example: 'AJUSTE_ENTRADA',
                  },
                  cantidad: { type: 'integer', example: 25 },
                  motivo: { type: 'string', example: 'Recepción de lote de proveedor #402' },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Ajuste aplicado y asentado en Kardex y Bitácora' },
          '400': { description: 'El ajuste dejaría la existencia en negativo o falta motivo' },
        },
      },
    },
    '/inventory/reservations': {
      post: {
        tags: ['Inventory'],
        summary: 'Reservar existencia de una variante por 15 minutos con bloqueo pesimista (SP_Inventario_ReservarExistencia)',
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: '#/components/parameters/GuestTokenHeader' }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idVariante', 'cantidad'],
                properties: {
                  idVariante: { type: 'integer', example: 1 },
                  cantidad: { type: 'integer', example: 2 },
                  tokenSesion: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Reserva temporal activa por 15 minutos' },
          '409': { description: 'Existencia disponible insuficiente' },
        },
      },
    },
    '/inventory/reservations/cart': {
      post: {
        tags: ['Inventory'],
        summary: 'Reservar todas las variantes del carrito activo por 15 minutos al iniciar el pago (SP_Inventario_ReservarCarritoCheckout)',
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: '#/components/parameters/GuestTokenHeader' }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idCarrito'],
                properties: {
                  idCarrito: { type: 'integer', example: 1 },
                  tokenSesion: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Reservas del carrito creadas por 15 minutos' },
          '409': { description: 'Existencia insuficiente en alguno de los productos' },
        },
      },
    },
    '/inventory/reservations/release': {
      post: {
        tags: ['Inventory'],
        summary: 'Liberar manualmente reservas temporales (SP_Inventario_LiberarReserva)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: false,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: {
                  idReserva: { type: 'integer' },
                  tokenSesion: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Reservas liberadas' },
        },
      },
    },
    '/inventory/reservations/release-expired': {
      post: {
        tags: ['Inventory'],
        summary: 'Barrer y liberar reservas con TTL vencido (SP_Inventario_LiberarReservasExpiradas)',
        security: [{ bearerAuth: [] }],
        responses: {
          '200': { description: 'Cantidad de reservas expiradas liberadas' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 4: CART (/api/cart)
    // ========================================================================
    '/cart': {
      get: {
        tags: ['Cart'],
        summary: 'Obtener carrito activo con subtotal, descuento, IVA 12% y total (SP_Carrito_ObtenerDetalle)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { $ref: '#/components/parameters/GuestTokenHeader' },
          { in: 'query', name: 'tokenInvitado', schema: { type: 'string' } },
          { in: 'query', name: 'codigoCupon', schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Encabezado y líneas del carrito activo' },
        },
      },
      delete: {
        tags: ['Cart'],
        summary: 'Vaciar carrito activo (SP_Carrito_Vaciar)',
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: '#/components/parameters/GuestTokenHeader' }],
        responses: {
          '200': { description: 'Carrito vaciado' },
        },
      },
    },
    '/cart/items': {
      post: {
        tags: ['Cart'],
        summary: 'Agregar o modificar producto en el carrito validando StockDisponible (SP_Carrito_AgregarOModificarItem)',
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: '#/components/parameters/GuestTokenHeader' }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idVariante', 'cantidad'],
                properties: {
                  idVariante: { type: 'integer', example: 1 },
                  cantidad: { type: 'integer', example: 1 },
                  modoOperacion: { type: 'string', enum: ['SUMAR', 'FIJAR'], default: 'SUMAR' },
                  tokenInvitado: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Carrito actualizado' },
          '409': { description: 'Cantidad supera la existencia disponible' },
        },
      },
    },
    '/cart/items/{idVariante}': {
      put: {
        tags: ['Cart'],
        summary: 'Fijar cantidad exacta de una variante en el carrito (SP_Carrito_AgregarOModificarItem)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
          { $ref: '#/components/parameters/GuestTokenHeader' },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['cantidad'],
                properties: {
                  cantidad: { type: 'integer', example: 3 },
                  tokenInvitado: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Cantidad actualizada' },
        },
      },
      delete: {
        tags: ['Cart'],
        summary: 'Eliminar una variante del carrito (SP_Carrito_EliminarItem)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idVariante', required: true, schema: { type: 'integer' } },
          { $ref: '#/components/parameters/GuestTokenHeader' },
        ],
        responses: {
          '200': { description: 'Producto eliminado del carrito' },
        },
      },
    },
    '/cart/merge': {
      post: {
        tags: ['Cart'],
        summary: 'Fusionar carrito de invitado hacia el carrito del usuario autenticado (SP_Carrito_FusionarInvitadoAUsuario)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['tokenInvitado'],
                properties: {
                  tokenInvitado: { type: 'string', example: 'guest-session-12345' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Carrito fusionado respetando topes de existencia disponible' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 5: COUPONS (/api/coupons)
    // ========================================================================
    '/coupons/validate': {
      post: {
        tags: ['Coupons'],
        summary: 'Validar y calcular descuento de un cupón sobre el carrito activo (SP_Cupones_ValidarYAplicarEnCarrito)',
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: '#/components/parameters/GuestTokenHeader' }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['codigo'],
                properties: {
                  codigo: { type: 'string', example: 'BIENVENIDA10' },
                  tokenInvitado: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Cupón válido con desglose de descuento y total' },
          '400': { description: 'Cupón vencido, agotado o no cumple mínimo de compra' },
        },
      },
    },
    '/coupons': {
      get: {
        tags: ['Coupons'],
        summary: 'Listar cupones con paginación y filtros (SP_Cupones_Listar - Solo Admin)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 15 } },
          { in: 'query', name: 'activo', schema: { type: 'boolean' } },
          { in: 'query', name: 'soloVigentes', schema: { type: 'boolean', default: false } },
          { in: 'query', name: 'tipoDescuento', schema: { type: 'string', enum: ['PORCENTAJE', 'MONTO_FIJO'] } },
          { in: 'query', name: 'busqueda', schema: { type: 'string' } },
        ],
        responses: {
          '200': { description: 'Lista paginada de cupones' },
        },
      },
      post: {
        tags: ['Coupons'],
        summary: 'Crear cupón de descuento (SP_Cupones_Crear - Solo Admin)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: [
                  'codigo',
                  'tipoDescuento',
                  'valorDescuento',
                  'fechaInicio',
                  'fechaFin',
                  'limiteUsosTotal',
                ],
                properties: {
                  codigo: { type: 'string', example: 'PROMO15' },
                  tipoDescuento: { type: 'string', enum: ['PORCENTAJE', 'MONTO_FIJO'], example: 'PORCENTAJE' },
                  valorDescuento: { type: 'number', example: 15.0 },
                  montoMinimoCompra: { type: 'number', example: 200.0 },
                  idCategoria: { type: 'integer', nullable: true, example: null },
                  fechaInicio: { type: 'string', format: 'date-time', example: '2026-10-26T00:00:00Z' },
                  fechaFin: { type: 'string', format: 'date-time', example: '2026-12-31T23:59:59Z' },
                  limiteUsosTotal: { type: 'integer', example: 100 },
                  limiteUsosPorCliente: { type: 'integer', example: 1 },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Cupón creado exitosamente' },
        },
      },
    },
    '/coupons/{idCupon}': {
      get: {
        tags: ['Coupons'],
        summary: 'Obtener detalle de cupón e historial de usos (SP_Cupones_ObtenerPorID - Solo Admin)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idCupon', required: true, schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Detalle del cupón y usos registrados' },
        },
      },
      put: {
        tags: ['Coupons'],
        summary: 'Actualizar cupón (SP_Cupones_Actualizar - Solo Admin)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idCupon', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: [
                  'codigo',
                  'tipoDescuento',
                  'valorDescuento',
                  'fechaInicio',
                  'fechaFin',
                  'limiteUsosTotal',
                ],
                properties: {
                  codigo: { type: 'string' },
                  tipoDescuento: { type: 'string', enum: ['PORCENTAJE', 'MONTO_FIJO'] },
                  valorDescuento: { type: 'number' },
                  montoMinimoCompra: { type: 'number' },
                  idCategoria: { type: 'integer', nullable: true },
                  fechaInicio: { type: 'string', format: 'date-time' },
                  fechaFin: { type: 'string', format: 'date-time' },
                  limiteUsosTotal: { type: 'integer' },
                  limiteUsosPorCliente: { type: 'integer' },
                  activo: { type: 'boolean', default: true },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Cupón actualizado' },
        },
      },
    },
    '/coupons/{idCupon}/status': {
      patch: {
        tags: ['Coupons'],
        summary: 'Activar o desactivar cupón (SP_Cupones_CambiarEstadoActivo - Solo Admin)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idCupon', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['activo'],
                properties: {
                  activo: { type: 'boolean', example: false },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Estado del cupón actualizado' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 6: ORDERS & CHECKOUT (/api/orders)
    // ========================================================================
    '/orders/checkout': {
      post: {
        tags: ['Orders'],
        summary: 'Checkout atómico e idempotente (SP_Pedidos_CrearCheckout)',
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: '#/components/parameters/IdempotencyKeyHeader' }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idDireccion'],
                properties: {
                  idDireccion: { type: 'integer', example: 1 },
                  idempotencyKey: { type: 'string', example: 'chk-20261102-unique-001' },
                  codigoCupon: { type: 'string', example: 'PROMO15' },
                  metodoPago: { type: 'string', default: 'TARJETA', example: 'TARJETA' },
                  transaccionId: { type: 'string', example: 'AUTH-998877' },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Pedido confirmado atómicamente (congela precios, descuenta stock y registra Kardex)' },
          '200': { description: 'Respuesta idempotente (reintento de una solicitud ya procesada)' },
          '409': { description: 'Existencia insuficiente en inventario' },
        },
      },
    },
    '/orders': {
      get: {
        tags: ['Orders'],
        summary: 'Listar pedidos con filtros por estado, cliente y fechas (SP_Pedidos_Listar)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 15 } },
          {
            in: 'query',
            name: 'estadoPedido',
            schema: {
              type: 'string',
              enum: ['PENDIENTE', 'PAGADO', 'EN_PREPARACION', 'ENVIADO', 'ENTREGADO', 'CANCELADO'],
            },
          },
          { in: 'query', name: 'idCliente', schema: { type: 'integer' } },
          { in: 'query', name: 'fechaInicio', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'fechaFin', schema: { type: 'string', format: 'date-time' } },
        ],
        responses: {
          '200': { description: 'Lista paginada de pedidos (aislada por rol)' },
        },
      },
    },
    '/orders/{idPedido}': {
      get: {
        tags: ['Orders'],
        summary: 'Obtener detalle completo de un pedido, líneas, pagos e historial de estados (SP_Pedidos_ObtenerDetalle)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idPedido', required: true, schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Detalle del pedido con sus 4 secciones' },
          '403': { description: 'Intento de acceder al pedido de otro cliente' },
        },
      },
    },
    '/orders/{idPedido}/status': {
      patch: {
        tags: ['Orders'],
        summary: 'Cambiar o cancelar estado de un pedido con validación de transiciones y reintegro a Kardex (SP_Pedidos_CambiarEstado)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idPedido', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['estadoNuevo'],
                properties: {
                  estadoNuevo: {
                    type: 'string',
                    enum: ['PAGADO', 'EN_PREPARACION', 'ENVIADO', 'ENTREGADO', 'CANCELADO'],
                    example: 'EN_PREPARACION',
                  },
                  motivo: { type: 'string', example: 'Pedido empacado en bodega central' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Estado actualizado y registrado en HistorialEstadosPedido' },
          '409': { description: 'Transición de estado no permitida' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 7: RETURNS (/api/returns)
    // ========================================================================
    '/returns': {
      get: {
        tags: ['Returns'],
        summary: 'Listar devoluciones paginadas (SP_Devoluciones_Listar)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 15 } },
          { in: 'query', name: 'estado', schema: { type: 'string', enum: ['SOLICITADA', 'APROBADA', 'RECHAZADA'] } },
          { in: 'query', name: 'idPedido', schema: { type: 'integer' } },
          { in: 'query', name: 'idCliente', schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Lista paginada de devoluciones' },
        },
      },
      post: {
        tags: ['Returns'],
        summary: 'Solicitar devolución total o parcial por línea de pedido entregado (SP_Devoluciones_Solicitar)',
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['idPedido', 'motivo', 'items'],
                properties: {
                  idPedido: { type: 'integer', example: 1 },
                  motivo: { type: 'string', example: 'Talla incorrecta en una de las prendas' },
                  items: {
                    type: 'array',
                    items: {
                      type: 'object',
                      required: ['idVariante', 'cantidad'],
                      properties: {
                        idVariante: { type: 'integer', example: 1 },
                        cantidad: { type: 'integer', example: 1 },
                      },
                    },
                  },
                },
              },
            },
          },
        },
        responses: {
          '201': { description: 'Devolución solicitada exitosamente' },
          '400': { description: 'La cantidad supera lo comprado disponible para devolver' },
        },
      },
    },
    '/returns/{idDevolucion}': {
      get: {
        tags: ['Returns'],
        summary: 'Obtener detalle de una devolución (SP_Devoluciones_ObtenerDetalle)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idDevolucion', required: true, schema: { type: 'integer' } },
        ],
        responses: {
          '200': { description: 'Encabezado y líneas de la devolución' },
        },
      },
    },
    '/returns/{idDevolucion}/resolve': {
      patch: {
        tags: ['Returns'],
        summary: 'Aprobar o rechazar devolución con reintegro automático al Kardex (SP_Devoluciones_Resolver)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'path', name: 'idDevolucion', required: true, schema: { type: 'integer' } },
        ],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['nuevoEstado'],
                properties: {
                  nuevoEstado: { type: 'string', enum: ['APROBADA', 'RECHAZADA'], example: 'APROBADA' },
                  observacion: { type: 'string', example: 'Producto recibido en buen estado en almacén' },
                },
              },
            },
          },
        },
        responses: {
          '200': { description: 'Devolución resuelta y stock reintegrado si fue aprobada' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 8: REPORTS & DASHBOARD (/api/reports) - SOLO ADMIN
    // ========================================================================
    '/reports/kpis': {
      get: {
        tags: ['Reports'],
        summary: 'Obtener tarjetas de KPIs ejecutivos (SP_Dashboard_ObtenerResumenKPIs)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'fechaInicio', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'fechaFin', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'minutosAbandono', schema: { type: 'integer', default: 60 } },
        ],
        responses: {
          '200': { description: 'Resumen de ventas netas en GTQ, ticket promedio y carritos abandonados' },
        },
      },
    },
    '/reports/sales-by-period': {
      get: {
        tags: ['Reports'],
        summary: 'Ventas netas por día, semana o mes (SP_Dashboard_VentasPorPeriodo)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'agrupacion', schema: { type: 'string', enum: ['DIA', 'SEMANA', 'MES'], default: 'DIA' } },
          { in: 'query', name: 'fechaInicio', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'fechaFin', schema: { type: 'string', format: 'date-time' } },
        ],
        responses: {
          '200': { description: 'Serie temporal de ventas netas y número de pedidos' },
        },
      },
    },
    '/reports/sales-by-category': {
      get: {
        tags: ['Reports'],
        summary: 'Ventas netas por categoría y porcentaje de participación (SP_Dashboard_VentasPorCategoria)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'fechaInicio', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'fechaFin', schema: { type: 'string', format: 'date-time' } },
        ],
        responses: {
          '200': { description: 'Ventas agrupadas por categoría' },
        },
      },
    },
    '/reports/top-products': {
      get: {
        tags: ['Reports'],
        summary: 'Top 10 productos más vendidos del periodo (SP_Dashboard_TopProductosMasVendidos)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'fechaInicio', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'fechaFin', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'topN', schema: { type: 'integer', default: 10 } },
        ],
        responses: {
          '200': { description: 'Ranking de productos más vendidos' },
        },
      },
    },
    '/reports/abandoned-carts': {
      get: {
        tags: ['Reports'],
        summary: 'Listado paginado de carritos abandonados (SP_Dashboard_ListarCarritosAbandonados)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 15 } },
          { in: 'query', name: 'minutosInactividad', schema: { type: 'integer', default: 60 } },
        ],
        responses: {
          '200': { description: 'Carritos sin actividad y monto potencial total en GTQ' },
        },
      },
    },

    // ========================================================================
    // MÓDULO 9: AUDIT (/api/audit) - SOLO ADMIN
    // ========================================================================
    '/audit': {
      get: {
        tags: ['Audit'],
        summary: 'Consultar Bitácora inmutable con filtro por módulo y acción (SP_Auditoria_ConsultarBitacora)',
        security: [{ bearerAuth: [] }],
        parameters: [
          { in: 'query', name: 'numeroPagina', schema: { type: 'integer', default: 1 } },
          { in: 'query', name: 'tamanoPagina', schema: { type: 'integer', default: 25 } },
          {
            in: 'query',
            name: 'modulo',
            schema: {
              type: 'string',
              example: 'PRODUCTOS',
              description: 'USUARIOS, CATEGORIAS, PRODUCTOS, VARIANTES, PRECIOS, INVENTARIO, CUPONES, PEDIDOS, DEVOLUCIONES',
            },
          },
          { in: 'query', name: 'accion', schema: { type: 'string', enum: ['CREAR', 'MODIFICAR', 'DESACTIVAR'] } },
          { in: 'query', name: 'idUsuario', schema: { type: 'integer' } },
          { in: 'query', name: 'fechaInicio', schema: { type: 'string', format: 'date-time' } },
          { in: 'query', name: 'fechaFin', schema: { type: 'string', format: 'date-time' } },
        ],
        responses: {
          '200': { description: 'Registros de auditoría de la Bitácora inmutable' },
        },
      },
    },
  },
};

export const swaggerRouter = Router();

swaggerRouter.get('/docs.json', (_req: Request, res: Response) => {
  res.status(200).json(openApiSpec);
});

swaggerRouter.get('/docs', (_req: Request, res: Response) => {
  const html = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>ShopCart API — Swagger UI</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.18.2/swagger-ui.css" />
  <style>
    body { margin: 0; background: #fafafa; }
    .topbar { display: none; }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5.18.2/swagger-ui-bundle.js"></script>
  <script src="https://unpkg.com/swagger-ui-dist@5.18.2/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function () {
      window.ui = SwaggerUIBundle({
        url: '/api/docs.json',
        dom_id: '#swagger-ui',
        deepLinking: true,
        persistAuthorization: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        layout: 'StandaloneLayout'
      });
    };
  </script>
</body>
</html>`;

  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; style-src 'self' 'unsafe-inline' https://unpkg.com; script-src 'self' 'unsafe-inline' https://unpkg.com; img-src 'self' data: https://unpkg.com; connect-src 'self';",
  );
  res.status(200).type('html').send(html);
});
