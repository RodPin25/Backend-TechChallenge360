-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 06_sp_carrito_compras.sql
-- DESCRIPCIÓN: Procedimientos almacenados para la gestión del Carrito de
--              Compras (usuarios autenticados e invitados), validación de
--              existencia disponible y fusión de sesión (RF-01, RF-04).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- NOTA: Precios en Quetzales (GTQ) con IVA del 12% incluido. Tipos DECIMAL(12,2).
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 4: CARRITO DE COMPRAS (RF-04)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SP_Carrito_ObtenerDetalle
-- Obtiene (o crea si no existe) el carrito con Estado = 'ACTIVO' para un
-- @IDUsuario o un @TokenInvitado.
-- Devuelve 2 recordsets:
--   1) Encabezado del carrito con Subtotal, Descuento (si se envía @CodigoCupon),
--      Total y desglose exacto del 12% de IVA sin errores de redondeo.
--   2) Líneas del carrito con PrecioUnitario, SubtotalLinea y StockDisponible.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Carrito_ObtenerDetalle
    @IDUsuario INT = NULL,
    @TokenInvitado VARCHAR(100) = NULL,
    @CodigoCupon VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @TokenInvitado = NULLIF(LTRIM(RTRIM(@TokenInvitado)), '');
        SET @CodigoCupon = NULLIF(LTRIM(RTRIM(UPPER(@CodigoCupon))), '');

        IF @IDUsuario IS NULL AND @TokenInvitado IS NULL
            ;THROW 50041, 'Debe especificar un usuario autenticado o un token de invitado para consultar el carrito.', 1;

        DECLARE @IDCarrito INT;

        IF @IDUsuario IS NOT NULL
        BEGIN
            SELECT TOP (1) @IDCarrito = IDCarrito
            FROM dbo.Carritos
            WHERE IDUsuario = @IDUsuario
              AND Estado = 'ACTIVO'
            ORDER BY IDCarrito DESC;
        END
        ELSE
        BEGIN
            SELECT TOP (1) @IDCarrito = IDCarrito
            FROM dbo.Carritos
            WHERE TokenInvitado = @TokenInvitado
              AND IDUsuario IS NULL
              AND Estado = 'ACTIVO'
            ORDER BY IDCarrito DESC;
        END

        -- Si no existe un carrito activo para la sesión, crearlo de forma transparente
        IF @IDCarrito IS NULL
        BEGIN
            BEGIN TRANSACTION;

            INSERT INTO dbo.Carritos (
                IDUsuario,
                TokenInvitado,
                Estado,
                FechaCreacion,
                FechaActualizacion
            )
            VALUES (
                @IDUsuario,
                CASE WHEN @IDUsuario IS NULL THEN @TokenInvitado ELSE NULL END,
                'ACTIVO',
                SYSDATETIME(),
                SYSDATETIME()
            );

            SET @IDCarrito = SCOPE_IDENTITY();

            COMMIT TRANSACTION;
        END

        -- Calcular Subtotal del carrito e identificar subtotal por categoría para cupones
        DECLARE @TotalItems INT = 0;
        DECLARE @TotalUnidades INT = 0;
        DECLARE @Subtotal DECIMAL(12,2) = 0.00;
        DECLARE @IDCategoriaCupon INT = NULL;
        DECLARE @SubtotalCategoriaElegible DECIMAL(12,2) = 0.00;

        IF @CodigoCupon IS NOT NULL
        BEGIN
            SELECT @IDCategoriaCupon = IDCategoria
            FROM dbo.Cupones
            WHERE Codigo = @CodigoCupon;
        END

        SELECT
            @TotalItems = COUNT(cd.IDCarritoDetalle),
            @TotalUnidades = ISNULL(SUM(cd.Cantidad), 0),
            @Subtotal = CAST(ISNULL(SUM(CAST(cd.Cantidad AS DECIMAL(12,2)) * v.Precio), 0.00) AS DECIMAL(12,2)),
            @SubtotalCategoriaElegible = CAST(
                ISNULL(
                    SUM(
                        CASE
                            WHEN @IDCategoriaCupon IS NOT NULL AND p.IDCategoria = @IDCategoriaCupon
                                THEN CAST(cd.Cantidad AS DECIMAL(12,2)) * v.Precio
                            ELSE 0.00
                        END
                    ),
                    0.00
                )
                AS DECIMAL(12,2)
            )
        FROM dbo.CarritoDetalle AS cd
        INNER JOIN dbo.Variantes AS v ON v.IDVariante = cd.IDVariante
        INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
        WHERE cd.IDCarrito = @IDCarrito;

        -- Evaluar cupón si fue proporcionado
        DECLARE @IDCupon INT = NULL;
        DECLARE @CuponValido BIT = 0;
        DECLARE @MensajeCupon NVARCHAR(200) = NULL;
        DECLARE @MontoDescuento DECIMAL(12,2) = 0.00;
        DECLARE @Total DECIMAL(12,2) = @Subtotal;

        IF @CodigoCupon IS NOT NULL AND @Subtotal > 0.00
        BEGIN
            SELECT
                @IDCupon = calc.IDCupon,
                @CuponValido = calc.EsValido,
                @MensajeCupon = calc.MensajeValidacion,
                @MontoDescuento = calc.MontoDescuento,
                @Total = calc.TotalConDescuento
            FROM dbo.FU_Cupones_CalculoDescuento(
                @CodigoCupon,
                @IDUsuario,
                @Subtotal,
                @SubtotalCategoriaElegible
            ) AS calc;
        END

        -- Recordset 1: Encabezado del carrito y desglose financiero exacto en DECIMAL(12,2)
        SELECT
            c.IDCarrito,
            c.IDUsuario,
            c.TokenInvitado,
            c.Estado,
            c.FechaCreacion,
            c.FechaActualizacion,
            @TotalItems AS TotalItems,
            @TotalUnidades AS TotalUnidades,
            @Subtotal AS Subtotal,
            @IDCupon AS IDCupon,
            @CodigoCupon AS CodigoCupon,
            @CuponValido AS CuponValido,
            @MensajeCupon AS MensajeCupon,
            @MontoDescuento AS MontoDescuento,
            iva.MontoSinIVA AS TotalSinIVA,
            iva.MontoIVA AS MontoIVA,
            @Total AS Total
        FROM dbo.Carritos AS c
        CROSS APPLY dbo.FU_Finanzas_DesgloseIVA(@Total) AS iva
        WHERE c.IDCarrito = @IDCarrito;

        -- Recordset 2: Detalle de líneas del carrito
        SELECT
            cd.IDCarritoDetalle,
            cd.IDCarrito,
            cd.IDVariante,
            v.SKU,
            v.NombreVariante,
            p.IDProducto,
            p.NombreProducto,
            cat.IDCategoria,
            cat.NombreCategoria,
            v.Precio AS PrecioUnitario,
            cd.Cantidad,
            CAST(CAST(cd.Cantidad AS DECIMAL(12,2)) * v.Precio AS DECIMAL(12,2)) AS SubtotalLinea,
            disp.StockFisico,
            disp.StockReservado,
            disp.StockDisponible,
            CAST(
                CASE
                    WHEN v.Activo = 1 AND p.Activo = 1 AND cat.Activo = 1 AND disp.StockDisponible >= cd.Cantidad
                        THEN 1
                    ELSE 0
                END
                AS BIT
            ) AS StockSuficiente,
            cd.FechaAgregado
        FROM dbo.CarritoDetalle AS cd
        INNER JOIN dbo.Variantes AS v ON v.IDVariante = cd.IDVariante
        INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
        INNER JOIN dbo.Categorias AS cat ON cat.IDCategoria = p.IDCategoria
        CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(v.IDVariante) AS disp
        WHERE cd.IDCarrito = @IDCarrito
        ORDER BY cd.FechaAgregado ASC, cd.IDCarritoDetalle ASC;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2. SP_Carrito_AgregarOModificarItem
-- Agrega una variante al carrito o modifica su cantidad.
-- @ModoOperacion:
--   - 'SUMAR': Suma @Cantidad a la cantidad ya existente en el carrito.
--   - 'FIJAR': Establece exactamente @Cantidad en la línea del carrito.
-- Cumple el criterio de aceptación RF-04:
--   "No se puede agregar más cantidad que la existencia disponible."
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Carrito_AgregarOModificarItem
    @IDVariante INT,
    @Cantidad INT,
    @IDUsuario INT = NULL,
    @TokenInvitado VARCHAR(100) = NULL,
    @ModoOperacion VARCHAR(15) = 'SUMAR' -- 'SUMAR' | 'FIJAR'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @TokenInvitado = NULLIF(LTRIM(RTRIM(@TokenInvitado)), '');
        SET @ModoOperacion = UPPER(LTRIM(RTRIM(ISNULL(@ModoOperacion, 'SUMAR'))));

        IF @IDUsuario IS NULL AND @TokenInvitado IS NULL
            ;THROW 50041, 'Debe especificar un usuario autenticado o un token de invitado.', 1;

        IF @Cantidad <= 0
            ;THROW 50042, 'La cantidad del producto en el carrito debe ser mayor a cero.', 1;

        IF @ModoOperacion NOT IN ('SUMAR', 'FIJAR')
            ;THROW 50043, 'El modo de operación debe ser SUMAR o FIJAR.', 1;

        -- 1. Obtener o crear el carrito activo del usuario o invitado
        DECLARE @IDCarrito INT;

        IF @IDUsuario IS NOT NULL
        BEGIN
            SELECT TOP (1) @IDCarrito = IDCarrito
            FROM dbo.Carritos WITH (UPDLOCK, ROWLOCK)
            WHERE IDUsuario = @IDUsuario
              AND Estado = 'ACTIVO'
            ORDER BY IDCarrito DESC;
        END
        ELSE
        BEGIN
            SELECT TOP (1) @IDCarrito = IDCarrito
            FROM dbo.Carritos WITH (UPDLOCK, ROWLOCK)
            WHERE TokenInvitado = @TokenInvitado
              AND IDUsuario IS NULL
              AND Estado = 'ACTIVO'
            ORDER BY IDCarrito DESC;
        END

        IF @IDCarrito IS NULL
        BEGIN
            INSERT INTO dbo.Carritos (
                IDUsuario,
                TokenInvitado,
                Estado,
                FechaCreacion,
                FechaActualizacion
            )
            VALUES (
                @IDUsuario,
                CASE WHEN @IDUsuario IS NULL THEN @TokenInvitado ELSE NULL END,
                'ACTIVO',
                SYSDATETIME(),
                SYSDATETIME()
            );

            SET @IDCarrito = SCOPE_IDENTITY();
        END

        -- 2. Verificar que la variante, producto y categoría estén activos
        DECLARE @StockFisico INT;
        DECLARE @VarianteActiva BIT;
        DECLARE @SKU VARCHAR(50);
        DECLARE @NombreVariante NVARCHAR(100);

        SELECT
            @StockFisico = v.StockFisico,
            @SKU = v.SKU,
            @NombreVariante = v.NombreVariante,
            @VarianteActiva = CASE WHEN v.Activo = 1 AND p.Activo = 1 AND c.Activo = 1 THEN 1 ELSE 0 END
        FROM dbo.Variantes AS v
        INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
        INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
        WHERE v.IDVariante = @IDVariante;

        IF @StockFisico IS NULL
            ;THROW 50019, 'La variante seleccionada no existe.', 1;

        IF @VarianteActiva = 0
            ;THROW 50032, 'El producto o variante seleccionada no se encuentra disponible para la venta.', 1;

        -- 3. Liberar reservas expiradas de la variante antes de validar disponibilidad
        UPDATE dbo.ReservasExistencia
        SET Estado = 'ACTIVA' -- No-op placeholder evitado: liberar directamente las expiradas
        WHERE 1 = 0;

        UPDATE dbo.ReservasExistencia
        SET Estado = 'LIBERADA'
        WHERE IDVariante = @IDVariante
          AND Estado = 'ACTIVA'
          AND FechaExpiracion <= SYSDATETIME();

        -- 4. Calcular cantidad final que tendría el ítem en el carrito
        DECLARE @IDCarritoDetalleExistente INT;
        DECLARE @CantidadActualEnCarrito INT = 0;

        SELECT
            @IDCarritoDetalleExistente = IDCarritoDetalle,
            @CantidadActualEnCarrito = Cantidad
        FROM dbo.CarritoDetalle WITH (UPDLOCK, ROWLOCK)
        WHERE IDCarrito = @IDCarrito
          AND IDVariante = @IDVariante;

        DECLARE @CantidadFinal INT = CASE
            WHEN @IDCarritoDetalleExistente IS NOT NULL AND @ModoOperacion = 'SUMAR'
                THEN @CantidadActualEnCarrito + @Cantidad
            ELSE @Cantidad
        END;

        -- 5. Calcular existencia disponible para este cliente (excluyendo reservas propias vigentes)
        DECLARE @ReservadoPorOtros INT = 0;

        SELECT @ReservadoPorOtros = ISNULL(SUM(r.Cantidad), 0)
        FROM dbo.ReservasExistencia AS r
        WHERE r.IDVariante = @IDVariante
          AND r.Estado = 'ACTIVA'
          AND r.FechaExpiracion > SYSDATETIME()
          AND NOT (
              (@IDUsuario IS NOT NULL AND r.IDUsuario = @IDUsuario)
              OR (@IDUsuario IS NULL AND @TokenInvitado IS NOT NULL AND r.TokenSesion = @TokenInvitado)
          );

        DECLARE @StockDisponibleCliente INT = @StockFisico - @ReservadoPorOtros;
        IF @StockDisponibleCliente < 0 SET @StockDisponibleCliente = 0;

        IF @CantidadFinal > @StockDisponibleCliente
        BEGIN
            DECLARE @MensajeStockCarrito NVARCHAR(250) = CONCAT(
                N'No se puede agregar más cantidad que la existencia disponible para "',
                @NombreVariante, N'" (SKU: ', @SKU, N'). Solicitado: ', @CantidadFinal,
                N', Disponible: ', @StockDisponibleCliente, N'.'
            );
            ;THROW 50044, @MensajeStockCarrito, 1;
        END

        -- 6. Insertar o actualizar en CarritoDetalle y refrescar FechaActualizacion del carrito
        IF @IDCarritoDetalleExistente IS NOT NULL
        BEGIN
            UPDATE dbo.CarritoDetalle
            SET Cantidad = @CantidadFinal
            WHERE IDCarritoDetalle = @IDCarritoDetalleExistente;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.CarritoDetalle (
                IDCarrito,
                IDVariante,
                Cantidad,
                FechaAgregado
            )
            VALUES (
                @IDCarrito,
                @IDVariante,
                @CantidadFinal,
                SYSDATETIME()
            );
        END

        UPDATE dbo.Carritos
        SET FechaActualizacion = SYSDATETIME()
        WHERE IDCarrito = @IDCarrito;

        COMMIT TRANSACTION;

        -- Retornar estado completo del carrito actualizado
        EXEC dbo.SP_Carrito_ObtenerDetalle
            @IDUsuario = @IDUsuario,
            @TokenInvitado = @TokenInvitado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 3. SP_Carrito_EliminarItem
-- Elimina una variante del carrito activo validando estrictamente que el
-- carrito pertenezca al usuario o sesión invitada (RF-01, RF-04).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Carrito_EliminarItem
    @IDVariante INT,
    @IDUsuario INT = NULL,
    @TokenInvitado VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @TokenInvitado = NULLIF(LTRIM(RTRIM(@TokenInvitado)), '');

        IF @IDUsuario IS NULL AND @TokenInvitado IS NULL
            ;THROW 50041, 'Debe especificar un usuario autenticado o un token de invitado.', 1;

        DECLARE @IDCarrito INT;

        IF @IDUsuario IS NOT NULL
        BEGIN
            SELECT TOP (1) @IDCarrito = IDCarrito
            FROM dbo.Carritos
            WHERE IDUsuario = @IDUsuario
              AND Estado = 'ACTIVO'
            ORDER BY IDCarrito DESC;
        END
        ELSE
        BEGIN
            SELECT TOP (1) @IDCarrito = IDCarrito
            FROM dbo.Carritos
            WHERE TokenInvitado = @TokenInvitado
              AND IDUsuario IS NULL
              AND Estado = 'ACTIVO'
            ORDER BY IDCarrito DESC;
        END

        IF @IDCarrito IS NULL
            ;THROW 50034, 'No se encontró un carrito activo para el usuario o sesión.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.CarritoDetalle
            WHERE IDCarrito = @IDCarrito
              AND IDVariante = @IDVariante
        )
            ;THROW 50045, 'El producto especificado no se encuentra en el carrito.', 1;

        DELETE FROM dbo.CarritoDetalle
        WHERE IDCarrito = @IDCarrito
          AND IDVariante = @IDVariante;

        -- Si tenía una reserva activa sobre esta variante, liberarla
        UPDATE dbo.ReservasExistencia
        SET Estado = 'LIBERADA'
        WHERE IDVariante = @IDVariante
          AND Estado = 'ACTIVA'
          AND (
              (@IDUsuario IS NOT NULL AND IDUsuario = @IDUsuario)
              OR (@IDUsuario IS NULL AND @TokenInvitado IS NOT NULL AND TokenSesion = @TokenInvitado)
          );

        UPDATE dbo.Carritos
        SET FechaActualizacion = SYSDATETIME()
        WHERE IDCarrito = @IDCarrito;

        COMMIT TRANSACTION;

        EXEC dbo.SP_Carrito_ObtenerDetalle
            @IDUsuario = @IDUsuario,
            @TokenInvitado = @TokenInvitado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 4. SP_Carrito_Vaciar
-- Elimina todos los productos del carrito activo del cliente o invitado y
-- libera cualquier reserva temporal activa asociada.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Carrito_Vaciar
    @IDUsuario INT = NULL,
    @TokenInvitado VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @TokenInvitado = NULLIF(LTRIM(RTRIM(@TokenInvitado)), '');

        IF @IDUsuario IS NULL AND @TokenInvitado IS NULL
            ;THROW 50041, 'Debe especificar un usuario autenticado o un token de invitado.', 1;

        DECLARE @IDCarrito INT;

        IF @IDUsuario IS NOT NULL
        BEGIN
            SELECT TOP (1) @IDCarrito = IDCarrito
            FROM dbo.Carritos
            WHERE IDUsuario = @IDUsuario
              AND Estado = 'ACTIVO'
            ORDER BY IDCarrito DESC;
        END
        ELSE
        BEGIN
            SELECT TOP (1) @IDCarrito = IDCarrito
            FROM dbo.Carritos
            WHERE TokenInvitado = @TokenInvitado
              AND IDUsuario IS NULL
              AND Estado = 'ACTIVO'
            ORDER BY IDCarrito DESC;
        END

        IF @IDCarrito IS NOT NULL
        BEGIN
            DELETE FROM dbo.CarritoDetalle
            WHERE IDCarrito = @IDCarrito;

            UPDATE dbo.Carritos
            SET FechaActualizacion = SYSDATETIME()
            WHERE IDCarrito = @IDCarrito;
        END

        -- Liberar reservas temporales activas de esta sesión/usuario
        UPDATE dbo.ReservasExistencia
        SET Estado = 'LIBERADA'
        WHERE Estado = 'ACTIVA'
          AND (
              (@IDUsuario IS NOT NULL AND IDUsuario = @IDUsuario)
              OR (@IDUsuario IS NULL AND @TokenInvitado IS NOT NULL AND TokenSesion = @TokenInvitado)
          );

        COMMIT TRANSACTION;

        EXEC dbo.SP_Carrito_ObtenerDetalle
            @IDUsuario = @IDUsuario,
            @TokenInvitado = @TokenInvitado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 5. SP_Carrito_FusionarInvitadoAUsuario
-- Cuando un visitante con @TokenInvitado inicia sesión o se registra con
-- @IDUsuario, fusiona los ítems de su carrito de invitado hacia su carrito
-- activo de usuario autenticado, respetando el tope de existencia disponible
-- (RF-04).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Carrito_FusionarInvitadoAUsuario
    @IDUsuario INT,
    @TokenInvitado VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @TokenInvitado = NULLIF(LTRIM(RTRIM(@TokenInvitado)), '');

        IF @IDUsuario IS NULL OR @TokenInvitado IS NULL
            ;THROW 50046, 'Se requiere tanto el IDUsuario como el TokenInvitado para fusionar el carrito.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IDUsuario = @IDUsuario AND Activo = 1)
            ;THROW 50004, 'El usuario autenticado no existe o está inactivo.', 1;

        DECLARE @IDCarritoInvitado INT;
        DECLARE @IDCarritoUsuario INT;

        SELECT TOP (1) @IDCarritoInvitado = IDCarrito
        FROM dbo.Carritos WITH (UPDLOCK, ROWLOCK)
        WHERE TokenInvitado = @TokenInvitado
          AND IDUsuario IS NULL
          AND Estado = 'ACTIVO'
        ORDER BY IDCarrito DESC;

        SELECT TOP (1) @IDCarritoUsuario = IDCarrito
        FROM dbo.Carritos WITH (UPDLOCK, ROWLOCK)
        WHERE IDUsuario = @IDUsuario
          AND Estado = 'ACTIVO'
        ORDER BY IDCarrito DESC;

        IF @IDCarritoInvitado IS NOT NULL
        BEGIN
            -- Caso A: El usuario aún no tenía carrito propio -> reasignarle directamente el carrito invitado
            IF @IDCarritoUsuario IS NULL
            BEGIN
                UPDATE dbo.Carritos
                SET IDUsuario = @IDUsuario,
                    TokenInvitado = NULL,
                    FechaActualizacion = SYSDATETIME()
                WHERE IDCarrito = @IDCarritoInvitado;

                SET @IDCarritoUsuario = @IDCarritoInvitado;
            END
            ELSE
            BEGIN
                -- Caso B: Ambos carritos existen -> fusionar líneas respetando StockDisponible
                -- Actualizar cantidades en líneas que ya existían en el carrito del usuario
                UPDATE cdu
                SET cdu.Cantidad = CASE
                    WHEN (cdu.Cantidad + cdi.Cantidad) > disp.StockDisponible
                        THEN CASE WHEN disp.StockDisponible >= cdu.Cantidad THEN disp.StockDisponible ELSE cdu.Cantidad END
                    ELSE (cdu.Cantidad + cdi.Cantidad)
                END
                FROM dbo.CarritoDetalle AS cdu
                INNER JOIN dbo.CarritoDetalle AS cdi
                    ON cdi.IDCarrito = @IDCarritoInvitado
                   AND cdi.IDVariante = cdu.IDVariante
                CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(cdu.IDVariante) AS disp
                WHERE cdu.IDCarrito = @IDCarritoUsuario;

                -- Insertar líneas nuevas que solo estaban en el carrito invitado y tienen stock > 0
                INSERT INTO dbo.CarritoDetalle (
                    IDCarrito,
                    IDVariante,
                    Cantidad,
                    FechaAgregado
                )
                SELECT
                    @IDCarritoUsuario,
                    cdi.IDVariante,
                    CASE WHEN cdi.Cantidad > disp.StockDisponible THEN disp.StockDisponible ELSE cdi.Cantidad END,
                    cdi.FechaAgregado
                FROM dbo.CarritoDetalle AS cdi
                CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(cdi.IDVariante) AS disp
                WHERE cdi.IDCarrito = @IDCarritoInvitado
                  AND disp.StockDisponible > 0
                  AND NOT EXISTS (
                      SELECT 1
                      FROM dbo.CarritoDetalle AS cdu
                      WHERE cdu.IDCarrito = @IDCarritoUsuario
                        AND cdu.IDVariante = cdi.IDVariante
                  );

                -- Limpiar detalle del carrito invitado y marcarlo como CONVERTIDO
                DELETE FROM dbo.CarritoDetalle
                WHERE IDCarrito = @IDCarritoInvitado;

                UPDATE dbo.Carritos
                SET Estado = 'CONVERTIDO',
                    FechaActualizacion = SYSDATETIME()
                WHERE IDCarrito = @IDCarritoInvitado;

                UPDATE dbo.Carritos
                SET FechaActualizacion = SYSDATETIME()
                WHERE IDCarrito = @IDCarritoUsuario;
            END

            -- Transferir reservas temporales activas del token invitado al usuario autenticado
            UPDATE dbo.ReservasExistencia
            SET IDUsuario = @IDUsuario,
                TokenSesion = NULL
            WHERE TokenSesion = @TokenInvitado
              AND Estado = 'ACTIVA';
        END

        COMMIT TRANSACTION;

        EXEC dbo.SP_Carrito_ObtenerDetalle
            @IDUsuario = @IDUsuario;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
