-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 10_vistas_dashboard_auditoria.sql
-- DESCRIPCIÓN: Vistas analíticas (VW_Modulo_Proceso), Trigger de inmutabilidad
--              y Stored Procedures de reportería ejecutiva y auditoría
--              (RF-08, RF-09).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- NOTA: Los reportes consideran solo pedidos pagados/completados, excluyen
--       cancelados y descuentan devoluciones aprobadas en Quetzales (GTQ).
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- 1. TRIGGER DE INMUTABILIDAD EN BITÁCORA (Criterio de aceptación RF-09)
-- "La bitácora no puede modificarse ni eliminarse."
-- ============================================================================
CREATE OR ALTER TRIGGER dbo.TR_Bitacora_InsteadOfUpdateDelete
ON dbo.Bitacora
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    ;THROW 50095, 'La bitácora de auditoría es estrictamente inmutable: no se permite modificar ni eliminar registros.', 1;
END;
GO

-- ============================================================================
-- 2. VISTAS ANALÍTICAS Y DE AUDITORÍA (Estándar VW_Modulo_Proceso)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 VW_Pedidos_LineasNetasCompletadas
-- Vista base que consolida cada línea de pedido pagado/completado (excluyendo
-- 'PENDIENTE' y 'CANCELADO') y descuenta exactamente las unidades e importes
-- de devoluciones con Estado = 'APROBADA' (RF-08).
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.VW_Pedidos_LineasNetasCompletadas
AS
SELECT
    p.IDPedido,
    p.IDUsuario AS IDCliente,
    p.EstadoPedido,
    p.FechaCreacion AS FechaPedido,
    CAST(p.FechaCreacion AS DATE) AS FechaDia,
    DATEPART(YEAR, p.FechaCreacion) AS Anio,
    DATEPART(ISO_WEEK, p.FechaCreacion) AS SemanaISO,
    DATEPART(MONTH, p.FechaCreacion) AS Mes,
    pd.IDPedidoDetalle,
    pd.IDVariante,
    v.SKU,
    v.NombreVariante,
    prod.IDProducto,
    prod.NombreProducto,
    cat.IDCategoria,
    cat.NombreCategoria,
    pd.Cantidad AS CantidadOriginal,
    ISNULL(dev.CantidadDevueltaAprobada, 0) AS CantidadDevuelta,
    CASE
        WHEN (pd.Cantidad - ISNULL(dev.CantidadDevueltaAprobada, 0)) < 0 THEN 0
        ELSE (pd.Cantidad - ISNULL(dev.CantidadDevueltaAprobada, 0))
    END AS CantidadNeta,
    pd.PrecioUnitarioCongelado,
    pd.DescuentoAplicado,
    pd.SubtotalLinea AS VentaBrutaLinea,
    CAST(
        ROUND(
            (pd.SubtotalLinea / CAST(pd.Cantidad AS DECIMAL(12,2)))
            * CAST(ISNULL(dev.CantidadDevueltaAprobada, 0) AS DECIMAL(12,2)),
            2
        )
        AS DECIMAL(12,2)
    ) AS MontoDevueltoLinea,
    CAST(
        CASE
            WHEN pd.SubtotalLinea - ROUND(
                (pd.SubtotalLinea / CAST(pd.Cantidad AS DECIMAL(12,2)))
                * CAST(ISNULL(dev.CantidadDevueltaAprobada, 0) AS DECIMAL(12,2)),
                2
            ) < 0.00 THEN 0.00
            ELSE pd.SubtotalLinea - ROUND(
                (pd.SubtotalLinea / CAST(pd.Cantidad AS DECIMAL(12,2)))
                * CAST(ISNULL(dev.CantidadDevueltaAprobada, 0) AS DECIMAL(12,2)),
                2
            )
        END
        AS DECIMAL(12,2)
    ) AS VentaNetaLinea
FROM dbo.Pedidos AS p
INNER JOIN dbo.PedidoDetalle AS pd ON pd.IDPedido = p.IDPedido
INNER JOIN dbo.Variantes AS v ON v.IDVariante = pd.IDVariante
INNER JOIN dbo.Productos AS prod ON prod.IDProducto = v.IDProducto
INNER JOIN dbo.Categorias AS cat ON cat.IDCategoria = prod.IDCategoria
OUTER APPLY (
    SELECT SUM(dd.CantidadDevuelta) AS CantidadDevueltaAprobada
    FROM dbo.DevolucionDetalle AS dd
    INNER JOIN dbo.Devoluciones AS d ON d.IDDevolucion = dd.IDDevolucion
    WHERE d.IDPedido = p.IDPedido
      AND dd.IDVariante = pd.IDVariante
      AND d.Estado = 'APROBADA'
) AS dev
WHERE p.EstadoPedido IN ('PAGADO', 'EN_PREPARACION', 'ENVIADO', 'ENTREGADO');
GO

-- ----------------------------------------------------------------------------
-- 2.2 VW_Dashboard_VentasPorPeriodo
-- Agrega las ventas diarias en Quetzales (GTQ), número de pedidos completados,
-- devoluciones descontadas, IVA neto y Ticket Promedio (RF-08).
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.VW_Dashboard_VentasPorPeriodo
AS
WITH ResumenPorDia AS (
    SELECT
        l.FechaDia,
        l.Anio,
        l.SemanaISO,
        l.Mes,
        COUNT(DISTINCT l.IDPedido) AS NumeroPedidos,
        SUM(l.CantidadOriginal) AS UnidadesBrutas,
        SUM(l.CantidadDevuelta) AS UnidadesDevueltas,
        SUM(l.CantidadNeta) AS UnidadesNetasVendidas,
        CAST(SUM(l.VentaBrutaLinea) AS DECIMAL(12,2)) AS VentaBrutaConDescuentoGTQ,
        CAST(SUM(l.MontoDevueltoLinea) AS DECIMAL(12,2)) AS MontoDevolucionesGTQ,
        CAST(SUM(l.VentaNetaLinea) AS DECIMAL(12,2)) AS VentaNetaGTQ
    FROM dbo.VW_Pedidos_LineasNetasCompletadas AS l
    GROUP BY
        l.FechaDia,
        l.Anio,
        l.SemanaISO,
        l.Mes
)
SELECT
    r.FechaDia,
    r.Anio,
    r.SemanaISO,
    r.Mes,
    r.NumeroPedidos,
    r.UnidadesBrutas,
    r.UnidadesDevueltas,
    r.UnidadesNetasVendidas,
    r.VentaBrutaConDescuentoGTQ,
    r.MontoDevolucionesGTQ,
    r.VentaNetaGTQ,
    iva.MontoSinIVA AS VentaNetaSinIVAGTQ,
    iva.MontoIVA AS MontoIVANetoGTQ,
    CAST(
        CASE
            WHEN r.NumeroPedidos > 0 THEN ROUND(r.VentaNetaGTQ / CAST(r.NumeroPedidos AS DECIMAL(12,2)), 2)
            ELSE 0.00
        END
        AS DECIMAL(12,2)
    ) AS TicketPromedioGTQ
FROM ResumenPorDia AS r
CROSS APPLY dbo.FU_Finanzas_DesgloseIVA(r.VentaNetaGTQ) AS iva;
GO

-- ----------------------------------------------------------------------------
-- 2.3 VW_Dashboard_VentasPorCategoria
-- Consolida las ventas netas en Quetzales (GTQ) y unidades por categoría,
-- excluyendo pedidos cancelados y descontando devoluciones aprobadas (RF-08).
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.VW_Dashboard_VentasPorCategoria
AS
SELECT
    c.IDCategoria,
    c.NombreCategoria,
    COUNT(DISTINCT l.IDPedido) AS NumeroPedidos,
    ISNULL(SUM(l.CantidadNeta), 0) AS UnidadesNetasVendidas,
    CAST(ISNULL(SUM(l.MontoDevueltoLinea), 0.00) AS DECIMAL(12,2)) AS MontoDevolucionesGTQ,
    CAST(ISNULL(SUM(l.VentaNetaLinea), 0.00) AS DECIMAL(12,2)) AS VentaNetaGTQ,
    iva.MontoSinIVA AS VentaNetaSinIVAGTQ,
    iva.MontoIVA AS MontoIVANetoGTQ
FROM dbo.Categorias AS c
LEFT JOIN dbo.VW_Pedidos_LineasNetasCompletadas AS l ON l.IDCategoria = c.IDCategoria
CROSS APPLY dbo.FU_Finanzas_DesgloseIVA(CAST(ISNULL(SUM(l.VentaNetaLinea), 0.00) AS DECIMAL(12,2))) AS iva
GROUP BY
    c.IDCategoria,
    c.NombreCategoria;
GO

-- ----------------------------------------------------------------------------
-- 2.4 VW_Reportes_TopProductos
-- Ranking de productos más vendidos (en unidades netas y en Quetzales netos),
-- descontando devoluciones aprobadas y excluyendo cancelados (RF-08).
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.VW_Reportes_TopProductos
AS
SELECT
    l.IDProducto,
    l.NombreProducto,
    l.IDCategoria,
    l.NombreCategoria,
    COUNT(DISTINCT l.IDPedido) AS NumeroPedidos,
    SUM(l.CantidadOriginal) AS UnidadesBrutasVendidas,
    SUM(l.CantidadDevuelta) AS UnidadesDevueltas,
    SUM(l.CantidadNeta) AS UnidadesNetasVendidas,
    CAST(SUM(l.VentaNetaLinea) AS DECIMAL(12,2)) AS IngresoNetoGTQ
FROM dbo.VW_Pedidos_LineasNetasCompletadas AS l
GROUP BY
    l.IDProducto,
    l.NombreProducto,
    l.IDCategoria,
    l.NombreCategoria;
GO

-- ----------------------------------------------------------------------------
-- 2.5 VW_Reportes_CarritosAbandonados
-- Identifica carritos con productos que no se han convertido en pedido,
-- calculando su tiempo de inactividad y valor potencial en GTQ (Sección 02, 03).
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.VW_Reportes_CarritosAbandonados
AS
SELECT
    c.IDCarrito,
    c.IDUsuario,
    u.NombreCompleto AS NombreCliente,
    u.Correo AS CorreoCliente,
    c.TokenInvitado,
    c.Estado AS EstadoCarrito,
    c.FechaCreacion,
    c.FechaActualizacion AS UltimaActividad,
    DATEDIFF(MINUTE, c.FechaActualizacion, SYSDATETIME()) AS MinutosInactividad,
    DATEDIFF(HOUR, c.FechaActualizacion, SYSDATETIME()) AS HorasInactividad,
    COUNT(cd.IDCarritoDetalle) AS TotalLineas,
    SUM(cd.Cantidad) AS TotalUnidades,
    CAST(SUM(CAST(cd.Cantidad AS DECIMAL(12,2)) * v.Precio) AS DECIMAL(12,2)) AS MontoEstimadoGTQ
FROM dbo.Carritos AS c
INNER JOIN dbo.CarritoDetalle AS cd ON cd.IDCarrito = c.IDCarrito
INNER JOIN dbo.Variantes AS v ON v.IDVariante = cd.IDVariante
LEFT JOIN dbo.Usuarios AS u ON u.IDUsuario = c.IDUsuario
WHERE c.Estado IN ('ACTIVO', 'ABANDONADO')
GROUP BY
    c.IDCarrito,
    c.IDUsuario,
    u.NombreCompleto,
    u.Correo,
    c.TokenInvitado,
    c.Estado,
    c.FechaCreacion,
    c.FechaActualizacion;
GO

-- ----------------------------------------------------------------------------
-- 2.6 VW_Pedidos_Historial (Estándar Grupo Pentandra - REQUIREMENTS.md L185)
-- Vista trazable de todos los cambios de estado de pedidos con datos del
-- cliente y del operador/usuario responsable.
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.VW_Pedidos_Historial
AS
SELECT
    h.IDHistorialEstado,
    h.IDPedido,
    p.EstadoPedido AS EstadoActualPedido,
    p.Total AS TotalPedidoGTQ,
    p.IDUsuario AS IDCliente,
    cli.NombreCompleto AS NombreCliente,
    h.IDUsuario AS IDUsuarioResponsable,
    resp.NombreCompleto AS NombreResponsable,
    r.NombreRol AS RolResponsable,
    h.EstadoAnterior,
    h.EstadoNuevo,
    h.FechaHora
FROM dbo.HistorialEstadosPedido AS h
INNER JOIN dbo.Pedidos AS p ON p.IDPedido = h.IDPedido
INNER JOIN dbo.Usuarios AS cli ON cli.IDUsuario = p.IDUsuario
INNER JOIN dbo.Usuarios AS resp ON resp.IDUsuario = h.IDUsuario
INNER JOIN dbo.Roles AS r ON r.IDRol = resp.IDRol;
GO

-- ----------------------------------------------------------------------------
-- 2.7 VW_Auditoria_Bitacora
-- Vista unificada de la Bitácora inmutable con información del usuario y rol
-- que ejecutó cada operación (RF-09).
-- ----------------------------------------------------------------------------
CREATE OR ALTER VIEW dbo.VW_Auditoria_Bitacora
AS
SELECT
    b.IDBitacora,
    b.FechaHora,
    b.Modulo,
    b.Accion,
    b.IDRegistroAfectado,
    b.IDUsuario,
    ISNULL(u.NombreCompleto, N'Sistema / Anónimo') AS NombreUsuario,
    u.Correo AS CorreoUsuario,
    r.NombreRol AS RolUsuario,
    b.ValorAnterior,
    b.ValorNuevo
FROM dbo.Bitacora AS b
LEFT JOIN dbo.Usuarios AS u ON u.IDUsuario = b.IDUsuario
LEFT JOIN dbo.Roles AS r ON r.IDRol = u.IDRol;
GO

-- ============================================================================
-- 3. STORED PROCEDURES DE DASHBOARD, REPORTES Y AUDITORÍA (RF-08, RF-09)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1 SP_Dashboard_ObtenerResumenKPIs
-- Devuelve las tarjetas de resumen ejecutivo (KPIs) para un rango de fechas:
--   - Venta Neta Total en GTQ (descontando devoluciones aprobadas y excluyendo cancelados)
--   - Número de pedidos completados
--   - Ticket Promedio en GTQ
--   - Unidades netas vendidas
--   - Monto total de devoluciones aprobadas
--   - Cantidad y monto estimado de carritos abandonados
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Dashboard_ObtenerResumenKPIs
    @FechaInicio DATETIME2(0) = NULL,
    @FechaFin DATETIME2(0) = NULL,
    @MinutosAbandono INT = 60
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, -30, SYSDATETIME());
    IF @FechaFin IS NULL SET @FechaFin = SYSDATETIME();
    IF @MinutosAbandono < 1 SET @MinutosAbandono = 60;

    DECLARE @NumeroPedidosCompletados INT = 0;
    DECLARE @UnidadesNetasVendidas INT = 0;
    DECLARE @VentaBrutaGTQ DECIMAL(12,2) = 0.00;
    DECLARE @MontoDevolucionesGTQ DECIMAL(12,2) = 0.00;
    DECLARE @VentaNetaGTQ DECIMAL(12,2) = 0.00;

    SELECT
        @NumeroPedidosCompletados = COUNT(DISTINCT l.IDPedido),
        @UnidadesNetasVendidas = ISNULL(SUM(l.CantidadNeta), 0),
        @VentaBrutaGTQ = CAST(ISNULL(SUM(l.VentaBrutaLinea), 0.00) AS DECIMAL(12,2)),
        @MontoDevolucionesGTQ = CAST(ISNULL(SUM(l.MontoDevueltoLinea), 0.00) AS DECIMAL(12,2)),
        @VentaNetaGTQ = CAST(ISNULL(SUM(l.VentaNetaLinea), 0.00) AS DECIMAL(12,2))
    FROM dbo.VW_Pedidos_LineasNetasCompletadas AS l
    WHERE l.FechaPedido >= @FechaInicio
      AND l.FechaPedido <= @FechaFin;

    DECLARE @PedidosCanceladosPeriodo INT = 0;
    SELECT @PedidosCanceladosPeriodo = COUNT(1)
    FROM dbo.Pedidos AS p
    WHERE p.EstadoPedido = 'CANCELADO'
      AND p.FechaCreacion >= @FechaInicio
      AND p.FechaCreacion <= @FechaFin;

    DECLARE @TotalCarritosAbandonados INT = 0;
    DECLARE @MontoCarritosAbandonadosGTQ DECIMAL(12,2) = 0.00;

    SELECT
        @TotalCarritosAbandonados = COUNT(1),
        @MontoCarritosAbandonadosGTQ = CAST(ISNULL(SUM(ca.MontoEstimadoGTQ), 0.00) AS DECIMAL(12,2))
    FROM dbo.VW_Reportes_CarritosAbandonados AS ca
    WHERE ca.MinutosInactividad >= @MinutosAbandono;

    SELECT
        @FechaInicio AS FechaInicio,
        @FechaFin AS FechaFin,
        @NumeroPedidosCompletados AS NumeroPedidosCompletados,
        @PedidosCanceladosPeriodo AS PedidosCancelados,
        @UnidadesNetasVendidas AS UnidadesNetasVendidas,
        @VentaBrutaGTQ AS VentaBrutaGTQ,
        @MontoDevolucionesGTQ AS MontoDevolucionesGTQ,
        @VentaNetaGTQ AS VentaNetaGTQ,
        iva.MontoSinIVA AS VentaNetaSinIVAGTQ,
        iva.MontoIVA AS MontoIVANetoGTQ,
        CAST(
            CASE
                WHEN @NumeroPedidosCompletados > 0
                    THEN ROUND(@VentaNetaGTQ / CAST(@NumeroPedidosCompletados AS DECIMAL(12,2)), 2)
                ELSE 0.00
            END
            AS DECIMAL(12,2)
        ) AS TicketPromedioGTQ,
        @TotalCarritosAbandonados AS TotalCarritosAbandonados,
        @MontoCarritosAbandonadosGTQ AS MontoCarritosAbandonadosGTQ
    FROM dbo.FU_Finanzas_DesgloseIVA(@VentaNetaGTQ) AS iva;
END;
GO

-- ----------------------------------------------------------------------------
-- 3.2 SP_Dashboard_VentasPorPeriodo
-- Devuelve las ventas en Quetzales (GTQ), número de pedidos y ticket promedio
-- agrupados por 'DIA', 'SEMANA' o 'MES' para las gráficas del dashboard (RF-08).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Dashboard_VentasPorPeriodo
    @Agrupacion VARCHAR(15) = 'DIA', -- 'DIA' | 'SEMANA' | 'MES'
    @FechaInicio DATETIME2(0) = NULL,
    @FechaFin DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Agrupacion = UPPER(LTRIM(RTRIM(ISNULL(@Agrupacion, 'DIA'))));
    IF @Agrupacion NOT IN ('DIA', 'SEMANA', 'MES')
        SET @Agrupacion = 'DIA';

    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, -30, SYSDATETIME());
    IF @FechaFin IS NULL SET @FechaFin = SYSDATETIME();

    IF @Agrupacion = 'DIA'
    BEGIN
        SELECT
            CONVERT(VARCHAR(10), l.FechaDia, 23) AS EtiquetaPeriodo,
            l.FechaDia AS FechaReferencia,
            COUNT(DISTINCT l.IDPedido) AS NumeroPedidos,
            SUM(l.CantidadNeta) AS UnidadesNetasVendidas,
            CAST(SUM(l.MontoDevueltoLinea) AS DECIMAL(12,2)) AS MontoDevolucionesGTQ,
            CAST(SUM(l.VentaNetaLinea) AS DECIMAL(12,2)) AS VentaNetaGTQ,
            CAST(
                CASE
                    WHEN COUNT(DISTINCT l.IDPedido) > 0
                        THEN ROUND(SUM(l.VentaNetaLinea) / CAST(COUNT(DISTINCT l.IDPedido) AS DECIMAL(12,2)), 2)
                    ELSE 0.00
                END
                AS DECIMAL(12,2)
            ) AS TicketPromedioGTQ
        FROM dbo.VW_Pedidos_LineasNetasCompletadas AS l
        WHERE l.FechaPedido >= @FechaInicio
          AND l.FechaPedido <= @FechaFin
        GROUP BY l.FechaDia
        ORDER BY l.FechaDia ASC;
    END
    ELSE IF @Agrupacion = 'SEMANA'
    BEGIN
        SELECT
            CONCAT(l.Anio, '-S', RIGHT('00' + CAST(l.SemanaISO AS VARCHAR(2)), 2)) AS EtiquetaPeriodo,
            MIN(l.FechaDia) AS FechaReferencia,
            COUNT(DISTINCT l.IDPedido) AS NumeroPedidos,
            SUM(l.CantidadNeta) AS UnidadesNetasVendidas,
            CAST(SUM(l.MontoDevueltoLinea) AS DECIMAL(12,2)) AS MontoDevolucionesGTQ,
            CAST(SUM(l.VentaNetaLinea) AS DECIMAL(12,2)) AS VentaNetaGTQ,
            CAST(
                CASE
                    WHEN COUNT(DISTINCT l.IDPedido) > 0
                        THEN ROUND(SUM(l.VentaNetaLinea) / CAST(COUNT(DISTINCT l.IDPedido) AS DECIMAL(12,2)), 2)
                    ELSE 0.00
                END
                AS DECIMAL(12,2)
            ) AS TicketPromedioGTQ
        FROM dbo.VW_Pedidos_LineasNetasCompletadas AS l
        WHERE l.FechaPedido >= @FechaInicio
          AND l.FechaPedido <= @FechaFin
        GROUP BY l.Anio, l.SemanaISO
        ORDER BY l.Anio ASC, l.SemanaISO ASC;
    END
    ELSE -- 'MES'
    BEGIN
        SELECT
            CONCAT(l.Anio, '-', RIGHT('00' + CAST(l.Mes AS VARCHAR(2)), 2)) AS EtiquetaPeriodo,
            MIN(l.FechaDia) AS FechaReferencia,
            COUNT(DISTINCT l.IDPedido) AS NumeroPedidos,
            SUM(l.CantidadNeta) AS UnidadesNetasVendidas,
            CAST(SUM(l.MontoDevueltoLinea) AS DECIMAL(12,2)) AS MontoDevolucionesGTQ,
            CAST(SUM(l.VentaNetaLinea) AS DECIMAL(12,2)) AS VentaNetaGTQ,
            CAST(
                CASE
                    WHEN COUNT(DISTINCT l.IDPedido) > 0
                        THEN ROUND(SUM(l.VentaNetaLinea) / CAST(COUNT(DISTINCT l.IDPedido) AS DECIMAL(12,2)), 2)
                    ELSE 0.00
                END
                AS DECIMAL(12,2)
            ) AS TicketPromedioGTQ
        FROM dbo.VW_Pedidos_LineasNetasCompletadas AS l
        WHERE l.FechaPedido >= @FechaInicio
          AND l.FechaPedido <= @FechaFin
        GROUP BY l.Anio, l.Mes
        ORDER BY l.Anio ASC, l.Mes ASC;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- 3.3 SP_Dashboard_VentasPorCategoria
-- Devuelve las ventas netas por categoría en un rango de fechas, incluyendo el
-- porcentaje de participación sobre el total vendido (RF-08).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Dashboard_VentasPorCategoria
    @FechaInicio DATETIME2(0) = NULL,
    @FechaFin DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, -90, SYSDATETIME());
    IF @FechaFin IS NULL SET @FechaFin = SYSDATETIME();

    WITH VentasCat AS (
        SELECT
            c.IDCategoria,
            c.NombreCategoria,
            COUNT(DISTINCT l.IDPedido) AS NumeroPedidos,
            ISNULL(SUM(l.CantidadNeta), 0) AS UnidadesNetasVendidas,
            CAST(ISNULL(SUM(l.MontoDevueltoLinea), 0.00) AS DECIMAL(12,2)) AS MontoDevolucionesGTQ,
            CAST(ISNULL(SUM(l.VentaNetaLinea), 0.00) AS DECIMAL(12,2)) AS VentaNetaGTQ
        FROM dbo.Categorias AS c
        LEFT JOIN dbo.VW_Pedidos_LineasNetasCompletadas AS l
            ON l.IDCategoria = c.IDCategoria
           AND l.FechaPedido >= @FechaInicio
           AND l.FechaPedido <= @FechaFin
        GROUP BY
            c.IDCategoria,
            c.NombreCategoria
    ),
    TotalGeneral AS (
        SELECT SUM(VentaNetaGTQ) AS GranTotalGTQ
        FROM VentasCat
    )
    SELECT
        vc.IDCategoria,
        vc.NombreCategoria,
        vc.NumeroPedidos,
        vc.UnidadesNetasVendidas,
        vc.MontoDevolucionesGTQ,
        vc.VentaNetaGTQ,
        CAST(
            CASE
                WHEN ISNULL(tg.GranTotalGTQ, 0.00) > 0.00
                    THEN ROUND((vc.VentaNetaGTQ / tg.GranTotalGTQ) * 100.00, 2)
                ELSE 0.00
            END
            AS DECIMAL(12,2)
        ) AS PorcentajeParticipacion
    FROM VentasCat AS vc
    CROSS JOIN TotalGeneral AS tg
    ORDER BY vc.VentaNetaGTQ DESC, vc.NombreCategoria ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 3.4 SP_Dashboard_TopProductosMasVendidos
-- Devuelve los 10 productos más vendidos de un periodo (RF-08), excluyendo
-- pedidos cancelados y descontando devoluciones aprobadas.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Dashboard_TopProductosMasVendidos
    @FechaInicio DATETIME2(0) = NULL,
    @FechaFin DATETIME2(0) = NULL,
    @TopN INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaInicio IS NULL SET @FechaInicio = DATEADD(DAY, -90, SYSDATETIME());
    IF @FechaFin IS NULL SET @FechaFin = SYSDATETIME();
    IF @TopN < 1 OR @TopN > 50 SET @TopN = 10;

    SELECT TOP (@TopN)
        l.IDProducto,
        l.NombreProducto,
        l.IDCategoria,
        l.NombreCategoria,
        COUNT(DISTINCT l.IDPedido) AS NumeroPedidos,
        SUM(l.CantidadOriginal) AS UnidadesBrutasVendidas,
        SUM(l.CantidadDevuelta) AS UnidadesDevueltas,
        SUM(l.CantidadNeta) AS UnidadesNetasVendidas,
        CAST(SUM(l.VentaNetaLinea) AS DECIMAL(12,2)) AS IngresoNetoGTQ
    FROM dbo.VW_Pedidos_LineasNetasCompletadas AS l
    WHERE l.FechaPedido >= @FechaInicio
      AND l.FechaPedido <= @FechaFin
    GROUP BY
        l.IDProducto,
        l.NombreProducto,
        l.IDCategoria,
        l.NombreCategoria
    HAVING SUM(l.CantidadNeta) > 0
    ORDER BY
        SUM(l.CantidadNeta) DESC,
        SUM(l.VentaNetaLinea) DESC;
END;
GO

-- ----------------------------------------------------------------------------
-- 3.5 SP_Dashboard_ListarCarritosAbandonados
-- Lista de forma paginada los carritos con productos sin actividad durante un
-- periodo configurable (@MinutosInactividad, por defecto 60 minutos).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Dashboard_ListarCarritosAbandonados
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 15,
    @MinutosInactividad INT = 60
AS
BEGIN
    SET NOCOUNT ON;

    IF @NumeroPagina < 1 SET @NumeroPagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 15;
    IF @MinutosInactividad < 0 SET @MinutosInactividad = 0;

    DECLARE @Offset INT = (@NumeroPagina - 1) * @TamanoPagina;

    -- Recordset 1: Total de carritos abandonados y monto potencial acumulado
    SELECT
        COUNT(1) AS TotalRegistros,
        CAST(ISNULL(SUM(ca.MontoEstimadoGTQ), 0.00) AS DECIMAL(12,2)) AS MontoPotencialTotalGTQ
    FROM dbo.VW_Reportes_CarritosAbandonados AS ca
    WHERE ca.MinutosInactividad >= @MinutosInactividad;

    -- Recordset 2: Página de carritos abandonados
    SELECT
        ca.IDCarrito,
        ca.IDUsuario,
        ca.NombreCliente,
        ca.CorreoCliente,
        ca.TokenInvitado,
        ca.EstadoCarrito,
        ca.FechaCreacion,
        ca.UltimaActividad,
        ca.MinutosInactividad,
        ca.HorasInactividad,
        ca.TotalLineas,
        ca.TotalUnidades,
        ca.MontoEstimadoGTQ
    FROM dbo.VW_Reportes_CarritosAbandonados AS ca
    WHERE ca.MinutosInactividad >= @MinutosInactividad
    ORDER BY ca.UltimaActividad DESC, ca.IDCarrito DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

-- ----------------------------------------------------------------------------
-- 3.6 SP_Auditoria_ConsultarBitacora
-- Consulta paginada y filtrada de la Bitácora inmutable para Administradores,
-- con filtro por módulo, acción, usuario y rango de fechas (RF-09).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Auditoria_ConsultarBitacora
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 25,
    @Modulo VARCHAR(50) = NULL,
    @Accion VARCHAR(20) = NULL,
    @IDUsuario INT = NULL,
    @FechaInicio DATETIME2(0) = NULL,
    @FechaFin DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @NumeroPagina < 1 SET @NumeroPagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 25;

    DECLARE @Offset INT = (@NumeroPagina - 1) * @TamanoPagina;
    SET @Modulo = NULLIF(LTRIM(RTRIM(UPPER(@Modulo))), '');
    SET @Accion = NULLIF(LTRIM(RTRIM(UPPER(@Accion))), '');

    -- Recordset 1: Total de registros para paginación
    SELECT COUNT(1) AS TotalRegistros
    FROM dbo.VW_Auditoria_Bitacora AS b
    WHERE (@Modulo IS NULL OR b.Modulo = @Modulo)
      AND (@Accion IS NULL OR b.Accion = @Accion)
      AND (@IDUsuario IS NULL OR b.IDUsuario = @IDUsuario)
      AND (@FechaInicio IS NULL OR b.FechaHora >= @FechaInicio)
      AND (@FechaFin IS NULL OR b.FechaHora <= @FechaFin);

    -- Recordset 2: Página de eventos de Bitácora
    SELECT
        b.IDBitacora,
        b.FechaHora,
        b.Modulo,
        b.Accion,
        b.IDRegistroAfectado,
        b.IDUsuario,
        b.NombreUsuario,
        b.CorreoUsuario,
        b.RolUsuario,
        b.ValorAnterior,
        b.ValorNuevo
    FROM dbo.VW_Auditoria_Bitacora AS b
    WHERE (@Modulo IS NULL OR b.Modulo = @Modulo)
      AND (@Accion IS NULL OR b.Accion = @Accion)
      AND (@IDUsuario IS NULL OR b.IDUsuario = @IDUsuario)
      AND (@FechaInicio IS NULL OR b.FechaHora >= @FechaInicio)
      AND (@FechaFin IS NULL OR b.FechaHora <= @FechaFin)
    ORDER BY b.FechaHora DESC, b.IDBitacora DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO
