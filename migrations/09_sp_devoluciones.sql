-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 09_sp_devoluciones.sql
-- DESCRIPCIÓN: Procedimientos almacenados para la gestión de Devoluciones
--              totales o parciales por línea de pedido, validación de topes
--              comprados y reintegro transaccional al Kardex (RF-03, RF-07, RF-09).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 7: DEVOLUCIONES Y REINTEGRO DE INVENTARIO (RF-03, RF-07, RF-09)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SP_Devoluciones_ObtenerDetalle
-- Devuelve 2 recordsets con toda la información de una devolución:
--   1) Encabezado de la devolución, pedido asociado, cliente y monto total
--      estimado de reintegro (calculado con el precio neto congelado por unidad).
--   2) Líneas de la devolución con SKU, variante, cantidad devuelta e importe.
-- Valida aislamiento por rol (RF-01).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Devoluciones_ObtenerDetalle
    @IDDevolucion INT,
    @IDUsuarioSolicitante INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RolSolicitante VARCHAR(30);
    SELECT @RolSolicitante = r.NombreRol
    FROM dbo.Usuarios AS u
    INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
    WHERE u.IDUsuario = @IDUsuarioSolicitante
      AND u.Activo = 1;

    IF @RolSolicitante IS NULL
        ;THROW 50004, 'El usuario solicitante no existe o está inactivo.', 1;

    DECLARE @IDClientePedido INT;
    SELECT @IDClientePedido = p.IDUsuario
    FROM dbo.Devoluciones AS d
    INNER JOIN dbo.Pedidos AS p ON p.IDPedido = d.IDPedido
    WHERE d.IDDevolucion = @IDDevolucion;

    IF @IDClientePedido IS NULL
        ;THROW 50080, 'La solicitud de devolución especificada no existe.', 1;

    IF @RolSolicitante = 'Cliente' AND @IDClientePedido <> @IDUsuarioSolicitante
        ;THROW 50081, 'No tiene permisos para consultar una devolución de otro cliente.', 1;

    -- Recordset 1: Encabezado de la devolución y monto neto asociado
    SELECT
        d.IDDevolucion,
        d.IDPedido,
        p.EstadoPedido,
        p.IDUsuario AS IDCliente,
        cli.NombreCompleto AS NombreCliente,
        cli.Correo AS CorreoCliente,
        d.IDUsuario AS IDUsuarioRegistra,
        reg.NombreCompleto AS UsuarioRegistra,
        d.Motivo,
        d.Estado,
        d.FechaSolicitud,
        ISNULL(tot.TotalUnidadesDevueltas, 0) AS TotalUnidadesDevueltas,
        CAST(ISNULL(tot.MontoReintegroConIVA, 0.00) AS DECIMAL(12,2)) AS MontoReintegroConIVA,
        iva.MontoSinIVA AS MontoReintegroSinIVA,
        iva.MontoIVA AS MontoReintegroIVA
    FROM dbo.Devoluciones AS d
    INNER JOIN dbo.Pedidos AS p ON p.IDPedido = d.IDPedido
    INNER JOIN dbo.Usuarios AS cli ON cli.IDUsuario = p.IDUsuario
    INNER JOIN dbo.Usuarios AS reg ON reg.IDUsuario = d.IDUsuario
    OUTER APPLY (
        SELECT
            SUM(dd.CantidadDevuelta) AS TotalUnidadesDevueltas,
            SUM(
                CAST(
                    ROUND(
                        (pd.SubtotalLinea / CAST(pd.Cantidad AS DECIMAL(12,2))) * CAST(dd.CantidadDevuelta AS DECIMAL(12,2)),
                        2
                    )
                    AS DECIMAL(12,2)
                )
            ) AS MontoReintegroConIVA
        FROM dbo.DevolucionDetalle AS dd
        INNER JOIN dbo.PedidoDetalle AS pd
            ON pd.IDPedido = d.IDPedido
           AND pd.IDVariante = dd.IDVariante
        WHERE dd.IDDevolucion = d.IDDevolucion
    ) AS tot
    CROSS APPLY dbo.FU_Finanzas_DesgloseIVA(ISNULL(tot.MontoReintegroConIVA, 0.00)) AS iva
    WHERE d.IDDevolucion = @IDDevolucion;

    -- Recordset 2: Detalle de líneas devueltas
    SELECT
        dd.IDDevolucionDetalle,
        dd.IDDevolucion,
        dd.IDVariante,
        v.SKU,
        v.NombreVariante,
        prod.IDProducto,
        prod.NombreProducto,
        pd.Cantidad AS CantidadCompradaOriginal,
        pd.PrecioUnitarioCongelado,
        pd.SubtotalLinea AS SubtotalLineaOriginal,
        dd.CantidadDevuelta,
        CAST(
            ROUND(
                (pd.SubtotalLinea / CAST(pd.Cantidad AS DECIMAL(12,2))) * CAST(dd.CantidadDevuelta AS DECIMAL(12,2)),
                2
            )
            AS DECIMAL(12,2)
        ) AS MontoLineaDevuelta
    FROM dbo.DevolucionDetalle AS dd
    INNER JOIN dbo.Devoluciones AS d ON d.IDDevolucion = dd.IDDevolucion
    INNER JOIN dbo.Variantes AS v ON v.IDVariante = dd.IDVariante
    INNER JOIN dbo.Productos AS prod ON prod.IDProducto = v.IDProducto
    INNER JOIN dbo.PedidoDetalle AS pd
        ON pd.IDPedido = d.IDPedido
       AND pd.IDVariante = dd.IDVariante
    WHERE dd.IDDevolucion = @IDDevolucion
    ORDER BY dd.IDDevolucionDetalle ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 2. SP_Devoluciones_Solicitar
-- Registra una solicitud de devolución total o parcial sobre un pedido en
-- estado 'ENTREGADO'.
-- Recibe @ItemsJSON con estructura: [{"IDVariante": 1, "Cantidad": 2}, ...]
-- Cumple el criterio de aceptación de RF-07:
--   "No se puede devolver más cantidad de la vendida en cada línea del pedido."
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Devoluciones_Solicitar
    @IDPedido INT,
    @IDUsuario INT,
    @Motivo NVARCHAR(250),
    @ItemsJSON NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @Motivo = LTRIM(RTRIM(@Motivo));
        IF ISNULL(@Motivo, '') = ''
            ;THROW 50082, 'El motivo de la devolución es obligatorio.', 1;

        IF ISNULL(LTRIM(RTRIM(@ItemsJSON)), '') = '' OR ISJSON(@ItemsJSON) = 0
            ;THROW 50083, 'El detalle de productos a devolver (@ItemsJSON) debe ser un arreglo JSON válido.', 1;

        DECLARE @RolUsuario VARCHAR(30);
        SELECT @RolUsuario = r.NombreRol
        FROM dbo.Usuarios AS u
        INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
        WHERE u.IDUsuario = @IDUsuario
          AND u.Activo = 1;

        IF @RolUsuario IS NULL
            ;THROW 50004, 'El usuario solicitante no existe o está inactivo.', 1;

        -- Bloquear el pedido para evitar solicitudes concurrentes que excedan el saldo
        DECLARE @IDClientePedido INT;
        DECLARE @EstadoPedido VARCHAR(30);

        SELECT
            @IDClientePedido = IDUsuario,
            @EstadoPedido = EstadoPedido
        FROM dbo.Pedidos WITH (UPDLOCK, ROWLOCK)
        WHERE IDPedido = @IDPedido;

        IF @IDClientePedido IS NULL
            ;THROW 50070, 'El pedido especificado no existe.', 1;

        -- Control de acceso por rol (RF-01): un Cliente solo puede devolver sus propios pedidos
        IF @RolUsuario = 'Cliente' AND @IDClientePedido <> @IDUsuario
            ;THROW 50071, 'No tiene permisos para solicitar devoluciones sobre el pedido de otro cliente.', 1;

        -- Solo pedidos entregados pueden devolverse (antes de entrega se utiliza cancelación)
        IF @EstadoPedido <> 'ENTREGADO'
            ;THROW 50084, 'Únicamente se pueden solicitar devoluciones sobre pedidos en estado ENTREGADO.', 1;

        -- Extraer y agrupar los ítems del JSON
        CREATE TABLE #ItemsDevolucion (
            IDVariante INT NOT NULL PRIMARY KEY,
            CantidadSolicitada INT NOT NULL
        );

        INSERT INTO #ItemsDevolucion (IDVariante, CantidadSolicitada)
        SELECT
            IDVariante,
            SUM(Cantidad)
        FROM OPENJSON(@ItemsJSON)
        WITH (
            IDVariante INT '$.IDVariante',
            Cantidad INT '$.Cantidad'
        )
        WHERE IDVariante IS NOT NULL
        GROUP BY IDVariante;

        IF NOT EXISTS (SELECT 1 FROM #ItemsDevolucion)
            ;THROW 50085, 'Debe incluir al menos una línea de producto para devolver.', 1;

        IF EXISTS (SELECT 1 FROM #ItemsDevolucion WHERE CantidadSolicitada <= 0)
            ;THROW 50086, 'La cantidad a devolver de cada línea debe ser mayor a cero.', 1;

        -- Validar que todas las variantes enviadas pertenezcan al pedido
        IF EXISTS (
            SELECT 1
            FROM #ItemsDevolucion AS i
            WHERE NOT EXISTS (
                SELECT 1
                FROM dbo.PedidoDetalle AS pd
                WHERE pd.IDPedido = @IDPedido
                  AND pd.IDVariante = i.IDVariante
            )
        )
            ;THROW 50087, 'Una o más variantes indicadas en la devolución no forman parte del pedido original.', 1;

        -- Validar contra dbo.FU_Pedidos_SaldoDevolucionLinea que ninguna línea supere lo disponible (RF-07)
        DECLARE @SKUExcedido VARCHAR(50);
        DECLARE @NombreExcedido NVARCHAR(100);
        DECLARE @CantSolicitadaExcedida INT;
        DECLARE @CantDisponibleExcedida INT;

        SELECT TOP (1)
            @SKUExcedido = v.SKU,
            @NombreExcedido = v.NombreVariante,
            @CantSolicitadaExcedida = i.CantidadSolicitada,
            @CantDisponibleExcedida = saldo.CantidadDisponibleDevolver
        FROM #ItemsDevolucion AS i
        INNER JOIN dbo.Variantes AS v ON v.IDVariante = i.IDVariante
        CROSS APPLY dbo.FU_Pedidos_SaldoDevolucionLinea(@IDPedido, i.IDVariante) AS saldo
        WHERE i.CantidadSolicitada > saldo.CantidadDisponibleDevolver;

        IF @SKUExcedido IS NOT NULL
        BEGIN
            DECLARE @MensajeExceso NVARCHAR(250) = CONCAT(
                N'No se puede devolver más cantidad de la vendida para "', @NombreExcedido,
                N'" (SKU: ', @SKUExcedido, N'). Solicitado: ', @CantSolicitadaExcedida,
                N', Disponible para devolver: ', @CantDisponibleExcedida, N'.'
            );
            ;THROW 50088, @MensajeExceso, 1;
        END

        -- Insertar encabezado en dbo.Devoluciones
        INSERT INTO dbo.Devoluciones (
            IDPedido,
            IDUsuario,
            Motivo,
            Estado,
            FechaSolicitud
        )
        VALUES (
            @IDPedido,
            @IDUsuario,
            @Motivo,
            'SOLICITADA',
            SYSDATETIME()
        );

        DECLARE @IDDevolucionNueva INT = SCOPE_IDENTITY();

        -- Insertar líneas en dbo.DevolucionDetalle
        INSERT INTO dbo.DevolucionDetalle (
            IDDevolucion,
            IDVariante,
            CantidadDevuelta
        )
        SELECT
            @IDDevolucionNueva,
            i.IDVariante,
            i.CantidadSolicitada
        FROM #ItemsDevolucion AS i
        ORDER BY i.IDVariante ASC;

        -- Registrar en dbo.Bitacora (RF-09)
        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Accion,
            IDRegistroAfectado,
            ValorAnterior,
            ValorNuevo
        )
        VALUES (
            @IDUsuario,
            'DEVOLUCIONES',
            'CREAR',
            CAST(@IDDevolucionNueva AS VARCHAR(50)),
            NULL,
            CONCAT(
                N'{"IDDevolucion":', @IDDevolucionNueva,
                N',"IDPedido":', @IDPedido,
                N',"Estado":"SOLICITADA","Motivo":"', @Motivo, N'"}'
            )
        );

        DROP TABLE #ItemsDevolucion;

        COMMIT TRANSACTION;

        EXEC dbo.SP_Devoluciones_ObtenerDetalle
            @IDDevolucion = @IDDevolucionNueva,
            @IDUsuarioSolicitante = @IDUsuario;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 3. SP_Devoluciones_Resolver
-- Permite a un Operador o Administrador aprobar ('APROBADA') o rechazar
-- ('RECHAZADA') una devolución en estado 'SOLICITADA'.
-- Si se aprueba, reintegra atómicamente las unidades a StockFisico en
-- dbo.Variantes y genera el movimiento 'DEVOLUCION' en dbo.Kardex (RF-03, RF-07).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Devoluciones_Resolver
    @IDDevolucion INT,
    @IDUsuario INT,
    @NuevoEstado VARCHAR(20), -- 'APROBADA' | 'RECHAZADA'
    @Observacion NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @NuevoEstado = LTRIM(RTRIM(UPPER(@NuevoEstado)));
        SET @Observacion = NULLIF(LTRIM(RTRIM(@Observacion)), '');

        IF @NuevoEstado NOT IN ('APROBADA', 'RECHAZADA')
            ;THROW 50089, 'El estado de resolución de la devolución debe ser APROBADA o RECHAZADA.', 1;

        DECLARE @RolResolutor VARCHAR(30);
        SELECT @RolResolutor = r.NombreRol
        FROM dbo.Usuarios AS u
        INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
        WHERE u.IDUsuario = @IDUsuario
          AND u.Activo = 1;

        IF @RolResolutor IS NULL OR @RolResolutor NOT IN ('Operador', 'Administrador')
            ;THROW 50090, 'Solo un Operador o Administrador activo puede aprobar o rechazar devoluciones.', 1;

        -- Bloquear la devolución para evitar doble resolución concurrente
        DECLARE @IDPedido INT;
        DECLARE @EstadoActual VARCHAR(20);
        DECLARE @MotivoOriginal NVARCHAR(250);

        SELECT
            @IDPedido = IDPedido,
            @EstadoActual = Estado,
            @MotivoOriginal = Motivo
        FROM dbo.Devoluciones WITH (UPDLOCK, ROWLOCK)
        WHERE IDDevolucion = @IDDevolucion;

        IF @IDPedido IS NULL
            ;THROW 50080, 'La solicitud de devolución especificada no existe.', 1;

        IF @EstadoActual <> 'SOLICITADA'
            ;THROW 50091, 'Esta solicitud de devolución ya fue procesada anteriormente.', 1;

        -- Si se aprueba, reintegrar existencias a dbo.Variantes y registrar 'DEVOLUCION' en dbo.Kardex
        IF @NuevoEstado = 'APROBADA'
        BEGIN
            DECLARE @IDVarianteDev INT;
            DECLARE @CantidadDev INT;
            DECLARE @StockAntDev INT;
            DECLARE @StockActDev INT;
            DECLARE @MotivoKardexDev NVARCHAR(250) = CONCAT(
                N'Reintegro por Devolución aprobada #', @IDDevolucion,
                N' (Pedido #', @IDPedido, N'): ',
                LEFT(ISNULL(@Observacion, @MotivoOriginal), 140)
            );

            DECLARE cur_devolucion CURSOR LOCAL FAST_FORWARD FOR
                SELECT dd.IDVariante, dd.CantidadDevuelta
                FROM dbo.DevolucionDetalle AS dd
                WHERE dd.IDDevolucion = @IDDevolucion
                ORDER BY dd.IDVariante ASC;

            OPEN cur_devolucion;
            FETCH NEXT FROM cur_devolucion INTO @IDVarianteDev, @CantidadDev;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT @StockAntDev = StockFisico
                FROM dbo.Variantes WITH (UPDLOCK, ROWLOCK)
                WHERE IDVariante = @IDVarianteDev;

                SET @StockActDev = @StockAntDev + @CantidadDev;

                UPDATE dbo.Variantes
                SET StockFisico = @StockActDev
                WHERE IDVariante = @IDVarianteDev;

                INSERT INTO dbo.Kardex (
                    IDVariante,
                    TipoMovimiento,
                    Cantidad,
                    StockAnterior,
                    StockActual,
                    IDPedido,
                    IDDevolucion,
                    IDUsuario,
                    Motivo,
                    FechaMovimiento
                )
                VALUES (
                    @IDVarianteDev,
                    'DEVOLUCION',
                    @CantidadDev,
                    @StockAntDev,
                    @StockActDev,
                    @IDPedido,
                    @IDDevolucion,
                    @IDUsuario,
                    @MotivoKardexDev,
                    SYSDATETIME()
                );

                FETCH NEXT FROM cur_devolucion INTO @IDVarianteDev, @CantidadDev;
            END

            CLOSE cur_devolucion;
            DEALLOCATE cur_devolucion;
        END

        -- Actualizar el estado de la devolución
        UPDATE dbo.Devoluciones
        SET Estado = @NuevoEstado,
            Motivo = CASE
                WHEN @Observacion IS NOT NULL THEN LEFT(CONCAT(@MotivoOriginal, N' | Resolución: ', @Observacion), 250)
                ELSE @MotivoOriginal
            END
        WHERE IDDevolucion = @IDDevolucion;

        -- Registrar en dbo.Bitacora (RF-09)
        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Accion,
            IDRegistroAfectado,
            ValorAnterior,
            ValorNuevo
        )
        VALUES (
            @IDUsuario,
            'DEVOLUCIONES',
            'MODIFICAR',
            CAST(@IDDevolucion AS VARCHAR(50)),
            CONCAT(N'{"IDDevolucion":', @IDDevolucion, N',"IDPedido":', @IDPedido, N',"Estado":"', @EstadoActual, N'"}'),
            CONCAT(N'{"IDDevolucion":', @IDDevolucion, N',"IDPedido":', @IDPedido, N',"Estado":"', @NuevoEstado, N'","Observacion":"', ISNULL(@Observacion, N''), N'"}')
        );

        COMMIT TRANSACTION;

        EXEC dbo.SP_Devoluciones_ObtenerDetalle
            @IDDevolucion = @IDDevolucion,
            @IDUsuarioSolicitante = @IDUsuario;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 4. SP_Devoluciones_Listar
-- Listado de devoluciones con paginación y filtros del lado del servidor.
-- Si quien consulta es 'Cliente', filtra estrictamente sus propias devoluciones.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Devoluciones_Listar
    @IDUsuarioSolicitante INT,
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 15,
    @Estado VARCHAR(20) = NULL,
    @IDPedido INT = NULL,
    @IDClienteFiltro INT = NULL,
    @FechaInicio DATETIME2(0) = NULL,
    @FechaFin DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @NumeroPagina < 1 SET @NumeroPagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 15;

    DECLARE @Offset INT = (@NumeroPagina - 1) * @TamanoPagina;

    DECLARE @RolSolicitante VARCHAR(30);
    SELECT @RolSolicitante = r.NombreRol
    FROM dbo.Usuarios AS u
    INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
    WHERE u.IDUsuario = @IDUsuarioSolicitante
      AND u.Activo = 1;

    IF @RolSolicitante IS NULL
        ;THROW 50004, 'El usuario solicitante no existe o está inactivo.', 1;

    IF @RolSolicitante = 'Cliente'
        SET @IDClienteFiltro = @IDUsuarioSolicitante;

    -- Recordset 1: Total de registros para paginación
    SELECT COUNT(1) AS TotalRegistros
    FROM dbo.Devoluciones AS d
    INNER JOIN dbo.Pedidos AS p ON p.IDPedido = d.IDPedido
    WHERE (@Estado IS NULL OR d.Estado = @Estado)
      AND (@IDPedido IS NULL OR d.IDPedido = @IDPedido)
      AND (@IDClienteFiltro IS NULL OR p.IDUsuario = @IDClienteFiltro)
      AND (@FechaInicio IS NULL OR d.FechaSolicitud >= @FechaInicio)
      AND (@FechaFin IS NULL OR d.FechaSolicitud <= @FechaFin);

    -- Recordset 2: Página de devoluciones
    SELECT
        d.IDDevolucion,
        d.IDPedido,
        p.IDUsuario AS IDCliente,
        cli.NombreCompleto AS NombreCliente,
        cli.Correo AS CorreoCliente,
        d.Motivo,
        d.Estado,
        d.FechaSolicitud,
        ISNULL(res.TotalUnidadesDevueltas, 0) AS TotalUnidadesDevueltas,
        CAST(ISNULL(res.MontoReintegroConIVA, 0.00) AS DECIMAL(12,2)) AS MontoReintegroConIVA
    FROM dbo.Devoluciones AS d
    INNER JOIN dbo.Pedidos AS p ON p.IDPedido = d.IDPedido
    INNER JOIN dbo.Usuarios AS cli ON cli.IDUsuario = p.IDUsuario
    OUTER APPLY (
        SELECT
            SUM(dd.CantidadDevuelta) AS TotalUnidadesDevueltas,
            SUM(
                CAST(
                    ROUND(
                        (pd.SubtotalLinea / CAST(pd.Cantidad AS DECIMAL(12,2))) * CAST(dd.CantidadDevuelta AS DECIMAL(12,2)),
                        2
                    )
                    AS DECIMAL(12,2)
                )
            ) AS MontoReintegroConIVA
        FROM dbo.DevolucionDetalle AS dd
        INNER JOIN dbo.PedidoDetalle AS pd
            ON pd.IDPedido = d.IDPedido
           AND pd.IDVariante = dd.IDVariante
        WHERE dd.IDDevolucion = d.IDDevolucion
    ) AS res
    WHERE (@Estado IS NULL OR d.Estado = @Estado)
      AND (@IDPedido IS NULL OR d.IDPedido = @IDPedido)
      AND (@IDClienteFiltro IS NULL OR p.IDUsuario = @IDClienteFiltro)
      AND (@FechaInicio IS NULL OR d.FechaSolicitud >= @FechaInicio)
      AND (@FechaFin IS NULL OR d.FechaSolicitud <= @FechaFin)
    ORDER BY d.FechaSolicitud DESC, d.IDDevolucion DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO
