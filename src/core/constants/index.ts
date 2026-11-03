// src/core/constants/index.ts

export const ROLES = {
  ADMIN: 1,
  OPERADOR: 2,
  CLIENTE: 3,
} as const;

export type RoleId = (typeof ROLES)[keyof typeof ROLES];

export const ROLE_NAMES = {
  ADMIN: 'Administrador',
  OPERADOR: 'Operador',
  CLIENTE: 'Cliente',
} as const;

export type RoleName = (typeof ROLE_NAMES)[keyof typeof ROLE_NAMES];

export const ESTADOS_PEDIDO = {
  PENDIENTE: 'PENDIENTE',
  PAGADO: 'PAGADO',
  EN_PREPARACION: 'EN_PREPARACION',
  ENVIADO: 'ENVIADO',
  ENTREGADO: 'ENTREGADO',
  CANCELADO: 'CANCELADO',
} as const;

export type EstadoPedido = (typeof ESTADOS_PEDIDO)[keyof typeof ESTADOS_PEDIDO];

export const TIPOS_MOVIMIENTO_KARDEX = {
  VENTA: 'VENTA',
  AJUSTE_ENTRADA: 'AJUSTE_ENTRADA',
  AJUSTE_SALIDA: 'AJUSTE_SALIDA',
  DEVOLUCION: 'DEVOLUCION',
} as const;

export type TipoMovimientoKardex =
  (typeof TIPOS_MOVIMIENTO_KARDEX)[keyof typeof TIPOS_MOVIMIENTO_KARDEX];

export const ESTADOS_RESERVA = {
  ACTIVA: 'ACTIVA',
  CONFIRMADA: 'CONFIRMADA',
  LIBERADA: 'LIBERADA',
} as const;

export type EstadoReserva = (typeof ESTADOS_RESERVA)[keyof typeof ESTADOS_RESERVA];

export const ESTADOS_CARRITO = {
  ACTIVO: 'ACTIVO',
  ABANDONADO: 'ABANDONADO',
  CONVERTIDO: 'CONVERTIDO',
} as const;

export type EstadoCarrito = (typeof ESTADOS_CARRITO)[keyof typeof ESTADOS_CARRITO];

export const TIPOS_DESCUENTO = {
  PORCENTAJE: 'PORCENTAJE',
  MONTO_FIJO: 'MONTO_FIJO',
} as const;

export type TipoDescuento = (typeof TIPOS_DESCUENTO)[keyof typeof TIPOS_DESCUENTO];

export const ESTADOS_DEVOLUCION = {
  SOLICITADA: 'SOLICITADA',
  APROBADA: 'APROBADA',
  RECHAZADA: 'RECHAZADA',
} as const;

export type EstadoDevolucion =
  (typeof ESTADOS_DEVOLUCION)[keyof typeof ESTADOS_DEVOLUCION];

export const ACCIONES_BITACORA = {
  CREAR: 'CREAR',
  MODIFICAR: 'MODIFICAR',
  DESACTIVAR: 'DESACTIVAR',
} as const;

export type AccionBitacora =
  (typeof ACCIONES_BITACORA)[keyof typeof ACCIONES_BITACORA];

export const ERROR_CODES = {
  VALIDATION_ERROR: 'ERR_VALIDACION',
  BAD_REQUEST: 'ERR_SOLICITUD_INVALIDA',
  UNAUTHORIZED: 'ERR_NO_AUTORIZADO',
  TOKEN_EXPIRED: 'ERR_TOKEN_EXPIRADO',
  FORBIDDEN: 'ERR_ACCESO_DENEGADO',
  NOT_FOUND: 'ERR_RECURSO_NO_ENCONTRADO',
  CONFLICT: 'ERR_CONFLICTO_NEGOCIO',
  INSUFFICIENT_STOCK: 'ERR_STOCK_INSUFICIENTE',
  COUPON_INVALID: 'ERR_CUPON_INVALIDO',
  INVALID_STATE_TRANSITION: 'ERR_TRANSICION_ESTADO_INVALIDA',
  DATABASE_ERROR: 'ERR_BASE_DE_DATOS',
  INTERNAL_ERROR: 'ERR_ERROR_INTERNO',
} as const;

export type ErrorCode = (typeof ERROR_CODES)[keyof typeof ERROR_CODES];
