-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 05_sp_inventario_kardex.sql
-- DESCRIPCIÓN: Procedimientos almacenados para control de Inventario,
--              Reservas Temporales con bloqueo pesimista (TTL 15 min) y Kardex
--              trazable (RF-03, RF-06, RF-07, RF-09).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 3: INVENTARIO, RESERVAS TEMPORALES Y KARDEX (RF-03, RF-06, RF-07, RF-09)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SP_Inventario_LiberarReservasExpiradas
-- Marca como 'LIBERADA' toda reserva con Estado = 'ACTIVA' cuyo TTL haya
-- vencido (FechaExpiracion <= SYSDATETIME()).
-- Cumple el criterio de aceptación RF-07: "Una reserva vencida libera la
-- existencia sin intervención manual".
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_LiberarReservasExpiradas
    @IDVariante INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.ReservasExistencia
        SET Estado = 'LIBERADA'
        WHERE Estado = 'ACTIVA'
          AND FechaExpiracion <= SYSDATETIME()
          AND (@IDVariante IS NULL OR IDVariante = @IDVariante);

        DECLARE @ReservasLiberadas INT = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT
            @ReservasLiberadas AS ReservasExpiradasLiberadas,
            SYSDATETIME() AS FechaCorte;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2. SP_Inventario_ReservarExistencia
-- Reserva temporalmente unidades de una variante durante 15 minutos usando
-- bloqueo pesimista (UPDLOCK, ROWLOCK) sobre dbo.Variantes para evitar
-- condiciones de carrera y sobreventa ante compras simultáneas de la última
-- unidad (RF-06).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ReservarExistencia
    @IDVariante INT,
    @Cantidad INT,
    @IDUsuario INT = NULL,
    @TokenSesion VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Cantidad <= 0
            THROW 50030, 'La cantidad a reservar debe ser mayor a cero.', 1;

        SET @TokenSesion = NULLIF(LTRIM(RTRIM(@TokenSesion)), '');

        IF @IDUsuario IS NULL AND @TokenSesion IS NULL
            THROW 50031, 'Debe especificar un usuario autenticado o un token de sesión para reservar existencia.', 1;

        -- 1. Bloqueo pesimista sobre la fila de la variante para serializar accesos concurrentes
        DECLARE @StockFisico INT;
        DECLARE @VarianteActiva BIT;
        DECLARE @SKU VARCHAR(50);
        DECLARE @NombreVariante NVARCHAR(100);

        SELECT
            @StockFisico = v.StockFisico,
            @SKU = v.SKU,
            @NombreVariante = v.NombreVariante,
            @VarianteActiva = CASE WHEN v.Activo = 1 AND p.Activo = 1 AND c.Activo = 1 THEN 1 ELSE 0 END
        FROM dbo.Variantes AS v WITH (UPDLOCK, ROWLOCK)
        INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
        INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
        WHERE v.IDVariante = @IDVariante;

        IF @StockFisico IS NULL
            THROW 50019, 'La variante solicitada no existe.', 1;

        IF @VarianteActiva = 0
            THROW 50032, 'El producto o variante seleccionada ya no se encuentra disponible para la venta.', 1;

        -- 2. Barrido automático de reservas expiradas sobre esta variante
        UPDATE dbo.ReservasExistencia
        SET Estado = 'LIBERADA'
        WHERE IDVariante = @IDVariante
          AND Estado = 'ACTIVA'
          AND FechaExpiracion <= SYSDATETIME();

        -- 3. Liberar cualquier reserva previa activa del mismo usuario/sesión sobre la misma variante
        --    para que un reintento renueve el apartado sin duplicar su propio bloqueo
        UPDATE dbo.ReservasExistencia
        SET Estado = 'LIBERADA'
        WHERE IDVariante = @IDVariante
          AND Estado = 'ACTIVA'
          AND (
              (@IDUsuario IS NOT NULL AND IDUsuario = @IDUsuario)
              OR (@IDUsuario IS NULL AND @TokenSesion IS NOT NULL AND TokenSesion = @TokenSesion)
          );

        -- 4. Calcular reservas activas vigentes de otros clientes
        DECLARE @StockReservadoOtros INT = 0;

        SELECT @StockReservadoOtros = ISNULL(SUM(r.Cantidad), 0)
        FROM dbo.ReservasExistencia AS r WITH (UPDLOCK)
        WHERE r.IDVariante = @IDVariante
          AND r.Estado = 'ACTIVA'
          AND r.FechaExpiracion > SYSDATETIME();

        DECLARE @StockDisponibleReal INT = @StockFisico - @StockReservadoOtros;

        IF @StockDisponibleReal < @Cantidad
        BEGIN
            DECLARE @MensajeSinStock NVARCHAR(250) = CONCAT(
                N'Existencia insuficiente para "', @NombreVariante,
                N'" (SKU: ', @SKU, N'). Solicitado: ', @Cantidad,
                N', Disponible: ', CASE WHEN @StockDisponibleReal < 0 THEN 0 ELSE @StockDisponibleReal END, N'.'
            );
            THROW 50033, @MensajeSinStock, 1;
        END

        -- 5. Crear la reserva temporal con TTL de 15 minutos
        DECLARE @FechaCreacion DATETIME2(0) = SYSDATETIME();
        DECLARE @FechaExpiracion DATETIME2(0) = DATEADD(MINUTE, 15, @FechaCreacion);

        INSERT INTO dbo.ReservasExistencia (
            IDVariante,
            IDUsuario,
            TokenSesion,
            Cantidad,
            FechaCreacion,
            FechaExpiracion,
            Estado
        )
        VALUES (
            @IDVariante,
            @IDUsuario,
            @TokenSesion,
            @Cantidad,
            @FechaCreacion,
            @FechaExpiracion,
            'ACTIVA'
        );

        DECLARE @IDReservaNueva BIGINT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT
            r.IDReserva,
            r.IDVariante,
            @SKU AS SKU,
            @NombreVariante AS NombreVariante,
            r.IDUsuario,
            r.TokenSesion,
            r.Cantidad AS CantidadReservada,
            r.FechaCreacion,
            r.FechaExpiracion,
            r.Estado,
            (@StockDisponibleReal - @Cantidad) AS StockDisponibleRestante
        FROM dbo.ReservasExistencia AS r
        WHERE r.IDReserva = @IDReservaNueva;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2.1 SP_Inventario_ReservarStock (Alias compatible con AGENTS.md)
