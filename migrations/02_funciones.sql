-- ============================================================================
-- PROYECTO: ShopCart
-- ARCHIVO: 02_funciones.sql
-- DESCRIPCIÓN: Funciones Definidas por el Usuario (UDFs) bajo el estándar
--              oficial de nomenclatura FU_Modulo_Proceso.
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- NOTA: Precios en Quetzales (GTQ) con IVA del 12% incluido. Tipos DECIMAL(12,2).
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- 1. FUNCIÓN ESCALAR: dbo.FU_Inventario_StockDisponible
-- MÓDULO: Inventario (RF-03, RF-04, RF-06)
-- PROPÓSITO: Calcula la existencia disponible real de una variante:
--            StockFisico - SUM(Reservas con Estado = 'ACTIVA' y vigentes).
--            Si la variante no existe, está inactiva o el cálculo resulta
--            menor a cero, retorna 0 para prevenir sobreventa.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.FU_Inventario_StockDisponible
(
    @IDVariante INT
)
RETURNS INT
AS
BEGIN
    DECLARE @StockFisico INT = 0;
    DECLARE @StockReservado INT = 0;
    DECLARE @StockDisponible INT = 0;
    DECLARE @VarianteActiva BIT = 0;

    SELECT
        @StockFisico = v.StockFisico,
        @VarianteActiva = CASE WHEN v.Activo = 1 AND p.Activo = 1 AND c.Activo = 1 THEN 1 ELSE 0 END
    FROM dbo.Variantes AS v
    INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
    INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
    WHERE v.IDVariante = @IDVariante;

    IF @VarianteActiva = 0
        RETURN 0;

    SELECT
        @StockReservado = ISNULL(SUM(r.Cantidad), 0)
    FROM dbo.ReservasExistencia AS r
    WHERE r.IDVariante = @IDVariante
      AND r.Estado = 'ACTIVA'
      AND r.FechaExpiracion > SYSDATETIME();

    SET @StockDisponible = @StockFisico - @StockReservado;

    IF @StockDisponible < 0
        SET @StockDisponible = 0;

    RETURN @StockDisponible;
END;
GO

-- ============================================================================
-- 2. FUNCIÓN TIPO TABLA (INLINE): dbo.FU_Inventario_DetalleDisponibilidad
-- MÓDULO: Inventario (RF-03, RF-04, RF-06)
-- PROPÓSITO: Versión tipo tabla (Inline TVF) optimizada para usarse con
--            CROSS APPLY en listados masivos de catálogo y carrito sin
--            penalización de ejecución fila por fila (< 1 segundo).
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.FU_Inventario_DetalleDisponibilidad
(
    @IDVariante INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        v.IDVariante,
        v.StockFisico,
        ISNULL(res.StockReservado, 0) AS StockReservado,
        CASE
            WHEN v.Activo = 0 OR p.Activo = 0 OR c.Activo = 0 THEN 0
            WHEN (v.StockFisico - ISNULL(res.StockReservado, 0)) < 0 THEN 0
            ELSE (v.StockFisico - ISNULL(res.StockReservado, 0))
        END AS StockDisponible
    FROM dbo.Variantes AS v
    INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
    INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
    OUTER APPLY (
        SELECT SUM(r.Cantidad) AS StockReservado
        FROM dbo.ReservasExistencia AS r
        WHERE r.IDVariante = v.IDVariante
          AND r.Estado = 'ACTIVA'
          AND r.FechaExpiracion > SYSDATETIME()
    ) AS res
    WHERE v.IDVariante = @IDVariante
);
GO

-- ============================================================================
-- 3. FUNCIÓN TIPO TABLA (INLINE): dbo.FU_Finanzas_DesgloseIVA
-- MÓDULO: Finanzas / Pedidos / Carrito (Sección 02, RF-04, RF-06)
-- PROPÓSITO: Recibe un monto en Quetzales (GTQ) que ya incluye el 12% de IVA
--            y devuelve el desglose exacto en DECIMAL(12,2) sin errores de
--            redondeo (MontoSinIVA + MontoIVA = MontoConIVA).
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.FU_Finanzas_DesgloseIVA
(
    @MontoConIVA DECIMAL(12,2)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        CAST(ISNULL(@MontoConIVA, 0.00) AS DECIMAL(12,2)) AS MontoConIVA,
        CAST(ROUND(ISNULL(@MontoConIVA, 0.00) / 1.12, 2) AS DECIMAL(12,2)) AS MontoSinIVA,
        CAST(
            ISNULL(@MontoConIVA, 0.00) - CAST(ROUND(ISNULL(@MontoConIVA, 0.00) / 1.12, 2) AS DECIMAL(12,2))
            AS DECIMAL(12,2)
        ) AS MontoIVA
);
GO

-- ============================================================================
-- 4. FUNCIÓN TIPO TABLA (INLINE): dbo.FU_Catalogo_PrecioVigente
-- MÓDULO: Catálogo (RF-02, RF-04, RF-06 - Estándar Grupo Pentandra)
-- PROPÓSITO: Obtiene el precio vigente actual de una variante en GTQ, su
--            desglose de IVA (12%), disponibilidad para la venta y la fecha
--            del último cambio registrado en HistorialPrecios.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.FU_Catalogo_PrecioVigente
(
    @IDVariante INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        v.IDVariante,
        v.IDProducto,
        p.IDCategoria,
        v.SKU,
        v.NombreVariante,
        v.Precio AS PrecioVigente,
        iva.MontoSinIVA AS PrecioSinIVA,
        iva.MontoIVA AS MontoIVAUnitario,
        v.Activo AS VarianteActiva,
        p.Activo AS ProductoActivo,
        c.Activo AS CategoriaActiva,
        CAST(CASE WHEN v.Activo = 1 AND p.Activo = 1 AND c.Activo = 1 THEN 1 ELSE 0 END AS BIT) AS DisponibleVenta,
        hp.FechaUltimaModificacionPrecio
    FROM dbo.Variantes AS v
    INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
    INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
    CROSS APPLY dbo.FU_Finanzas_DesgloseIVA(v.Precio) AS iva
    OUTER APPLY (
        SELECT MAX(h.FechaModificacion) AS FechaUltimaModificacionPrecio
        FROM dbo.HistorialPrecios AS h
        WHERE h.IDVariante = v.IDVariante
    ) AS hp
    WHERE v.IDVariante = @IDVariante
);
GO

-- ============================================================================
-- 5. FUNCIÓN TIPO TABLA (INLINE): dbo.FU_Cupones_CalculoDescuento
-- MÓDULO: Cupones y Promociones (RF-05 - Estándar Grupo Pentandra)
-- PROPÓSITO: Valida todas las reglas de negocio de un cupón (existencia,
--            estado activo, vigencia de fechas, límite global de usos,
--            límite de usos por cliente, monto mínimo de compra y elegibilidad
--            por categoría) y calcula el descuento exacto en DECIMAL(12,2)
--            garantizando que jamás exceda el subtotal ni deje el total < 0.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.FU_Cupones_CalculoDescuento
(
    @Codigo VARCHAR(30),
    @IDUsuario INT = NULL,
    @SubtotalTotalCarrito DECIMAL(12,2),
    @SubtotalCategoriaElegible DECIMAL(12,2) = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH DatosCupon AS (
        SELECT
            c.IDCupon,
            c.Codigo,
            c.TipoDescuento,
            c.ValorDescuento,
            c.MontoMinimoCompra,
            c.IDCategoria,
            c.FechaInicio,
            c.FechaFin,
            c.LimiteUsosTotal,
            c.UsosActuales,
            c.LimiteUsosPorCliente,
            c.Activo,
            ISNULL((
                SELECT COUNT(1)
                FROM dbo.CuponesUso AS cu
                WHERE cu.IDCupon = c.IDCupon
                  AND (@IDUsuario IS NOT NULL AND cu.IDUsuario = @IDUsuario)
            ), 0) AS UsosCliente,
            CASE
                WHEN c.IDCategoria IS NULL THEN ISNULL(@SubtotalTotalCarrito, 0.00)
                ELSE ISNULL(@SubtotalCategoriaElegible, 0.00)
            END AS BaseCalculo
        FROM dbo.Cupones AS c
        WHERE c.Codigo = @Codigo
    ),
    Evaluacion AS (
        SELECT
            dc.*,
            CASE
                WHEN dc.Activo = 0 THEN 0
                WHEN SYSDATETIME() < dc.FechaInicio THEN 0
                WHEN SYSDATETIME() > dc.FechaFin THEN 0
                WHEN dc.UsosActuales >= dc.LimiteUsosTotal THEN 0
                WHEN @IDUsuario IS NOT NULL AND dc.UsosCliente >= dc.LimiteUsosPorCliente THEN 0
                WHEN ISNULL(@SubtotalTotalCarrito, 0.00) < dc.MontoMinimoCompra THEN 0
                WHEN dc.IDCategoria IS NOT NULL AND dc.BaseCalculo <= 0.00 THEN 0
                ELSE 1
            END AS EsValido,
            CASE
                WHEN dc.Activo = 0 THEN N'El cupón se encuentra inactivo.'
                WHEN SYSDATETIME() < dc.FechaInicio THEN N'El cupón aún no ha iniciado su vigencia.'
                WHEN SYSDATETIME() > dc.FechaFin THEN N'El cupón ha vencido.'
                WHEN dc.UsosActuales >= dc.LimiteUsosTotal THEN N'El cupón ha alcanzado su límite máximo de usos.'
                WHEN @IDUsuario IS NOT NULL AND dc.UsosCliente >= dc.LimiteUsosPorCliente THEN N'Has alcanzado el límite de usos permitidos para este cupón.'
                WHEN ISNULL(@SubtotalTotalCarrito, 0.00) < dc.MontoMinimoCompra THEN N'El subtotal del carrito no alcanza el monto mínimo de compra requerido por el cupón.'
                WHEN dc.IDCategoria IS NOT NULL AND dc.BaseCalculo <= 0.00 THEN N'El carrito no contiene productos de la categoría requerida por el cupón.'
                ELSE N'Cupón válido y aplicado correctamente.'
            END AS MensajeValidacion,
            CAST(
                CASE
                    WHEN dc.TipoDescuento = 'PORCENTAJE'
                        THEN ROUND(dc.BaseCalculo * (dc.ValorDescuento / 100.00), 2)
                    WHEN dc.TipoDescuento = 'MONTO_FIJO'
                        THEN dc.ValorDescuento
                    ELSE 0.00
                END
                AS DECIMAL(12,2)
            ) AS DescuentoBruto
        FROM DatosCupon AS dc
    )
    SELECT
        e.IDCupon,
        e.Codigo,
        e.TipoDescuento,
        e.ValorDescuento,
        e.MontoMinimoCompra,
        e.IDCategoria,
        CAST(e.EsValido AS BIT) AS EsValido,
        e.MensajeValidacion,
        CAST(
            CASE
                WHEN e.EsValido = 0 THEN 0.00
                WHEN e.DescuentoBruto > e.BaseCalculo THEN e.BaseCalculo
                WHEN e.DescuentoBruto > ISNULL(@SubtotalTotalCarrito, 0.00) THEN ISNULL(@SubtotalTotalCarrito, 0.00)
                ELSE e.DescuentoBruto
            END
            AS DECIMAL(12,2)
        ) AS MontoDescuento,
        CAST(
            ISNULL(@SubtotalTotalCarrito, 0.00) -
            CASE
                WHEN e.EsValido = 0 THEN 0.00
                WHEN e.DescuentoBruto > e.BaseCalculo THEN e.BaseCalculo
                WHEN e.DescuentoBruto > ISNULL(@SubtotalTotalCarrito, 0.00) THEN ISNULL(@SubtotalTotalCarrito, 0.00)
                ELSE e.DescuentoBruto
            END
            AS DECIMAL(12,2)
        ) AS TotalConDescuento
    FROM Evaluacion AS e

    UNION ALL

    SELECT
        NULL AS IDCupon,
        @Codigo AS Codigo,
        NULL AS TipoDescuento,
        CAST(0.00 AS DECIMAL(12,2)) AS ValorDescuento,
        CAST(0.00 AS DECIMAL(12,2)) AS MontoMinimoCompra,
        NULL AS IDCategoria,
        CAST(0 AS BIT) AS EsValido,
        N'El código de cupón ingresado no existe.' AS MensajeValidacion,
        CAST(0.00 AS DECIMAL(12,2)) AS MontoDescuento,
        CAST(ISNULL(@SubtotalTotalCarrito, 0.00) AS DECIMAL(12,2)) AS TotalConDescuento
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Cupones WHERE Codigo = @Codigo)
);
GO

-- ============================================================================
-- 6. FUNCIÓN ESCALAR: dbo.FU_Pedidos_ValidarTransicionEstado
-- MÓDULO: Pedidos (RF-07)
-- PROPÓSITO: Evalúa si la transición entre @EstadoActual y @EstadoNuevo es
--            válida según la máquina de estados del ciclo de vida del pedido:
--            - PENDIENTE      -> PAGADO | CANCELADO
--            - PAGADO         -> EN_PREPARACION | CANCELADO
--            - EN_PREPARACION -> ENVIADO | CANCELADO (cancelable antes de despacho)
--            - ENVIADO        -> ENTREGADO
--            - ENTREGADO / CANCELADO -> Estados finales (sin transiciones)
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.FU_Pedidos_ValidarTransicionEstado
(
    @EstadoActual VARCHAR(30),
    @EstadoNuevo VARCHAR(30)
)
RETURNS BIT
AS
BEGIN
    DECLARE @EsValida BIT = 0;

    IF @EstadoActual = 'PENDIENTE' AND @EstadoNuevo IN ('PAGADO', 'CANCELADO')
        SET @EsValida = 1;
    ELSE IF @EstadoActual = 'PAGADO' AND @EstadoNuevo IN ('EN_PREPARACION', 'CANCELADO')
        SET @EsValida = 1;
    ELSE IF @EstadoActual = 'EN_PREPARACION' AND @EstadoNuevo IN ('ENVIADO', 'CANCELADO')
        SET @EsValida = 1;
    ELSE IF @EstadoActual = 'ENVIADO' AND @EstadoNuevo = 'ENTREGADO'
        SET @EsValida = 1;

    RETURN @EsValida;
END;
GO

-- ============================================================================
-- 7. FUNCIÓN TIPO TABLA (INLINE): dbo.FU_Pedidos_SaldoDevolucionLinea
-- MÓDULO: Devoluciones y Pedidos (RF-07)
-- PROPÓSITO: Calcula para cada línea de un pedido la cantidad comprada,
--            la cantidad acumulada en devoluciones activas ('SOLICITADA' o
--            'APROBADA') y la cantidad restante disponible para devolver,
--            evitando que se devuelva más de lo vendido por línea.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.FU_Pedidos_SaldoDevolucionLinea
(
    @IDPedido INT,
    @IDVariante INT = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        pd.IDPedido,
        pd.IDPedidoDetalle,
        pd.IDVariante,
        pd.Cantidad AS CantidadComprada,
        pd.PrecioUnitarioCongelado,
        pd.DescuentoAplicado,
        pd.SubtotalLinea,
        ISNULL(dev.CantidadDevueltaAcumulada, 0) AS CantidadYaDevuelta,
        CASE
            WHEN (pd.Cantidad - ISNULL(dev.CantidadDevueltaAcumulada, 0)) < 0 THEN 0
            ELSE (pd.Cantidad - ISNULL(dev.CantidadDevueltaAcumulada, 0))
        END AS CantidadDisponibleDevolver
    FROM dbo.PedidoDetalle AS pd
    OUTER APPLY (
        SELECT SUM(dd.CantidadDevuelta) AS CantidadDevueltaAcumulada
        FROM dbo.DevolucionDetalle AS dd
        INNER JOIN dbo.Devoluciones AS d ON d.IDDevolucion = dd.IDDevolucion
        WHERE d.IDPedido = pd.IDPedido
          AND dd.IDVariante = pd.IDVariante
          AND d.Estado IN ('SOLICITADA', 'APROBADA')
    ) AS dev
    WHERE pd.IDPedido = @IDPedido
      AND (@IDVariante IS NULL OR pd.IDVariante = @IDVariante)
);
GO

-- ============================================================================
-- ALIAS DE COMPATIBILIDAD CON PREFIJO FN_ (AGENTS.md)
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.FN_Inventario_StockDisponible
(
    @IDVariante INT
)
RETURNS INT
AS
BEGIN
    RETURN dbo.FU_Inventario_StockDisponible(@IDVariante);
END;
GO

CREATE OR ALTER FUNCTION dbo.FN_Inventario_DetalleDisponibilidad
(
    @IDVariante INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        IDVariante,
        StockFisico,
        StockReservado,
        StockDisponible
    FROM dbo.FU_Inventario_DetalleDisponibilidad(@IDVariante)
);
GO

CREATE OR ALTER FUNCTION dbo.FN_Finanzas_DesgloseIVA
(
    @MontoConIVA DECIMAL(12,2)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        CAST(ISNULL(@MontoConIVA, 0.00) AS DECIMAL(12,2)) AS MontoConIVA,
        CAST(ROUND(ISNULL(@MontoConIVA, 0.00) / 1.12, 2) AS DECIMAL(12,2)) AS MontoSinIVA,
        CAST(
            ISNULL(@MontoConIVA, 0.00) - CAST(ROUND(ISNULL(@MontoConIVA, 0.00) / 1.12, 2) AS DECIMAL(12,2))
            AS DECIMAL(12,2)
        ) AS MontoIVA
);
GO

CREATE OR ALTER FUNCTION dbo.FN_Catalogo_PrecioVigente
(
    @IDVariante INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        IDVariante,
        IDProducto,
        IDCategoria,
        SKU,
        NombreVariante,
        PrecioVigente,
        PrecioSinIVA,
        MontoIVAUnitario,
        VarianteActiva,
        ProductoActivo,
        CategoriaActiva,
        DisponibleVenta,
        FechaUltimaModificacionPrecio
    FROM dbo.FU_Catalogo_PrecioVigente(@IDVariante)
);
GO

CREATE OR ALTER FUNCTION dbo.FN_Cupones_CalculoDescuento
(
    @Codigo VARCHAR(30),
    @IDUsuario INT = NULL,
    @SubtotalTotalCarrito DECIMAL(12,2),
    @SubtotalCategoriaElegible DECIMAL(12,2) = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        IDCupon,
        Codigo,
        TipoDescuento,
        ValorDescuento,
        MontoMinimoCompra,
        IDCategoria,
        EsValido,
        MensajeValidacion,
        MontoDescuento,
        TotalConDescuento
    FROM dbo.FU_Cupones_CalculoDescuento(@Codigo, @IDUsuario, @SubtotalTotalCarrito, @SubtotalCategoriaElegible)
);
GO

CREATE OR ALTER FUNCTION dbo.FN_Pedidos_ValidarTransicionEstado
(
    @EstadoActual VARCHAR(30),
    @EstadoNuevo VARCHAR(30)
)
RETURNS BIT
AS
BEGIN
    RETURN dbo.FU_Pedidos_ValidarTransicionEstado(@EstadoActual, @EstadoNuevo);
END;
GO

CREATE OR ALTER FUNCTION dbo.FN_Pedidos_SaldoDevolucionLinea
(
    @IDPedido INT,
    @IDVariante INT = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        IDPedido,
        IDPedidoDetalle,
        IDVariante,
        CantidadComprada,
        PrecioUnitarioCongelado,
        DescuentoAplicado,
        SubtotalLinea,
        CantidadYaDevuelta,
        CantidadDisponibleDevolver
    FROM dbo.FU_Pedidos_SaldoDevolucionLinea(@IDPedido, @IDVariante)
);
GO
