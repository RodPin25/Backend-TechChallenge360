-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 01_schema.sql
-- DESCRIPCIÓN: Creación de tablas, restricciones, llaves foráneas e índices.
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- NOTA: Precios en Quetzales (GTQ) con IVA del 12% incluido. Tipos DECIMAL exactos.
-- ============================================================================

-- 1. CREACIÓN O CONTEXTO DE BASE DE DATOS
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'ShopCartDB')
BEGIN
CREATE DATABASE ShopCartDB;
END;
GO

USE ShopCartDB;
GO

-- ============================================================================
-- LIMPIEZA DE TABLAS EN CASO DE REGENERACIÓN (Orden inverso a dependencias)
-- ============================================================================
IF OBJECT_ID('dbo.Bitacora', 'U') IS NOT NULL DROP TABLE dbo.Bitacora;
IF OBJECT_ID('dbo.Kardex', 'U') IS NOT NULL DROP TABLE dbo.Kardex;
IF OBJECT_ID('dbo.DevolucionDetalle', 'U') IS NOT NULL DROP TABLE dbo.DevolucionDetalle;
IF OBJECT_ID('dbo.Devoluciones', 'U') IS NOT NULL DROP TABLE dbo.Devoluciones;
IF OBJECT_ID('dbo.Pagos', 'U') IS NOT NULL DROP TABLE dbo.Pagos;
IF OBJECT_ID('dbo.HistorialEstadosPedido', 'U') IS NOT NULL DROP TABLE dbo.HistorialEstadosPedido;
IF OBJECT_ID('dbo.CuponesUso', 'U') IS NOT NULL DROP TABLE dbo.CuponesUso;
IF OBJECT_ID('dbo.PedidoDetalle', 'U') IS NOT NULL DROP TABLE dbo.PedidoDetalle;
IF OBJECT_ID('dbo.Pedidos', 'U') IS NOT NULL DROP TABLE dbo.Pedidos;
IF OBJECT_ID('dbo.CarritoDetalle', 'U') IS NOT NULL DROP TABLE dbo.CarritoDetalle;
IF OBJECT_ID('dbo.Carritos', 'U') IS NOT NULL DROP TABLE dbo.Carritos;
IF OBJECT_ID('dbo.ReservasExistencia', 'U') IS NOT NULL DROP TABLE dbo.ReservasExistencia;
IF OBJECT_ID('dbo.HistorialPrecios', 'U') IS NOT NULL DROP TABLE dbo.HistorialPrecios;
IF OBJECT_ID('dbo.VarianteImagenes', 'U') IS NOT NULL DROP TABLE dbo.VarianteImagenes;
IF OBJECT_ID('dbo.VarianteAtributos', 'U') IS NOT NULL DROP TABLE dbo.VarianteAtributos;
IF OBJECT_ID('dbo.Variantes', 'U') IS NOT NULL DROP TABLE dbo.Variantes;
IF OBJECT_ID('dbo.Cupones', 'U') IS NOT NULL DROP TABLE dbo.Cupones;
IF OBJECT_ID('dbo.Productos', 'U') IS NOT NULL DROP TABLE dbo.Productos;
IF OBJECT_ID('dbo.Categorias', 'U') IS NOT NULL DROP TABLE dbo.Categorias;
IF OBJECT_ID('dbo.Direcciones', 'U') IS NOT NULL DROP TABLE dbo.Direcciones;
IF OBJECT_ID('dbo.Usuarios', 'U') IS NOT NULL DROP TABLE dbo.Usuarios;
IF OBJECT_ID('dbo.Roles', 'U') IS NOT NULL DROP TABLE dbo.Roles;
GO

-- ============================================================================
-- MÓDULO 1: AUTENTICACIÓN Y USUARIOS (RF-01)
-- ============================================================================

CREATE TABLE dbo.Roles (
IDRol INT IDENTITY(1,1) NOT NULL,
NombreRol VARCHAR(30) NOT NULL,
Descripcion VARCHAR(150) NULL,
CONSTRAINT PK_Roles PRIMARY KEY CLUSTERED (IDRol),
CONSTRAINT UQ_Roles_NombreRol UNIQUE (NombreRol)
);
GO

CREATE TABLE dbo.Usuarios (
IDUsuario INT IDENTITY(1,1) NOT NULL,
IDRol INT NOT NULL,
Correo VARCHAR(120) NOT NULL,
PasswordHash VARCHAR(255) NOT NULL,
NombreCompleto NVARCHAR(120) NOT NULL,
Telefono VARCHAR(20) NULL,
Activo BIT NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Usuarios_FechaCreacion DEFAULT (SYSDATETIME()),
CONSTRAINT PK_Usuarios PRIMARY KEY CLUSTERED (IDUsuario),
CONSTRAINT UQ_Usuarios_Correo UNIQUE (Correo),
CONSTRAINT FK_Usuarios_Roles FOREIGN KEY (IDRol) REFERENCES dbo.Roles (IDRol)
);
GO

CREATE TABLE dbo.Direcciones (
IDDireccion INT IDENTITY(1,1) NOT NULL,
IDUsuario INT NOT NULL,
DireccionLinea NVARCHAR(200) NOT NULL,
Municipio NVARCHAR(100) NOT NULL,
Departamento NVARCHAR(100) NOT NULL,
CodigoPostal VARCHAR(10) NULL,
Referencia NVARCHAR(200) NULL,
EsPrincipal BIT NOT NULL CONSTRAINT DF_Direcciones_EsPrincipal DEFAULT (0),
Activo BIT NOT NULL CONSTRAINT DF_Direcciones_Activo DEFAULT (1),
CONSTRAINT PK_Direcciones PRIMARY KEY CLUSTERED (IDDireccion),
CONSTRAINT FK_Direcciones_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario)
);
GO

-- ============================================================================
-- MÓDULO 2: CATÁLOGO Y PRODUCTOS (RF-02)
-- ============================================================================

CREATE TABLE dbo.Categorias (
IDCategoria INT IDENTITY(1,1) NOT NULL,
NombreCategoria NVARCHAR(100) NOT NULL,
Descripcion NVARCHAR(250) NULL,
Activo BIT NOT NULL CONSTRAINT DF_Categorias_Activo DEFAULT (1),
CONSTRAINT PK_Categorias PRIMARY KEY CLUSTERED (IDCategoria),
CONSTRAINT UQ_Categorias_NombreCategoria UNIQUE (NombreCategoria)
);
GO

CREATE TABLE dbo.Productos (
IDProducto INT IDENTITY(1,1) NOT NULL,
IDCategoria INT NOT NULL,
NombreProducto NVARCHAR(150) NOT NULL,
Descripcion NVARCHAR(MAX) NULL,
Activo BIT NOT NULL CONSTRAINT DF_Productos_Activo DEFAULT (1),
FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Productos_FechaCreacion DEFAULT (SYSDATETIME()),
CONSTRAINT PK_Productos PRIMARY KEY CLUSTERED (IDProducto),
CONSTRAINT FK_Productos_Categorias FOREIGN KEY (IDCategoria) REFERENCES dbo.Categorias (IDCategoria)
);
GO

CREATE TABLE dbo.Variantes (
IDVariante INT IDENTITY(1,1) NOT NULL,
IDProducto INT NOT NULL,
SKU VARCHAR(50) NOT NULL,
NombreVariante NVARCHAR(100) NOT NULL,
Precio DECIMAL(12,2) NOT NULL,
StockFisico INT NOT NULL CONSTRAINT DF_Variantes_StockFisico DEFAULT (0),
Activo BIT NOT NULL CONSTRAINT DF_Variantes_Activo DEFAULT (1),
CONSTRAINT PK_Variantes PRIMARY KEY CLUSTERED (IDVariante),
CONSTRAINT UQ_Variantes_SKU UNIQUE (SKU),
CONSTRAINT CHK_Variantes_Precio CHECK (Precio >= 0),
CONSTRAINT CHK_Variantes_StockFisico CHECK (StockFisico >= 0),
CONSTRAINT FK_Variantes_Productos FOREIGN KEY (IDProducto) REFERENCES dbo.Productos (IDProducto)
);
GO

CREATE TABLE dbo.VarianteAtributos (
IDVarianteAtributo INT IDENTITY(1,1) NOT NULL,
IDVariante INT NOT NULL,
Clave NVARCHAR(50) NOT NULL,
Valor NVARCHAR(100) NOT NULL,
Activo BIT NOT NULL CONSTRAINT DF_VarianteAtributos_Activo DEFAULT (1),
CONSTRAINT PK_VarianteAtributos PRIMARY KEY CLUSTERED (IDVarianteAtributo),
CONSTRAINT FK_VarianteAtributos_Variantes FOREIGN KEY (IDVariante) REFERENCES dbo.Variantes (IDVariante)
);
GO

CREATE TABLE dbo.VarianteImagenes (
    IDVarianteImagen INT IDENTITY(1,1) NOT NULL,
    IDVariante INT NOT NULL,
    UrlImagen NVARCHAR(500) NOT NULL,
    EsPrincipal BIT NOT NULL CONSTRAINT DF_VarianteImagenes_EsPrincipal DEFAULT (0),
    Orden INT NOT NULL CONSTRAINT DF_VarianteImagenes_Orden DEFAULT (1),
    Activo BIT NOT NULL CONSTRAINT DF_VarianteImagenes_Activo DEFAULT (1),
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_VarianteImagenes_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_VarianteImagenes PRIMARY KEY CLUSTERED (IDVarianteImagen),
    CONSTRAINT FK_VarianteImagenes_Variantes FOREIGN KEY (IDVariante) REFERENCES dbo.Variantes (IDVariante)
);
GO

CREATE TABLE dbo.HistorialPrecios (
IDHistorialPrecio BIGINT IDENTITY(1,1) NOT NULL,
IDVariante INT NOT NULL,
PrecioAnterior DECIMAL(12,2) NOT NULL,
PrecioNuevo DECIMAL(12,2) NOT NULL,
IDUsuario INT NOT NULL,
FechaModificacion DATETIME2(0) NOT NULL CONSTRAINT DF_HistorialPrecios_Fecha DEFAULT (SYSDATETIME()),
CONSTRAINT PK_HistorialPrecios PRIMARY KEY CLUSTERED (IDHistorialPrecio),
CONSTRAINT FK_HistorialPrecios_Variantes FOREIGN KEY (IDVariante) REFERENCES dbo.Variantes (IDVariante),
CONSTRAINT FK_HistorialPrecios_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario)
);
GO

-- ============================================================================
-- MÓDULO 3: INVENTARIO Y RESERVAS TEMPORALES (RF-03, RF-06)
-- ============================================================================

CREATE TABLE dbo.ReservasExistencia (
IDReserva BIGINT IDENTITY(1,1) NOT NULL,
IDVariante INT NOT NULL,
IDUsuario INT NULL,
TokenSesion VARCHAR(100) NULL,
Cantidad INT NOT NULL,
FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Reservas_FechaCreacion DEFAULT (SYSDATETIME()),
FechaExpiracion DATETIME2(0) NOT NULL,
Estado VARCHAR(20) NOT NULL CONSTRAINT DF_Reservas_Estado DEFAULT ('ACTIVA'),
CONSTRAINT PK_ReservasExistencia PRIMARY KEY CLUSTERED (IDReserva),
CONSTRAINT CHK_Reservas_Cantidad CHECK (Cantidad > 0),
CONSTRAINT CHK_Reservas_Estado CHECK (Estado IN ('ACTIVA', 'CONFIRMADA', 'LIBERADA')),
CONSTRAINT FK_ReservasExistencia_Variantes FOREIGN KEY (IDVariante) REFERENCES dbo.Variantes (IDVariante),
CONSTRAINT FK_ReservasExistencia_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario)
);
GO

-- ============================================================================
-- MÓDULO 4: CARRITO DE COMPRAS (RF-04)
-- ============================================================================

CREATE TABLE dbo.Carritos (
IDCarrito INT IDENTITY(1,1) NOT NULL,
IDUsuario INT NULL,
TokenInvitado VARCHAR(100) NULL,
Estado VARCHAR(20) NOT NULL CONSTRAINT DF_Carritos_Estado DEFAULT ('ACTIVO'),
FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Carritos_FechaCreacion DEFAULT (SYSDATETIME()),
FechaActualizacion DATETIME2(0) NOT NULL CONSTRAINT DF_Carritos_FechaActualizacion DEFAULT (SYSDATETIME()),
CONSTRAINT PK_Carritos PRIMARY KEY CLUSTERED (IDCarrito),
CONSTRAINT CHK_Carritos_Estado CHECK (Estado IN ('ACTIVO', 'ABANDONADO', 'CONVERTIDO')),
CONSTRAINT FK_Carritos_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario)
);
GO

CREATE TABLE dbo.CarritoDetalle (
IDCarritoDetalle INT IDENTITY(1,1) NOT NULL,
IDCarrito INT NOT NULL,
IDVariante INT NOT NULL,
Cantidad INT NOT NULL,
FechaAgregado DATETIME2(0) NOT NULL CONSTRAINT DF_CarritoDetalle_FechaAgregado DEFAULT (SYSDATETIME()),
CONSTRAINT PK_CarritoDetalle PRIMARY KEY CLUSTERED (IDCarritoDetalle),
CONSTRAINT CHK_CarritoDetalle_Cantidad CHECK (Cantidad > 0),
CONSTRAINT FK_CarritoDetalle_Carritos FOREIGN KEY (IDCarrito) REFERENCES dbo.Carritos (IDCarrito),
CONSTRAINT FK_CarritoDetalle_Variantes FOREIGN KEY (IDVariante) REFERENCES dbo.Variantes (IDVariante),
CONSTRAINT UQ_CarritoDetalle_Item UNIQUE (IDCarrito, IDVariante)
);
GO

-- ============================================================================
-- MÓDULO 5: CUPONES Y PROMOCIONES (RF-05)
-- ============================================================================

CREATE TABLE dbo.Cupones (
    IDCupon INT IDENTITY(1,1) NOT NULL,
    Codigo VARCHAR(30) NOT NULL,
    TipoDescuento VARCHAR(20) NOT NULL,
    ValorDescuento DECIMAL(12,2) NOT NULL,
    MontoMinimoCompra DECIMAL(12,2) NOT NULL CONSTRAINT DF_Cupones_MontoMinimo DEFAULT (0.00),
    IDCategoria INT NULL,
    FechaInicio DATETIME2(0) NOT NULL,
    FechaFin DATETIME2(0) NOT NULL,
    LimiteUsosTotal INT NOT NULL,
    UsosActuales INT NOT NULL CONSTRAINT DF_Cupones_UsosActuales DEFAULT (0),
    LimiteUsosPorCliente INT NOT NULL CONSTRAINT DF_Cupones_LimitePorCliente DEFAULT (1),
    Activo BIT NOT NULL CONSTRAINT DF_Cupones_Activo DEFAULT (1),
    CONSTRAINT PK_Cupones PRIMARY KEY CLUSTERED (IDCupon),
    CONSTRAINT UQ_Cupones_Codigo UNIQUE (Codigo),
    CONSTRAINT CHK_Cupones_Tipo CHECK (TipoDescuento IN ('PORCENTAJE', 'MONTO_FIJO')),
    CONSTRAINT CHK_Cupones_Valor CHECK (ValorDescuento > 0 AND (TipoDescuento <> 'PORCENTAJE' OR ValorDescuento <= 100.00)),
    CONSTRAINT CHK_Cupones_Fechas CHECK (FechaFin >= FechaInicio),
    CONSTRAINT FK_Cupones_Categorias FOREIGN KEY (IDCategoria) REFERENCES dbo.Categorias (IDCategoria)
);
GO

-- ============================================================================
-- MÓDULO 6: PEDIDOS Y CHECKOUT (RF-06, RF-07)
-- ============================================================================

CREATE TABLE dbo.Pedidos (
    IDPedido INT IDENTITY(1,1) NOT NULL,
    IDUsuario INT NOT NULL,
    IDDireccion INT NOT NULL,
    IDCupon INT NULL,
    IdempotencyKey VARCHAR(64) NOT NULL,
    EstadoPedido VARCHAR(30) NOT NULL CONSTRAINT DF_Pedidos_Estado DEFAULT ('PENDIENTE'),
    Subtotal DECIMAL(12,2) NOT NULL,
    MontoDescuento DECIMAL(12,2) NOT NULL CONSTRAINT DF_Pedidos_Descuento DEFAULT (0.00),
    MontoIVA DECIMAL(12,2) NOT NULL,
    Total DECIMAL(12,2) NOT NULL,
    DireccionEntregaTexto NVARCHAR(500) NOT NULL,
    FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Pedidos_FechaCreacion DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Pedidos PRIMARY KEY CLUSTERED (IDPedido),
    CONSTRAINT UQ_Pedidos_Idempotency UNIQUE (IdempotencyKey),
    CONSTRAINT CHK_Pedidos_Estado CHECK (EstadoPedido IN ('PENDIENTE', 'PAGADO', 'EN_PREPARACION', 'ENVIADO', 'ENTREGADO', 'CANCELADO')),
    CONSTRAINT CHK_Pedidos_Total CHECK (Total >= 0),
    CONSTRAINT CHK_Pedidos_Montos CHECK (Subtotal >= 0 AND MontoDescuento >= 0 AND MontoDescuento <= Subtotal AND MontoIVA >= 0),
    CONSTRAINT FK_Pedidos_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario),
    CONSTRAINT FK_Pedidos_Direcciones FOREIGN KEY (IDDireccion) REFERENCES dbo.Direcciones (IDDireccion),
    CONSTRAINT FK_Pedidos_Cupones FOREIGN KEY (IDCupon) REFERENCES dbo.Cupones (IDCupon)
);
GO

CREATE TABLE dbo.PedidoDetalle (
IDPedidoDetalle INT IDENTITY(1,1) NOT NULL,
IDPedido INT NOT NULL,
IDVariante INT NOT NULL,
Cantidad INT NOT NULL,
PrecioUnitarioCongelado DECIMAL(12,2) NOT NULL,
DescuentoAplicado DECIMAL(12,2) NOT NULL CONSTRAINT DF_PedidoDetalle_Descuento DEFAULT (0.00),
SubtotalLinea DECIMAL(12,2) NOT NULL,
CONSTRAINT PK_PedidoDetalle PRIMARY KEY CLUSTERED (IDPedidoDetalle),
CONSTRAINT CHK_PedidoDetalle_Cantidad CHECK (Cantidad > 0),
CONSTRAINT FK_PedidoDetalle_Pedidos FOREIGN KEY (IDPedido) REFERENCES dbo.Pedidos (IDPedido),
CONSTRAINT FK_PedidoDetalle_Variantes FOREIGN KEY (IDVariante) REFERENCES dbo.Variantes (IDVariante)
);
GO

CREATE TABLE dbo.CuponesUso (
IDCuponUso INT IDENTITY(1,1) NOT NULL,
IDCupon INT NOT NULL,
IDUsuario INT NOT NULL,
IDPedido INT NOT NULL,
FechaUso DATETIME2(0) NOT NULL CONSTRAINT DF_CuponesUso_Fecha DEFAULT (SYSDATETIME()),
CONSTRAINT PK_CuponesUso PRIMARY KEY CLUSTERED (IDCuponUso),
CONSTRAINT FK_CuponesUso_Cupones FOREIGN KEY (IDCupon) REFERENCES dbo.Cupones (IDCupon),
CONSTRAINT FK_CuponesUso_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario),
CONSTRAINT FK_CuponesUso_Pedidos FOREIGN KEY (IDPedido) REFERENCES dbo.Pedidos (IDPedido)
);
GO

CREATE TABLE dbo.Pagos (
IDPago INT IDENTITY(1,1) NOT NULL,
IDPedido INT NOT NULL,
MetodoPago VARCHAR(30) NOT NULL,
TransaccionId VARCHAR(100) NOT NULL,
Monto DECIMAL(12,2) NOT NULL,
Estado VARCHAR(20) NOT NULL,
FechaPago DATETIME2(0) NOT NULL CONSTRAINT DF_Pagos_FechaPago DEFAULT (SYSDATETIME()),
CONSTRAINT PK_Pagos PRIMARY KEY CLUSTERED (IDPago),
CONSTRAINT CHK_Pagos_Estado CHECK (Estado IN ('APROBADO', 'RECHAZADO', 'PENDIENTE')),
CONSTRAINT FK_Pagos_Pedidos FOREIGN KEY (IDPedido) REFERENCES dbo.Pedidos (IDPedido)
);
GO

CREATE TABLE dbo.HistorialEstadosPedido (
IDHistorialEstado INT IDENTITY(1,1) NOT NULL,
IDPedido INT NOT NULL,
IDUsuario INT NOT NULL,
EstadoAnterior VARCHAR(30) NOT NULL,
EstadoNuevo VARCHAR(30) NOT NULL,
FechaHora DATETIME2(0) NOT NULL CONSTRAINT DF_HistorialEstados_Fecha DEFAULT (SYSDATETIME()),
CONSTRAINT PK_HistorialEstadosPedido PRIMARY KEY CLUSTERED (IDHistorialEstado),
CONSTRAINT FK_HistorialEstados_Pedidos FOREIGN KEY (IDPedido) REFERENCES dbo.Pedidos (IDPedido),
CONSTRAINT FK_HistorialEstados_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario)
);
GO

-- ============================================================================
-- MÓDULO 7: DEVOLUCIONES Y KARDEX (RF-03, RF-07)
-- ============================================================================

CREATE TABLE dbo.Devoluciones (
IDDevolucion INT IDENTITY(1,1) NOT NULL,
IDPedido INT NOT NULL,
IDUsuario INT NOT NULL,
Motivo NVARCHAR(250) NOT NULL,
Estado VARCHAR(20) NOT NULL CONSTRAINT DF_Devoluciones_Estado DEFAULT ('SOLICITADA'),
FechaSolicitud DATETIME2(0) NOT NULL CONSTRAINT DF_Devoluciones_Fecha DEFAULT (SYSDATETIME()),
CONSTRAINT PK_Devoluciones PRIMARY KEY CLUSTERED (IDDevolucion),
CONSTRAINT CHK_Devoluciones_Estado CHECK (Estado IN ('SOLICITADA', 'APROBADA', 'RECHAZADA')),
CONSTRAINT FK_Devoluciones_Pedidos FOREIGN KEY (IDPedido) REFERENCES dbo.Pedidos (IDPedido),
CONSTRAINT FK_Devoluciones_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario)
);
GO

CREATE TABLE dbo.DevolucionDetalle (
IDDevolucionDetalle INT IDENTITY(1,1) NOT NULL,
IDDevolucion INT NOT NULL,
IDVariante INT NOT NULL,
CantidadDevuelta INT NOT NULL,
CONSTRAINT PK_DevolucionDetalle PRIMARY KEY CLUSTERED (IDDevolucionDetalle),
CONSTRAINT CHK_DevolucionDetalle_Cantidad CHECK (CantidadDevuelta > 0),
CONSTRAINT FK_DevolucionDetalle_Devoluciones FOREIGN KEY (IDDevolucion) REFERENCES dbo.Devoluciones (IDDevolucion),
CONSTRAINT FK_DevolucionDetalle_Variantes FOREIGN KEY (IDVariante) REFERENCES dbo.Variantes (IDVariante)
);
GO

CREATE TABLE dbo.Kardex (
    IDKardex BIGINT IDENTITY(1,1) NOT NULL,
    IDVariante INT NOT NULL,
    TipoMovimiento VARCHAR(25) NOT NULL,
    Cantidad INT NOT NULL,
    StockAnterior INT NOT NULL,
    StockActual INT NOT NULL,
    IDPedido INT NULL,
    IDDevolucion INT NULL,
    IDUsuario INT NOT NULL,
    Motivo NVARCHAR(250) NOT NULL,
    FechaMovimiento DATETIME2(0) NOT NULL CONSTRAINT DF_Kardex_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Kardex PRIMARY KEY CLUSTERED (IDKardex),
    CONSTRAINT CHK_Kardex_TipoMovimiento CHECK (TipoMovimiento IN ('VENTA', 'AJUSTE_ENTRADA', 'AJUSTE_SALIDA', 'DEVOLUCION')),
    CONSTRAINT CHK_Kardex_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CHK_Kardex_Stock CHECK (StockAnterior >= 0 AND StockActual >= 0),
    CONSTRAINT FK_Kardex_Variantes FOREIGN KEY (IDVariante) REFERENCES dbo.Variantes (IDVariante),
    CONSTRAINT FK_Kardex_Pedidos FOREIGN KEY (IDPedido) REFERENCES dbo.Pedidos (IDPedido),
    CONSTRAINT FK_Kardex_Devoluciones FOREIGN KEY (IDDevolucion) REFERENCES dbo.Devoluciones (IDDevolucion),
    CONSTRAINT FK_Kardex_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario)
);
GO

-- ============================================================================
-- MÓDULO 8: BITÁCORA INMUTABLE (RF-09)
-- ============================================================================

CREATE TABLE dbo.Bitacora (
IDBitacora BIGINT IDENTITY(1,1) NOT NULL,
IDUsuario INT NULL,
FechaHora DATETIME2(0) NOT NULL CONSTRAINT DF_Bitacora_Fecha DEFAULT (SYSDATETIME()),
Modulo VARCHAR(50) NOT NULL,
Accion VARCHAR(20) NOT NULL,
IDRegistroAfectado VARCHAR(50) NOT NULL,
ValorAnterior NVARCHAR(MAX) NULL,
ValorNuevo NVARCHAR(MAX) NOT NULL,
CONSTRAINT PK_Bitacora PRIMARY KEY CLUSTERED (IDBitacora),
CONSTRAINT CHK_Bitacora_Accion CHECK (Accion IN ('CREAR', 'MODIFICAR', 'DESACTIVAR')),
CONSTRAINT FK_Bitacora_Usuarios FOREIGN KEY (IDUsuario) REFERENCES dbo.Usuarios (IDUsuario)
);
GO

-- ============================================================================
-- ÍNDICES PARA RENDIMIENTO
-- ============================================================================
CREATE NONCLUSTERED INDEX IX_Variantes_IDProducto ON dbo.Variantes (IDProducto);
CREATE NONCLUSTERED INDEX IX_VarianteAtributos_Variante ON dbo.VarianteAtributos (IDVariante, Activo);
CREATE NONCLUSTERED INDEX IX_VarianteImagenes_Variante_Orden ON dbo.VarianteImagenes (IDVariante, Activo, Orden) INCLUDE (UrlImagen, EsPrincipal);
CREATE NONCLUSTERED INDEX IX_Reservas_Variante_Estado ON dbo.ReservasExistencia (IDVariante, Estado, FechaExpiracion);
CREATE NONCLUSTERED INDEX IX_Carritos_Usuario_Estado ON dbo.Carritos (IDUsuario, Estado);
CREATE NONCLUSTERED INDEX IX_Pedidos_Usuario_Estado ON dbo.Pedidos (IDUsuario, EstadoPedido);
CREATE NONCLUSTERED INDEX IX_Kardex_Variante_Fecha ON dbo.Kardex (IDVariante, FechaMovimiento);
CREATE NONCLUSTERED INDEX IX_Bitacora_Modulo_Fecha ON dbo.Bitacora (Modulo, FechaHora);
GO