-- Invoca internamente dbo.SP_Inventario_ReservarExistencia.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ReservarStock
    @IDVariante INT,
    @Cantidad INT,
    @IDUsuario INT = NULL,
    @TokenSesion VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.SP_Inventario_ReservarExistencia
        @IDVariante = @IDVariante,
        @Cantidad = @Cantidad,
        @IDUsuario = @IDUsuario,
        @TokenSesion = @TokenSesion;
END;
GO

-- ----------------------------------------------------------------------------
-- 3. SP_Inventario_ReservarCarritoCheckout
-- Al iniciar el checkout (RF-06), reserva atómicamente durante 15 minutos
-- todas las variantes del carrito activo del cliente en orden ascendente de
-- IDVariante para prevenir deadlocks y garantizar que ningún ítem quede sin
-- stock antes de proceder al pago.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ReservarCarritoCheckout
    @IDCarrito INT,
    @IDUsuario INT = NULL,
    @TokenSesion VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @TokenSesion = NULLIF(LTRIM(RTRIM(@TokenSesion)), '');

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Carritos AS c
            WHERE c.IDCarrito = @IDCarrito
              AND c.Estado = 'ACTIVO'
              AND (
                  (@IDUsuario IS NOT NULL AND c.IDUsuario = @IDUsuario)
                  OR (@IDUsuario IS NULL AND @TokenSesion IS NOT NULL AND c.TokenInvitado = @TokenSesion)
              )
        )
            THROW 50034, 'El carrito especificado no existe, no está activo o no pertenece al usuario.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.CarritoDetalle WHERE IDCarrito = @IDCarrito)
            THROW 50035, 'El carrito se encuentra vacío; no hay productos para reservar.', 1;

        -- 1. Liberar reservas expiradas globales de las variantes involucradas
        UPDATE r
        SET r.Estado = 'LIBERADA'
        FROM dbo.ReservasExistencia AS r
        INNER JOIN dbo.CarritoDetalle AS cd ON cd.IDVariante = r.IDVariante
        WHERE cd.IDCarrito = @IDCarrito
          AND r.Estado = 'ACTIVA'
          AND r.FechaExpiracion <= SYSDATETIME();

        -- 2. Liberar reservas activas previas de este mismo usuario/sesión para renovarlas
        UPDATE dbo.ReservasExistencia
        SET Estado = 'LIBERADA'
        WHERE Estado = 'ACTIVA'
          AND (
              (@IDUsuario IS NOT NULL AND IDUsuario = @IDUsuario)
              OR (@IDUsuario IS NULL AND @TokenSesion IS NOT NULL AND TokenSesion = @TokenSesion)
          );

        -- 3. Iterar en orden determinista (IDVariante ASC) adquiriendo UPDLOCK, ROWLOCK
        DECLARE @IDVarianteActual INT;
        DECLARE @CantidadSolicitada INT;
        DECLARE @StockFisico INT;
        DECLARE @StockReservadoOtros INT;
        DECLARE @VarianteActiva BIT;
        DECLARE @SKU VARCHAR(50);
        DECLARE @NombreVariante NVARCHAR(100);
        DECLARE @FechaAhora DATETIME2(0) = SYSDATETIME();
        DECLARE @FechaExpiracion DATETIME2(0) = DATEADD(MINUTE, 15, @FechaAhora);

        DECLARE cur_items CURSOR LOCAL FAST_FORWARD FOR
            SELECT cd.IDVariante, cd.Cantidad
            FROM dbo.CarritoDetalle AS cd
            WHERE cd.IDCarrito = @IDCarrito
            ORDER BY cd.IDVariante ASC;

        OPEN cur_items;
        FETCH NEXT FROM cur_items INTO @IDVarianteActual, @CantidadSolicitada;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT
                @StockFisico = v.StockFisico,
                @SKU = v.SKU,
                @NombreVariante = v.NombreVariante,
                @VarianteActiva = CASE WHEN v.Activo = 1 AND p.Activo = 1 AND c.Activo = 1 THEN 1 ELSE 0 END
            FROM dbo.Variantes AS v WITH (UPDLOCK, ROWLOCK)
            INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
            INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
            WHERE v.IDVariante = @IDVarianteActual;

            IF @VarianteActiva = 0
            BEGIN
                DECLARE @MsgInactivo NVARCHAR(250) = CONCAT(
                    N'El artículo "', @NombreVariante, N'" (SKU: ', @SKU, N') ya no se encuentra disponible.'
                );
                THROW 50032, @MsgInactivo, 1;
            END

            SELECT @StockReservadoOtros = ISNULL(SUM(r.Cantidad), 0)
            FROM dbo.ReservasExistencia AS r WITH (UPDLOCK)
            WHERE r.IDVariante = @IDVarianteActual
              AND r.Estado = 'ACTIVA'
              AND r.FechaExpiracion > @FechaAhora;

            IF (@StockFisico - @StockReservadoOtros) < @CantidadSolicitada
            BEGIN
                DECLARE @Disp INT = CASE WHEN (@StockFisico - @StockReservadoOtros) < 0 THEN 0 ELSE (@StockFisico - @StockReservadoOtros) END;
                DECLARE @MsgStock NVARCHAR(250) = CONCAT(
                    N'Existencia insuficiente para "', @NombreVariante,
                    N'" (SKU: ', @SKU, N'). Solicitado: ', @CantidadSolicitada,
                    N', Disponible: ', @Disp, N'.'
                );
                THROW 50033, @MsgStock, 1;
            END

            INSERT INTO dbo.ReservasExistencia (
                IDVariante,
                IDUsuario,
                TokenSesion,
                Cantidad,
                FechaCreacion,
                FechaExpiracion,
                Estado
            )
            VALUES (
                @IDVarianteActual,
                @IDUsuario,
                @TokenSesion,
                @CantidadSolicitada,
                @FechaAhora,
                @FechaExpiracion,
                'ACTIVA'
            );

            FETCH NEXT FROM cur_items INTO @IDVarianteActual, @CantidadSolicitada;
        END

        CLOSE cur_items;
        DEALLOCATE cur_items;

        COMMIT TRANSACTION;

        -- Devolver las reservas creadas para este carrito
        SELECT
            r.IDReserva,
            r.IDVariante,
            v.SKU,
            v.NombreVariante,
            r.Cantidad AS CantidadReservada,
            r.FechaCreacion,
            r.FechaExpiracion,
            r.Estado
        FROM dbo.ReservasExistencia AS r
        INNER JOIN dbo.Variantes AS v ON v.IDVariante = r.IDVariante
        WHERE r.Estado = 'ACTIVA'
          AND r.FechaCreacion = @FechaAhora
          AND (
              (@IDUsuario IS NOT NULL AND r.IDUsuario = @IDUsuario)
              OR (@IDUsuario IS NULL AND @TokenSesion IS NOT NULL AND r.TokenSesion = @TokenSesion)
          )
        ORDER BY r.IDVariante ASC;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 4. SP_Inventario_LiberarReserva
-- Libera manualmente una reserva específica por @IDReserva o todas las
-- reservas activas de un @IDUsuario / @TokenSesion.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_LiberarReserva
    @IDReserva BIGINT = NULL,
    @IDUsuario INT = NULL,
    @TokenSesion VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @TokenSesion = NULLIF(LTRIM(RTRIM(@TokenSesion)), '');

        IF @IDReserva IS NULL AND @IDUsuario IS NULL AND @TokenSesion IS NULL
            THROW 50036, 'Debe indicar el IDReserva, IDUsuario o TokenSesion a liberar.', 1;

        UPDATE dbo.ReservasExistencia
        SET Estado = 'LIBERADA'
        WHERE Estado = 'ACTIVA'
          AND (@IDReserva IS NULL OR IDReserva = @IDReserva)
          AND (@IDUsuario IS NULL OR IDUsuario = @IDUsuario)
          AND (@TokenSesion IS NULL OR TokenSesion = @TokenSesion);

        DECLARE @TotalLiberadas INT = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT
            @TotalLiberadas AS ReservasLiberadas,
            SYSDATETIME() AS FechaLiberacion;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 5. SP_Inventario_RegistrarAjuste
-- Permite a un Operador o Administrador realizar un ajuste manual de almacén
-- ('AJUSTE_ENTRADA' o 'AJUSTE_SALIDA').
-- Cumple criterios de aceptación RF-03 y RF-09:
--   - Exige motivo obligatorio.
--   - No permite que la existencia quede en negativo.
--   - Registra el movimiento en dbo.Kardex (StockAnterior, StockActual).
--   - Registra la auditoría en dbo.Bitacora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_RegistrarAjuste
    @IDUsuario INT,
    @IDVariante INT,
    @TipoMovimiento VARCHAR(25), -- 'AJUSTE_ENTRADA' | 'AJUSTE_SALIDA'
    @Cantidad INT,
    @Motivo NVARCHAR(250)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @TipoMovimiento NOT IN ('AJUSTE_ENTRADA', 'AJUSTE_SALIDA')
            THROW 50037, 'El tipo de movimiento manual debe ser AJUSTE_ENTRADA o AJUSTE_SALIDA.', 1;

        IF @Cantidad <= 0
            THROW 50038, 'La cantidad del ajuste de inventario debe ser mayor a cero.', 1;

        SET @Motivo = LTRIM(RTRIM(@Motivo));
        IF ISNULL(@Motivo, '') = ''
            THROW 50039, 'El motivo del ajuste manual de inventario es obligatorio.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IDUsuario = @IDUsuario AND Activo = 1)
            THROW 50004, 'El usuario operador/administrador no existe o está inactivo.', 1;

        -- Bloqueo pesimista sobre la variante para garantizar consistencia con el Kardex
        DECLARE @StockAnterior INT;
        DECLARE @SKU VARCHAR(50);
        DECLARE @NombreVariante NVARCHAR(100);

        SELECT
            @StockAnterior = StockFisico,
            @SKU = SKU,
            @NombreVariante = NombreVariante
        FROM dbo.Variantes WITH (UPDLOCK, ROWLOCK)
        WHERE IDVariante = @IDVariante;

        IF @StockAnterior IS NULL
            THROW 50019, 'La variante especificada no existe.', 1;

        DECLARE @StockActual INT;

        IF @TipoMovimiento = 'AJUSTE_ENTRADA'
        BEGIN
            SET @StockActual = @StockAnterior + @Cantidad;
        END
        ELSE
        BEGIN
            IF (@StockAnterior - @Cantidad) < 0
            BEGIN
                DECLARE @MsgNegativo NVARCHAR(250) = CONCAT(
                    N'El ajuste de salida por ', @Cantidad,
                    N' unidades dejaría en negativo la existencia física de "', @NombreVariante,
                    N'" (Stock actual: ', @StockAnterior, N').'
                );
                THROW 50040, @MsgNegativo, 1;
            END

            SET @StockActual = @StockAnterior - @Cantidad;
        END

        -- 1. Actualizar StockFisico en Variantes
        UPDATE dbo.Variantes
        SET StockFisico = @StockActual
        WHERE IDVariante = @IDVariante;

        -- 2. Insertar asiento trazable en Kardex
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
            @IDVariante,
            @TipoMovimiento,
            @Cantidad,
            @StockAnterior,
            @StockActual,
            NULL,
            NULL,
            @IDUsuario,
            @Motivo,
            SYSDATETIME()
        );

        DECLARE @IDKardexGenerado BIGINT = SCOPE_IDENTITY();

        -- 3. Registrar auditoría en Bitácora
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
            'INVENTARIO',
            'MODIFICAR',
            CAST(@IDVariante AS VARCHAR(50)),
            CONCAT(N'{"SKU":"', @SKU, N'","StockFisico":', @StockAnterior, N'}'),
            CONCAT(N'{"SKU":"', @SKU, N'","TipoMovimiento":"', @TipoMovimiento, N'","Cantidad":', @Cantidad, N',"StockFisico":', @StockActual, N',"Motivo":"', @Motivo, N'"}')
        );

        COMMIT TRANSACTION;

        SELECT
            k.IDKardex,
            k.IDVariante,
            @SKU AS SKU,
            @NombreVariante AS NombreVariante,
            k.TipoMovimiento,
            k.Cantidad,
            k.StockAnterior,
            k.StockActual,
            disp.StockReservado,
            disp.StockDisponible,
            k.IDUsuario,
            k.Motivo,
            k.FechaMovimiento
        FROM dbo.Kardex AS k
        CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(k.IDVariante) AS disp
        WHERE k.IDKardex = @IDKardexGenerado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 6. SP_Inventario_ConsultarKardex
-- Consulta paginada y filtrada del historial de movimientos en dbo.Kardex.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ConsultarKardex
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 20,
    @IDVariante INT = NULL,
    @IDProducto INT = NULL,
    @TipoMovimiento VARCHAR(25) = NULL,
    @FechaInicio DATETIME2(0) = NULL,
    @FechaFin DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @NumeroPagina < 1 SET @NumeroPagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 20;

    DECLARE @Offset INT = (@NumeroPagina - 1) * @TamanoPagina;

    -- Recordset 1: Total de movimientos para paginación
    SELECT COUNT(1) AS TotalRegistros
    FROM dbo.Kardex AS k
    INNER JOIN dbo.Variantes AS v ON v.IDVariante = k.IDVariante
    WHERE (@IDVariante IS NULL OR k.IDVariante = @IDVariante)
      AND (@IDProducto IS NULL OR v.IDProducto = @IDProducto)
      AND (@TipoMovimiento IS NULL OR k.TipoMovimiento = @TipoMovimiento)
      AND (@FechaInicio IS NULL OR k.FechaMovimiento >= @FechaInicio)
      AND (@FechaFin IS NULL OR k.FechaMovimiento <= @FechaFin);

    -- Recordset 2: Página de movimientos del Kardex
    SELECT
        k.IDKardex,
        k.IDVariante,
        v.SKU,
        v.NombreVariante,
        p.IDProducto,
        p.NombreProducto,
        k.TipoMovimiento,
        k.Cantidad,
        k.StockAnterior,
        k.StockActual,
        k.IDPedido,
        k.IDDevolucion,
        k.IDUsuario,
        u.NombreCompleto AS UsuarioResponsable,
        u.Correo AS CorreoResponsable,
        k.Motivo,
        k.FechaMovimiento
    FROM dbo.Kardex AS k
    INNER JOIN dbo.Variantes AS v ON v.IDVariante = k.IDVariante
    INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
    INNER JOIN dbo.Usuarios AS u ON u.IDUsuario = k.IDUsuario
    WHERE (@IDVariante IS NULL OR k.IDVariante = @IDVariante)
      AND (@IDProducto IS NULL OR v.IDProducto = @IDProducto)
      AND (@TipoMovimiento IS NULL OR k.TipoMovimiento = @TipoMovimiento)
      AND (@FechaInicio IS NULL OR k.FechaMovimiento >= @FechaInicio)
      AND (@FechaFin IS NULL OR k.FechaMovimiento <= @FechaFin)
    ORDER BY k.FechaMovimiento DESC, k.IDKardex DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

-- ----------------------------------------------------------------------------
-- 7. SP_Inventario_ListarExistencias
-- Listado de inventario para Operadores y Administradores con paginación
-- server-side, mostrando StockFisico, StockReservado, StockDisponible y la
-- suma histórica del Kardex para verificar la integridad exigida en RF-03.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ListarExistencias
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 20,
    @IDCategoria INT = NULL,
    @Busqueda NVARCHAR(150) = NULL,
    @SoloBajoStock BIT = 0,
    @UmbralBajoStock INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    IF @NumeroPagina < 1 SET @NumeroPagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 20;

    DECLARE @Offset INT = (@NumeroPagina - 1) * @TamanoPagina;
    SET @Busqueda = NULLIF(LTRIM(RTRIM(@Busqueda)), '');

    -- Recordset 1: Total de variantes filtradas
    SELECT COUNT(1) AS TotalRegistros
    FROM dbo.Variantes AS v
    INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
    CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(v.IDVariante) AS disp
    WHERE (@IDCategoria IS NULL OR p.IDCategoria = @IDCategoria)
      AND (
          @Busqueda IS NULL
          OR v.SKU LIKE '%' + @Busqueda + '%'
          OR v.NombreVariante LIKE N'%' + @Busqueda + N'%'
          OR p.NombreProducto LIKE N'%' + @Busqueda + N'%'
      )
      AND (@SoloBajoStock = 0 OR disp.StockDisponible <= @UmbralBajoStock);

    -- Recordset 2: Detalle de existencias y conciliación contra Kardex
    SELECT
        v.IDVariante,
        v.SKU,
        v.NombreVariante,
        p.IDProducto,
        p.NombreProducto,
        c.IDCategoria,
        c.NombreCategoria,
        v.Precio,
        disp.StockFisico,
        disp.StockReservado,
        disp.StockDisponible,
        ISNULL(kardexSum.SumaMovimientosKardex, 0) AS SumaMovimientosKardex,
        CAST(CASE WHEN disp.StockFisico = ISNULL(kardexSum.SumaMovimientosKardex, 0) THEN 1 ELSE 0 END AS BIT) AS CuadraConKardex,
        v.Activo AS VarianteActiva,
        p.Activo AS ProductoActivo
    FROM dbo.Variantes AS v
    INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
    INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
    CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(v.IDVariante) AS disp
    OUTER APPLY (
        SELECT SUM(
            CASE
                WHEN k.TipoMovimiento IN ('AJUSTE_ENTRADA', 'DEVOLUCION') THEN k.Cantidad
                WHEN k.TipoMovimiento IN ('VENTA', 'AJUSTE_SALIDA') THEN -k.Cantidad
                ELSE 0
            END
        ) AS SumaMovimientosKardex
        FROM dbo.Kardex AS k
        WHERE k.IDVariante = v.IDVariante
    ) AS kardexSum
    WHERE (@IDCategoria IS NULL OR p.IDCategoria = @IDCategoria)
      AND (
          @Busqueda IS NULL
          OR v.SKU LIKE '%' + @Busqueda + '%'
          OR v.NombreVariante LIKE N'%' + @Busqueda + N'%'
          OR p.NombreProducto LIKE N'%' + @Busqueda + N'%'
      )
      AND (@SoloBajoStock = 0 OR disp.StockDisponible <= @UmbralBajoStock)
    ORDER BY disp.StockDisponible ASC, v.IDVariante ASC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO
