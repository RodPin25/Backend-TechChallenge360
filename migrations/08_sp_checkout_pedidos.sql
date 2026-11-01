-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 08_sp_checkout_pedidos.sql
-- DESCRIPCIÓN: Procedimientos almacenados para Checkout Atómico e Idempotente,
--              congelación de precios, consumo concurrente de cupones/stock y
--              ciclo de vida del pedido con reintegro en cancelación
--              (RF-01, RF-03, RF-05, RF-06, RF-07, RF-08, RF-09).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- NOTA: Precios y montos en Quetzales (GTQ) con IVA del 12% incluido.
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 6: CHECKOUT ATÓMICO E IDEMPOTENTE Y GESTIÓN DE PEDIDOS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SP_Pedidos_ObtenerDetalle
-- Devuelve 4 recordsets con toda la información de un pedido:
--   1) Encabezado del pedido, cliente, dirección y cupón aplicado
--   2) Líneas del pedido con precios congelados y saldo disponible de devolución
--   3) Pagos asociados al pedido
--   4) Historial cronológico de cambios de estado
-- Valida estrictamente el control de acceso por rol (RF-01: un Cliente solo
-- puede consultar sus propios pedidos).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Pedidos_ObtenerDetalle
    @IDPedido INT,
    @IDUsuarioSolicitante INT,
    @FueRespuestaIdempotente BIT = 0
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

    DECLARE @IDPropietarioPedido INT;
    SELECT @IDPropietarioPedido = IDUsuario
    FROM dbo.Pedidos
    WHERE IDPedido = @IDPedido;

    IF @IDPropietarioPedido IS NULL
        ;THROW 50070, 'El pedido solicitado no existe.', 1;

    -- Prevención de IDOR (RF-01): un Cliente jamás puede consultar pedidos de otro cliente
    IF @RolSolicitante = 'Cliente' AND @IDPropietarioPedido <> @IDUsuarioSolicitante
        ;THROW 50071, 'No tiene permisos para consultar un pedido que pertenece a otro cliente.', 1;

    -- Recordset 1: Encabezado del pedido
    SELECT
        p.IDPedido,
        p.IDUsuario,
        u.NombreCompleto AS NombreCliente,
        u.Correo AS CorreoCliente,
        u.Telefono AS TelefonoCliente,
        p.IDDireccion,
        p.DireccionEntregaTexto,
        p.IDCupon,
        c.Codigo AS CodigoCupon,
        c.TipoDescuento,
        p.IdempotencyKey,
        p.EstadoPedido,
        p.Subtotal,
        p.MontoDescuento,
        iva.MontoSinIVA AS TotalSinIVA,
        p.MontoIVA,
        p.Total,
        p.FechaCreacion,
        @FueRespuestaIdempotente AS FueRespuestaIdempotente
    FROM dbo.Pedidos AS p
    INNER JOIN dbo.Usuarios AS u ON u.IDUsuario = p.IDUsuario
    LEFT JOIN dbo.Cupones AS c ON c.IDCupon = p.IDCupon
    CROSS APPLY dbo.FU_Finanzas_DesgloseIVA(p.Total) AS iva
    WHERE p.IDPedido = @IDPedido;

    -- Recordset 2: Detalle de líneas con precios congelados y saldo de devolución
    SELECT
        pd.IDPedidoDetalle,
        pd.IDPedido,
        pd.IDVariante,
        v.SKU,
        v.NombreVariante,
        prod.IDProducto,
        prod.NombreProducto,
        cat.IDCategoria,
        cat.NombreCategoria,
        pd.Cantidad,
        pd.PrecioUnitarioCongelado,
        pd.DescuentoAplicado,
        pd.SubtotalLinea,
        saldo.CantidadYaDevuelta,
        saldo.CantidadDisponibleDevolver
    FROM dbo.PedidoDetalle AS pd
    INNER JOIN dbo.Variantes AS v ON v.IDVariante = pd.IDVariante
    INNER JOIN dbo.Productos AS prod ON prod.IDProducto = v.IDProducto
    INNER JOIN dbo.Categorias AS cat ON cat.IDCategoria = prod.IDCategoria
    CROSS APPLY dbo.FU_Pedidos_SaldoDevolucionLinea(pd.IDPedido, pd.IDVariante) AS saldo
    WHERE pd.IDPedido = @IDPedido
    ORDER BY pd.IDPedidoDetalle ASC;

    -- Recordset 3: Pagos registrados
    SELECT
        pg.IDPago,
        pg.IDPedido,
        pg.MetodoPago,
        pg.TransaccionId,
        pg.Monto,
        pg.Estado,
        pg.FechaPago
    FROM dbo.Pagos AS pg
    WHERE pg.IDPedido = @IDPedido
    ORDER BY pg.FechaPago DESC, pg.IDPago DESC;

    -- Recordset 4: Historial de estados del pedido
    SELECT
        h.IDHistorialEstado,
        h.IDPedido,
        h.IDUsuario,
        u.NombreCompleto AS UsuarioResponsable,
        r.NombreRol AS RolResponsable,
        h.EstadoAnterior,
        h.EstadoNuevo,
        h.FechaHora
    FROM dbo.HistorialEstadosPedido AS h
    INNER JOIN dbo.Usuarios AS u ON u.IDUsuario = h.IDUsuario
    INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
    WHERE h.IDPedido = @IDPedido
    ORDER BY h.FechaHora ASC, h.IDHistorialEstado ASC;
END;
GO

-- ----------------------------------------------------------------------------
-- 2. SP_Pedidos_CrearCheckout
-- Ejecuta de forma atómica e idempotente el proceso completo de Checkout:
--   1) Verifica IdempotencyKey: si ya existe el pedido, devuelve el resultado
--      previo sin volver a cobrar ni duplicar registros (RF-06).
--   2) Verifica que la dirección pertenezca al cliente (RF-01).
--   3) Bloquea en orden ascendente las variantes del carrito (UPDLOCK, ROWLOCK),
--      barre reservas expiradas y valida existencia disponible real (RF-03, RF-06).
--   4) Si se incluye cupón, bloquea la fila del cupón (UPDLOCK, ROWLOCK),
--      valida vigencia/límites/mínimo y calcula el descuento exacto (RF-05).
--   5) Congela los precios unitarios del catálogo en PedidoDetalle, calcula
--      el desglose exacto del 12% de IVA y crea el Pedido.
--   6) Descuenta StockFisico, inserta movimientos 'VENTA' en Kardex, confirma
--      reservas temporales, registra el uso del cupón, el pago, el historial
--      de estados, convierte el carrito y audita en Bitácora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Pedidos_CrearCheckout
    @IDUsuario INT,
    @IDDireccion INT,
    @IdempotencyKey VARCHAR(64),
    @CodigoCupon VARCHAR(30) = NULL,
    @MetodoPago VARCHAR(30) = 'TARJETA',
    @TransaccionId VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @IdempotencyKey = LTRIM(RTRIM(@IdempotencyKey));
    SET @CodigoCupon = NULLIF(LTRIM(RTRIM(UPPER(@CodigoCupon))), '');
    SET @MetodoPago = ISNULL(NULLIF(LTRIM(RTRIM(UPPER(@MetodoPago))), ''), 'TARJETA');

    IF ISNULL(@IdempotencyKey, '') = ''
        ;THROW 50072, 'La llave de idempotencia (IdempotencyKey) es obligatoria para procesar el checkout.', 1;

    -- 1. VERIFICACIÓN DE IDEMPOTENCIA (fuera o antes de escribir para evitar duplicados)
    DECLARE @IDPedidoExistente INT;
    SELECT @IDPedidoExistente = IDPedido
    FROM dbo.Pedidos
    WHERE IdempotencyKey = @IdempotencyKey;

    IF @IDPedidoExistente IS NOT NULL
    BEGIN
        EXEC dbo.SP_Pedidos_ObtenerDetalle
            @IDPedido = @IDPedidoExistente,
            @IDUsuarioSolicitante = @IDUsuario,
            @FueRespuestaIdempotente = 1;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Doble verificación bajo bloqueo por si dos hilos con la misma IdempotencyKey entraron al mismo milisegundo
        SELECT @IDPedidoExistente = IDPedido
        FROM dbo.Pedidos WITH (UPDLOCK, HOLDLOCK)
        WHERE IdempotencyKey = @IdempotencyKey;

        IF @IDPedidoExistente IS NOT NULL
        BEGIN
            COMMIT TRANSACTION;

            EXEC dbo.SP_Pedidos_ObtenerDetalle
                @IDPedido = @IDPedidoExistente,
                @IDUsuarioSolicitante = @IDUsuario,
                @FueRespuestaIdempotente = 1;
            RETURN;
        END

        -- 2. Validar usuario activo
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IDUsuario = @IDUsuario AND Activo = 1)
            ;THROW 50004, 'El usuario no existe o se encuentra inactivo.', 1;

        -- 3. Validar dirección de entrega perteneciente al cliente (RF-01, RF-06)
        DECLARE @DireccionEntregaTexto NVARCHAR(500);

        SELECT @DireccionEntregaTexto = CONCAT(
            d.DireccionLinea, N', ', d.Municipio, N', ', d.Departamento,
            CASE WHEN NULLIF(LTRIM(RTRIM(d.CodigoPostal)), '') IS NOT NULL THEN CONCAT(N' (CP ', d.CodigoPostal, N')') ELSE N'' END,
            CASE WHEN NULLIF(LTRIM(RTRIM(d.Referencia)), '') IS NOT NULL THEN CONCAT(N' - Ref: ', d.Referencia) ELSE N'' END
        )
        FROM dbo.Direcciones AS d
        WHERE d.IDDireccion = @IDDireccion
          AND d.IDUsuario = @IDUsuario
          AND d.Activo = 1;

        IF @DireccionEntregaTexto IS NULL
            ;THROW 50008, 'La dirección de entrega seleccionada no existe o no pertenece al cliente.', 1;

        -- 4. Obtener carrito activo del usuario con bloqueo
        DECLARE @IDCarrito INT;

        SELECT TOP (1) @IDCarrito = IDCarrito
        FROM dbo.Carritos WITH (UPDLOCK, ROWLOCK)
        WHERE IDUsuario = @IDUsuario
          AND Estado = 'ACTIVO'
        ORDER BY IDCarrito DESC;

        IF @IDCarrito IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.CarritoDetalle WHERE IDCarrito = @IDCarrito)
            ;THROW 50035, 'El carrito de compras está vacío o ya fue procesado.', 1;

        -- 5. Barrido de reservas expiradas sobre las variantes del carrito
        UPDATE r
        SET r.Estado = 'LIBERADA'
        FROM dbo.ReservasExistencia AS r
        INNER JOIN dbo.CarritoDetalle AS cd ON cd.IDVariante = r.IDVariante
        WHERE cd.IDCarrito = @IDCarrito
          AND r.Estado = 'ACTIVA'
          AND r.FechaExpiracion <= SYSDATETIME();

        -- 6. Tabla temporal de trabajo para congelar precios y bloquear variantes en orden de IDVariante ASC
        CREATE TABLE #LineasCheckout (
            NumeroLinea INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            IDVariante INT NOT NULL,
            IDCategoria INT NOT NULL,
            SKU VARCHAR(50) NOT NULL,
            NombreVariante NVARCHAR(100) NOT NULL,
            Cantidad INT NOT NULL,
            PrecioUnitarioCongelado DECIMAL(12,2) NOT NULL,
            SubtotalBrutoLinea DECIMAL(12,2) NOT NULL,
            DescuentoAplicado DECIMAL(12,2) NOT NULL DEFAULT (0.00),
            SubtotalLinea DECIMAL(12,2) NOT NULL,
            StockAnterior INT NOT NULL,
            StockActual INT NOT NULL
        );

        DECLARE @IDVarianteIter INT;
        DECLARE @CantidadIter INT;
        DECLARE @StockFisicoIter INT;
        DECLARE @ReservadoOtrosIter INT;
        DECLARE @PrecioIter DECIMAL(12,2);
        DECLARE @IDCategoriaIter INT;
        DECLARE @SKUIter VARCHAR(50);
        DECLARE @NombreVarianteIter NVARCHAR(100);
        DECLARE @DisponibleVentaIter BIT;

        DECLARE cur_checkout CURSOR LOCAL FAST_FORWARD FOR
            SELECT cd.IDVariante, cd.Cantidad
            FROM dbo.CarritoDetalle AS cd
            WHERE cd.IDCarrito = @IDCarrito
            ORDER BY cd.IDVariante ASC;

        OPEN cur_checkout;
        FETCH NEXT FROM cur_checkout INTO @IDVarianteIter, @CantidadIter;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Bloqueo pesimista sobre la variante para evitar sobreventa (RF-06)
            SELECT
                @StockFisicoIter = v.StockFisico,
                @PrecioIter = v.Precio,
                @SKUIter = v.SKU,
                @NombreVarianteIter = v.NombreVariante,
                @IDCategoriaIter = p.IDCategoria,
                @DisponibleVentaIter = CASE WHEN v.Activo = 1 AND p.Activo = 1 AND c.Activo = 1 THEN 1 ELSE 0 END
            FROM dbo.Variantes AS v WITH (UPDLOCK, ROWLOCK)
            INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
            INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
            WHERE v.IDVariante = @IDVarianteIter;

            IF @DisponibleVentaIter = 0
            BEGIN
                DECLARE @MsgProdInactivo NVARCHAR(250) = CONCAT(
                    N'El producto "', @NombreVarianteIter, N'" (SKU: ', @SKUIter, N') ya no se encuentra disponible para la venta.'
                );
                ;THROW 50032, @MsgProdInactivo, 1;
            END

            -- Calcular reservas activas de OTROS usuarios sobre esta variante
            SELECT @ReservadoOtrosIter = ISNULL(SUM(r.Cantidad), 0)
            FROM dbo.ReservasExistencia AS r WITH (UPDLOCK)
            WHERE r.IDVariante = @IDVarianteIter
              AND r.Estado = 'ACTIVA'
              AND r.FechaExpiracion > SYSDATETIME()
              AND (r.IDUsuario IS NULL OR r.IDUsuario <> @IDUsuario);

            IF (@StockFisicoIter - @ReservadoOtrosIter) < @CantidadIter
            BEGIN
                DECLARE @StockDispMsg INT = CASE WHEN (@StockFisicoIter - @ReservadoOtrosIter) < 0 THEN 0 ELSE (@StockFisicoIter - @ReservadoOtrosIter) END;
                DECLARE @MsgSinStockCheckout NVARCHAR(250) = CONCAT(
                    N'No hay existencia disponible para "', @NombreVarianteIter,
                    N'" (SKU: ', @SKUIter, N'). Solicitado: ', @CantidadIter,
                    N', Disponible: ', @StockDispMsg, N'.'
                );
                ;THROW 50033, @MsgSinStockCheckout, 1;
            END

            DECLARE @SubBruto DECIMAL(12,2) = CAST(CAST(@CantidadIter AS DECIMAL(12,2)) * @PrecioIter AS DECIMAL(12,2));

            INSERT INTO #LineasCheckout (
                IDVariante,
                IDCategoria,
                SKU,
                NombreVariante,
                Cantidad,
                PrecioUnitarioCongelado,
                SubtotalBrutoLinea,
                DescuentoAplicado,
                SubtotalLinea,
                StockAnterior,
                StockActual
            )
            VALUES (
                @IDVarianteIter,
                @IDCategoriaIter,
                @SKUIter,
                @NombreVarianteIter,
                @CantidadIter,
                @PrecioIter,
                @SubBruto,
                0.00,
                @SubBruto,
                @StockFisicoIter,
                (@StockFisicoIter - @CantidadIter)
            );

            FETCH NEXT FROM cur_checkout INTO @IDVarianteIter, @CantidadIter;
        END

        CLOSE cur_checkout;
        DEALLOCATE cur_checkout;

        -- 7. Calcular Subtotal y validar/bloquear Cupón si fue enviado (RF-05)
        DECLARE @SubtotalPedido DECIMAL(12,2) = 0.00;
        SELECT @SubtotalPedido = CAST(ISNULL(SUM(SubtotalBrutoLinea), 0.00) AS DECIMAL(12,2))
        FROM #LineasCheckout;

        DECLARE @IDCuponAplicado INT = NULL;
        DECLARE @IDCategoriaCupon INT = NULL;
        DECLARE @MontoDescuentoPedido DECIMAL(12,2) = 0.00;

        IF @CodigoCupon IS NOT NULL
        BEGIN
            -- Bloqueo pesimista sobre el cupón para respetar LimiteUsosTotal concurrente (RF-05)
            SELECT
                @IDCuponAplicado = IDCupon,
                @IDCategoriaCupon = IDCategoria
            FROM dbo.Cupones WITH (UPDLOCK, ROWLOCK)
            WHERE Codigo = @CodigoCupon;

            DECLARE @SubtotalCatElegible DECIMAL(12,2) = 0.00;

            SELECT @SubtotalCatElegible = CAST(ISNULL(SUM(SubtotalBrutoLinea), 0.00) AS DECIMAL(12,2))
            FROM #LineasCheckout
            WHERE @IDCategoriaCupon IS NOT NULL AND IDCategoria = @IDCategoriaCupon;

            DECLARE @CuponEsValido BIT = 0;
            DECLARE @MensajeErrorCupon NVARCHAR(200);

            SELECT
                @CuponEsValido = calc.EsValido,
                @MensajeErrorCupon = calc.MensajeValidacion,
                @MontoDescuentoPedido = calc.MontoDescuento
            FROM dbo.FU_Cupones_CalculoDescuento(
                @CodigoCupon,
                @IDUsuario,
                @SubtotalPedido,
                @SubtotalCatElegible
            ) AS calc;

            IF @CuponEsValido = 0
                ;THROW 50060, @MensajeErrorCupon, 1;

            -- Prorratear el descuento entre las líneas elegibles en #LineasCheckout sin perder ni un centavo
            IF @MontoDescuentoPedido > 0.00
            BEGIN
                DECLARE @BaseProrrateo DECIMAL(12,2) = CASE
                    WHEN @IDCategoriaCupon IS NULL THEN @SubtotalPedido
                    ELSE @SubtotalCatElegible
                END;

                UPDATE #LineasCheckout
                SET DescuentoAplicado = CASE
                        WHEN @IDCategoriaCupon IS NULL OR IDCategoria = @IDCategoriaCupon
                            THEN CAST(ROUND(@MontoDescuentoPedido * (SubtotalBrutoLinea / @BaseProrrateo), 2) AS DECIMAL(12,2))
                        ELSE 0.00
                    END;

                -- Ajustar diferencia de centavos por redondeo en la última línea elegible
                DECLARE @SumaDescuentoLineas DECIMAL(12,2);
                SELECT @SumaDescuentoLineas = ISNULL(SUM(DescuentoAplicado), 0.00)
                FROM #LineasCheckout;

                DECLARE @DiferenciaCentavos DECIMAL(12,2) = @MontoDescuentoPedido - @SumaDescuentoLineas;

                IF @DiferenciaCentavos <> 0.00
                BEGIN
                    DECLARE @UltimaLineaElegible INT;
                    SELECT TOP (1) @UltimaLineaElegible = NumeroLinea
                    FROM #LineasCheckout
                    WHERE (@IDCategoriaCupon IS NULL OR IDCategoria = @IDCategoriaCupon)
                    ORDER BY SubtotalBrutoLinea DESC, NumeroLinea DESC;

                    UPDATE #LineasCheckout
                    SET DescuentoAplicado = DescuentoAplicado + @DiferenciaCentavos
                    WHERE NumeroLinea = @UltimaLineaElegible;
                END

                UPDATE #LineasCheckout
                SET SubtotalLinea = SubtotalBrutoLinea - DescuentoAplicado;
            END
        END

        -- 8. Calcular Total e IVA (12% incluido) usando FU_Finanzas_DesgloseIVA
        DECLARE @TotalPedido DECIMAL(12,2) = @SubtotalPedido - @MontoDescuentoPedido;
        IF @TotalPedido < 0.00 SET @TotalPedido = 0.00;

        DECLARE @MontoIVAPedido DECIMAL(12,2) = 0.00;
        SELECT @MontoIVAPedido = MontoIVA
        FROM dbo.FU_Finanzas_DesgloseIVA(@TotalPedido);

        DECLARE @EstadoInicialPedido VARCHAR(30) = CASE
            WHEN @MetodoPago = 'PENDIENTE_PAGO' THEN 'PENDIENTE'
            ELSE 'PAGADO'
        END;

        -- 9. Insertar el encabezado en dbo.Pedidos
        INSERT INTO dbo.Pedidos (
            IDUsuario,
            IDDireccion,
            IDCupon,
            IdempotencyKey,
            EstadoPedido,
            Subtotal,
            MontoDescuento,
            MontoIVA,
            Total,
            DireccionEntregaTexto,
            FechaCreacion
        )
        VALUES (
            @IDUsuario,
            @IDDireccion,
            @IDCuponAplicado,
            @IdempotencyKey,
            @EstadoInicialPedido,
            @SubtotalPedido,
            @MontoDescuentoPedido,
            @MontoIVAPedido,
            @TotalPedido,
            @DireccionEntregaTexto,
            SYSDATETIME()
        );

        DECLARE @IDPedidoNuevo INT = SCOPE_IDENTITY();

        -- 10. Insertar el detalle del pedido con precios congelados (RF-02, RF-06)
        INSERT INTO dbo.PedidoDetalle (
            IDPedido,
            IDVariante,
            Cantidad,
            PrecioUnitarioCongelado,
            DescuentoAplicado,
            SubtotalLinea
        )
        SELECT
            @IDPedidoNuevo,
            lc.IDVariante,
            lc.Cantidad,
            lc.PrecioUnitarioCongelado,
            lc.DescuentoAplicado,
            lc.SubtotalLinea
        FROM #LineasCheckout AS lc
        ORDER BY lc.NumeroLinea ASC;

        -- 11. Actualizar StockFisico en dbo.Variantes
        UPDATE v
        SET v.StockFisico = lc.StockActual
        FROM dbo.Variantes AS v
        INNER JOIN #LineasCheckout AS lc ON lc.IDVariante = v.IDVariante;

        -- 12. Insertar movimientos 'VENTA' en dbo.Kardex por cada variante (RF-03)
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
        SELECT
            lc.IDVariante,
            'VENTA',
            lc.Cantidad,
            lc.StockAnterior,
            lc.StockActual,
            @IDPedidoNuevo,
            NULL,
            @IDUsuario,
            CONCAT(N'Salida por venta confirmada en Pedido #', @IDPedidoNuevo),
            SYSDATETIME()
        FROM #LineasCheckout AS lc
        ORDER BY lc.NumeroLinea ASC;

        -- 13. Confirmar las reservas temporales activas del usuario para estas variantes
        UPDATE r
        SET r.Estado = 'CONFIRMADA'
        FROM dbo.ReservasExistencia AS r
        INNER JOIN #LineasCheckout AS lc ON lc.IDVariante = r.IDVariante
        WHERE r.IDUsuario = @IDUsuario
          AND r.Estado = 'ACTIVA';

        -- 14. Si se usó cupón, incrementar UsosActuales y registrar en dbo.CuponesUso (RF-05)
        IF @IDCuponAplicado IS NOT NULL
        BEGIN
            UPDATE dbo.Cupones
            SET UsosActuales = UsosActuales + 1
            WHERE IDCupon = @IDCuponAplicado;

            INSERT INTO dbo.CuponesUso (
                IDCupon,
                IDUsuario,
                IDPedido,
                FechaUso
            )
            VALUES (
                @IDCuponAplicado,
                @IDUsuario,
                @IDPedidoNuevo,
                SYSDATETIME()
            );
        END

        -- 15. Registrar transacción de pago en dbo.Pagos
        DECLARE @TransaccionFinal VARCHAR(100) = ISNULL(
            NULLIF(LTRIM(RTRIM(@TransaccionId)), ''),
            CONCAT('TXN-', @IDPedidoNuevo, '-', LEFT(@IdempotencyKey, 16))
        );

        INSERT INTO dbo.Pagos (
            IDPedido,
            MetodoPago,
            TransaccionId,
            Monto,
            Estado,
            FechaPago
        )
        VALUES (
            @IDPedidoNuevo,
            @MetodoPago,
            @TransaccionFinal,
            @TotalPedido,
            CASE WHEN @EstadoInicialPedido = 'PAGADO' THEN 'APROBADO' ELSE 'PENDIENTE' END,
            SYSDATETIME()
        );

        -- 16. Registrar trazabilidad en dbo.HistorialEstadosPedido (RF-07)
        INSERT INTO dbo.HistorialEstadosPedido (
            IDPedido,
            IDUsuario,
            EstadoAnterior,
            EstadoNuevo,
            FechaHora
        )
        VALUES (
            @IDPedidoNuevo,
            @IDUsuario,
            'PENDIENTE',
            @EstadoInicialPedido,
            SYSDATETIME()
        );

        -- 17. Marcar el carrito como 'CONVERTIDO' y limpiar sus líneas temporales
        DELETE FROM dbo.CarritoDetalle
        WHERE IDCarrito = @IDCarrito;

        UPDATE dbo.Carritos
        SET Estado = 'CONVERTIDO',
            FechaActualizacion = SYSDATETIME()
        WHERE IDCarrito = @IDCarrito;

        -- 18. Registrar en dbo.Bitacora (RF-09)
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
            'PEDIDOS',
            'CREAR',
            CAST(@IDPedidoNuevo AS VARCHAR(50)),
            NULL,
            CONCAT(
                N'{"IDPedido":', @IDPedidoNuevo,
                N',"EstadoPedido":"', @EstadoInicialPedido,
                N'","Subtotal":', @SubtotalPedido,
                N',"MontoDescuento":', @MontoDescuentoPedido,
                N',"MontoIVA":', @MontoIVAPedido,
                N',"Total":', @TotalPedido,
                N',"IdempotencyKey":"', @IdempotencyKey, N'"}'
            )
        );

        DROP TABLE #LineasCheckout;

        COMMIT TRANSACTION;

        -- Retornar los 4 recordsets del pedido recién creado
        EXEC dbo.SP_Pedidos_ObtenerDetalle
            @IDPedido = @IDPedidoNuevo,
            @IDUsuarioSolicitante = @IDUsuario,
            @FueRespuestaIdempotente = 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2.1 SP_Pedidos_CrearPedido (Alias compatible con REQUIREMENTS.md de Grupo Pentandra)
-- Invoca internamente dbo.SP_Pedidos_CrearCheckout.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Pedidos_CrearPedido
    @IDUsuario INT,
    @IDDireccion INT,
    @IdempotencyKey VARCHAR(64),
    @CodigoCupon VARCHAR(30) = NULL,
    @MetodoPago VARCHAR(30) = 'TARJETA',
    @TransaccionId VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.SP_Pedidos_CrearCheckout
        @IDUsuario = @IDUsuario,
        @IDDireccion = @IDDireccion,
        @IdempotencyKey = @IdempotencyKey,
        @CodigoCupon = @CodigoCupon,
        @MetodoPago = @MetodoPago,
        @TransaccionId = @TransaccionId;
END;
GO

-- ----------------------------------------------------------------------------
-- 3. SP_Pedidos_CambiarEstado
-- Avanza o cancela el estado de un pedido validando la máquina de estados
-- mediante dbo.FU_Pedidos_ValidarTransicionEstado.
-- Cumple todos los criterios de aceptación de RF-07 y RF-09:
--   - "Una transición de estado no permitida se rechaza en la base de datos."
--   - "Un pedido puede cancelarse mientras no haya sido despachado."
--   - "Cancelar reintegra la existencia mediante movimientos en el kardex."
--   - "Cada cambio de estado registra usuario, fecha y hora, estado anterior
--     y estado nuevo."
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Pedidos_CambiarEstado
    @IDPedido INT,
    @IDUsuario INT,
    @EstadoNuevo VARCHAR(30),
    @Motivo NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @EstadoNuevo = LTRIM(RTRIM(UPPER(@EstadoNuevo)));
        SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), '');

        DECLARE @RolUsuario VARCHAR(30);
        SELECT @RolUsuario = r.NombreRol
        FROM dbo.Usuarios AS u
        INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
        WHERE u.IDUsuario = @IDUsuario
          AND u.Activo = 1;

        IF @RolUsuario IS NULL
            ;THROW 50004, 'El usuario que intenta cambiar el estado no existe o está inactivo.', 1;

        -- Bloquear el pedido a modificar
        DECLARE @EstadoActual VARCHAR(30);
        DECLARE @IDClientePedido INT;

        SELECT
            @EstadoActual = EstadoPedido,
            @IDClientePedido = IDUsuario
        FROM dbo.Pedidos WITH (UPDLOCK, ROWLOCK)
        WHERE IDPedido = @IDPedido;

        IF @EstadoActual IS NULL
            ;THROW 50070, 'El pedido especificado no existe.', 1;

        -- Control de acceso por rol (RF-01 y RF-07):
        -- Un Cliente solo puede cancelar su propio pedido; no puede avanzar estados operativos
        IF @RolUsuario = 'Cliente'
        BEGIN
            IF @IDClientePedido <> @IDUsuario
                ;THROW 50071, 'No tiene permisos para modificar un pedido de otro cliente.', 1;

            IF @EstadoNuevo <> 'CANCELADO'
                ;THROW 50073, 'Un cliente únicamente puede solicitar la cancelación de su pedido.', 1;
        END

        -- Validar transición en la máquina de estados (RF-07)
        IF dbo.FU_Pedidos_ValidarTransicionEstado(@EstadoActual, @EstadoNuevo) = 0
        BEGIN
            DECLARE @MensajeTransicionInvalida NVARCHAR(250) = CONCAT(
                N'Transición de estado no permitida: no es posible cambiar un pedido de "',
                @EstadoActual, N'" a "', @EstadoNuevo, N'".'
            );
            ;THROW 50074, @MensajeTransicionInvalida, 1;
        END

        -- Si el nuevo estado es CANCELADO, reintegrar las existencias al inventario y al Kardex (RF-07)
        IF @EstadoNuevo = 'CANCELADO'
        BEGIN
            DECLARE @IDVarianteCanc INT;
            DECLARE @CantidadCanc INT;
            DECLARE @StockAntCanc INT;
            DECLARE @StockActCanc INT;
            DECLARE @MotivoKardexCanc NVARCHAR(250) = ISNULL(
                @Motivo,
                CONCAT(N'Reintegro de existencia por cancelación del Pedido #', @IDPedido)
            );

            DECLARE cur_cancelacion CURSOR LOCAL FAST_FORWARD FOR
                SELECT pd.IDVariante, pd.Cantidad
                FROM dbo.PedidoDetalle AS pd
                WHERE pd.IDPedido = @IDPedido
                ORDER BY pd.IDVariante ASC;

            OPEN cur_cancelacion;
            FETCH NEXT FROM cur_cancelacion INTO @IDVarianteCanc, @CantidadCanc;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT @StockAntCanc = StockFisico
                FROM dbo.Variantes WITH (UPDLOCK, ROWLOCK)
                WHERE IDVariante = @IDVarianteCanc;

                SET @StockActCanc = @StockAntCanc + @CantidadCanc;

                UPDATE dbo.Variantes
                SET StockFisico = @StockActCanc
                WHERE IDVariante = @IDVarianteCanc;

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
                    @IDVarianteCanc,
                    'AJUSTE_ENTRADA',
                    @CantidadCanc,
                    @StockAntCanc,
                    @StockActCanc,
                    @IDPedido,
                    NULL,
                    @IDUsuario,
                    @MotivoKardexCanc,
                    SYSDATETIME()
                );

                FETCH NEXT FROM cur_cancelacion INTO @IDVarianteCanc, @CantidadCanc;
            END

            CLOSE cur_cancelacion;
            DEALLOCATE cur_cancelacion;
        END

        -- Actualizar el estado en dbo.Pedidos
        UPDATE dbo.Pedidos
        SET EstadoPedido = @EstadoNuevo
        WHERE IDPedido = @IDPedido;

        -- Si pasa de PENDIENTE a PAGADO, marcar pago pendiente como APROBADO
        IF @EstadoActual = 'PENDIENTE' AND @EstadoNuevo = 'PAGADO'
        BEGIN
            UPDATE dbo.Pagos
            SET Estado = 'APROBADO',
                FechaPago = SYSDATETIME()
            WHERE IDPedido = @IDPedido
              AND Estado = 'PENDIENTE';
        END

        -- Registrar en dbo.HistorialEstadosPedido (RF-07)
        INSERT INTO dbo.HistorialEstadosPedido (
            IDPedido,
            IDUsuario,
            EstadoAnterior,
            EstadoNuevo,
            FechaHora
        )
        VALUES (
            @IDPedido,
            @IDUsuario,
            @EstadoActual,
            @EstadoNuevo,
            SYSDATETIME()
        );

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
            'PEDIDOS',
            'MODIFICAR',
            CAST(@IDPedido AS VARCHAR(50)),
            CONCAT(N'{"IDPedido":', @IDPedido, N',"EstadoPedido":"', @EstadoActual, N'"}'),
            CONCAT(N'{"IDPedido":', @IDPedido, N',"EstadoPedido":"', @EstadoNuevo, N'","Motivo":"', ISNULL(@Motivo, N''), N'"}')
        );

        COMMIT TRANSACTION;

        EXEC dbo.SP_Pedidos_ObtenerDetalle
            @IDPedido = @IDPedido,
            @IDUsuarioSolicitante = @IDUsuario,
            @FueRespuestaIdempotente = 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 4. SP_Pedidos_Listar
-- Listado de pedidos con paginación y filtros del lado del servidor por
-- estado, cliente y rango de fechas (RF-07, RF-08).
-- Si quien consulta tiene rol 'Cliente', fuerza el filtro a sus propios pedidos.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Pedidos_Listar
    @IDUsuarioSolicitante INT,
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 15,
    @EstadoPedido VARCHAR(30) = NULL,
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

    -- Si es Cliente, aislar estrictamente a sus propios pedidos (RF-01)
    IF @RolSolicitante = 'Cliente'
        SET @IDClienteFiltro = @IDUsuarioSolicitante;

    -- Recordset 1: Total de pedidos para paginación
    SELECT COUNT(1) AS TotalRegistros
    FROM dbo.Pedidos AS p
    WHERE (@IDClienteFiltro IS NULL OR p.IDUsuario = @IDClienteFiltro)
      AND (@EstadoPedido IS NULL OR p.EstadoPedido = @EstadoPedido)
      AND (@FechaInicio IS NULL OR p.FechaCreacion >= @FechaInicio)
      AND (@FechaFin IS NULL OR p.FechaCreacion <= @FechaFin);

    -- Recordset 2: Página de pedidos
    SELECT
        p.IDPedido,
        p.IDUsuario,
        u.NombreCompleto AS NombreCliente,
        u.Correo AS CorreoCliente,
        p.EstadoPedido,
        p.Subtotal,
        p.MontoDescuento,
        p.MontoIVA,
        p.Total,
        p.IDCupon,
        c.Codigo AS CodigoCupon,
        p.DireccionEntregaTexto,
        p.FechaCreacion,
        ISNULL(lineas.TotalItems, 0) AS TotalLineas,
        ISNULL(lineas.TotalUnidades, 0) AS TotalUnidades
    FROM dbo.Pedidos AS p
    INNER JOIN dbo.Usuarios AS u ON u.IDUsuario = p.IDUsuario
    LEFT JOIN dbo.Cupones AS c ON c.IDCupon = p.IDCupon
    OUTER APPLY (
        SELECT
            COUNT(pd.IDPedidoDetalle) AS TotalItems,
            SUM(pd.Cantidad) AS TotalUnidades
        FROM dbo.PedidoDetalle AS pd
        WHERE pd.IDPedido = p.IDPedido
    ) AS lineas
    WHERE (@IDClienteFiltro IS NULL OR p.IDUsuario = @IDClienteFiltro)
      AND (@EstadoPedido IS NULL OR p.EstadoPedido = @EstadoPedido)
      AND (@FechaInicio IS NULL OR p.FechaCreacion >= @FechaInicio)
      AND (@FechaFin IS NULL OR p.FechaCreacion <= @FechaFin)
    ORDER BY p.FechaCreacion DESC, p.IDPedido DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO
