-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 07_sp_cupones_promociones.sql
-- DESCRIPCIÓN: Procedimientos almacenados para el CRUD administrativo de
--              Cupones y el motor de validación/cálculo de descuentos
--              (RF-05, RF-09).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- NOTA: Precios y descuentos en Quetzales (GTQ) en DECIMAL(12,2).
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 5: CUPONES Y PROMOCIONES (RF-05, RF-09)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SP_Cupones_Crear
-- Permite al Administrador crear un nuevo cupón de tipo 'PORCENTAJE' o
-- 'MONTO_FIJO', validando rangos lógicos, fechas y unicidad de código, y
-- registrando el alta en dbo.Bitacora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Cupones_Crear
    @IDUsuario INT,
    @Codigo VARCHAR(30),
    @TipoDescuento VARCHAR(20), -- 'PORCENTAJE' | 'MONTO_FIJO'
    @ValorDescuento DECIMAL(12,2),
    @MontoMinimoCompra DECIMAL(12,2) = 0.00,
    @IDCategoria INT = NULL,
    @FechaInicio DATETIME2(0),
    @FechaFin DATETIME2(0),
    @LimiteUsosTotal INT,
    @LimiteUsosPorCliente INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @Codigo = LTRIM(RTRIM(UPPER(@Codigo)));
        SET @TipoDescuento = LTRIM(RTRIM(UPPER(@TipoDescuento)));

        IF @Codigo = ''
            ;THROW 50050, 'El código del cupón es obligatorio.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Cupones WHERE Codigo = @Codigo)
            ;THROW 50051, 'Ya existe un cupón registrado con ese código.', 1;

        IF @TipoDescuento NOT IN ('PORCENTAJE', 'MONTO_FIJO')
            ;THROW 50052, 'El tipo de descuento debe ser PORCENTAJE o MONTO_FIJO.', 1;

        IF @ValorDescuento <= 0.00
            ;THROW 50053, 'El valor del descuento debe ser mayor a cero.', 1;

        IF @TipoDescuento = 'PORCENTAJE' AND @ValorDescuento > 100.00
            ;THROW 50054, 'En cupones de porcentaje, el valor de descuento no puede superar el 100%.', 1;

        IF @MontoMinimoCompra < 0.00
            ;THROW 50055, 'El monto mínimo de compra no puede ser negativo.', 1;

        IF @FechaFin < @FechaInicio
            ;THROW 50056, 'La fecha de fin de vigencia no puede ser anterior a la fecha de inicio.', 1;

        IF @LimiteUsosTotal <= 0 OR @LimiteUsosPorCliente <= 0
            ;THROW 50057, 'El límite total de usos y el límite por cliente deben ser mayores a cero.', 1;

        IF @IDCategoria IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE IDCategoria = @IDCategoria)
            ;THROW 50012, 'La categoría asociada al cupón no existe.', 1;

        INSERT INTO dbo.Cupones (
            Codigo,
            TipoDescuento,
            ValorDescuento,
            MontoMinimoCompra,
            IDCategoria,
            FechaInicio,
            FechaFin,
            LimiteUsosTotal,
            UsosActuales,
            LimiteUsosPorCliente,
            Activo
        )
        VALUES (
            @Codigo,
            @TipoDescuento,
            @ValorDescuento,
            @MontoMinimoCompra,
            @IDCategoria,
            @FechaInicio,
            @FechaFin,
            @LimiteUsosTotal,
            0,
            @LimiteUsosPorCliente,
            1
        );

        DECLARE @IDCuponNuevo INT = SCOPE_IDENTITY();

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
            'CUPONES',
            'CREAR',
            CAST(@IDCuponNuevo AS VARCHAR(50)),
            NULL,
            CONCAT(
                N'{"Codigo":"', @Codigo,
                N'","TipoDescuento":"', @TipoDescuento,
                N'","ValorDescuento":', @ValorDescuento,
                N',"MontoMinimoCompra":', @MontoMinimoCompra,
                N',"IDCategoria":', ISNULL(CAST(@IDCategoria AS VARCHAR(20)), 'null'),
                N',"LimiteUsosTotal":', @LimiteUsosTotal,
                N',"LimiteUsosPorCliente":', @LimiteUsosPorCliente,
                N',"Activo":1}'
            )
        );

        COMMIT TRANSACTION;

        SELECT
            c.IDCupon,
            c.Codigo,
            c.TipoDescuento,
            c.ValorDescuento,
            c.MontoMinimoCompra,
            c.IDCategoria,
            cat.NombreCategoria,
            c.FechaInicio,
            c.FechaFin,
            c.LimiteUsosTotal,
            c.UsosActuales,
            c.LimiteUsosPorCliente,
            c.Activo
        FROM dbo.Cupones AS c
        LEFT JOIN dbo.Categorias AS cat ON cat.IDCategoria = c.IDCategoria
        WHERE c.IDCupon = @IDCuponNuevo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2. SP_Cupones_Actualizar
-- Modifica las reglas de un cupón existente validando que LimiteUsosTotal no
-- sea inferior a UsosActuales y dejando trazabilidad en Bitácora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Cupones_Actualizar
    @IDUsuario INT,
    @IDCupon INT,
    @Codigo VARCHAR(30),
    @TipoDescuento VARCHAR(20),
    @ValorDescuento DECIMAL(12,2),
    @MontoMinimoCompra DECIMAL(12,2) = 0.00,
    @IDCategoria INT = NULL,
    @FechaInicio DATETIME2(0),
    @FechaFin DATETIME2(0),
    @LimiteUsosTotal INT,
    @LimiteUsosPorCliente INT = 1,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CodigoAnt VARCHAR(30);
        DECLARE @TipoAnt VARCHAR(20);
        DECLARE @ValorAnt DECIMAL(12,2);
        DECLARE @MinimoAnt DECIMAL(12,2);
        DECLARE @UsosActuales INT;
        DECLARE @ActivoAnt BIT;

        SELECT
            @CodigoAnt = Codigo,
            @TipoAnt = TipoDescuento,
            @ValorAnt = ValorDescuento,
            @MinimoAnt = MontoMinimoCompra,
            @UsosActuales = UsosActuales,
            @ActivoAnt = Activo
        FROM dbo.Cupones WITH (UPDLOCK, ROWLOCK)
        WHERE IDCupon = @IDCupon;

        IF @CodigoAnt IS NULL
            ;THROW 50058, 'El cupón especificado no existe.', 1;

        SET @Codigo = LTRIM(RTRIM(UPPER(@Codigo)));
        SET @TipoDescuento = LTRIM(RTRIM(UPPER(@TipoDescuento)));

        IF @Codigo = ''
            ;THROW 50050, 'El código del cupón es obligatorio.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Cupones WHERE Codigo = @Codigo AND IDCupon <> @IDCupon)
            ;THROW 50051, 'Ya existe otro cupón con ese código.', 1;

        IF @TipoDescuento NOT IN ('PORCENTAJE', 'MONTO_FIJO')
            ;THROW 50052, 'El tipo de descuento debe ser PORCENTAJE o MONTO_FIJO.', 1;

        IF @ValorDescuento <= 0.00
            ;THROW 50053, 'El valor del descuento debe ser mayor a cero.', 1;

        IF @TipoDescuento = 'PORCENTAJE' AND @ValorDescuento > 100.00
            ;THROW 50054, 'En cupones de porcentaje, el valor de descuento no puede superar el 100%.', 1;

        IF @MontoMinimoCompra < 0.00
            ;THROW 50055, 'El monto mínimo de compra no puede ser negativo.', 1;

        IF @FechaFin < @FechaInicio
            ;THROW 50056, 'La fecha de fin de vigencia no puede ser anterior a la fecha de inicio.', 1;

        IF @LimiteUsosTotal <= 0 OR @LimiteUsosPorCliente <= 0
            ;THROW 50057, 'El límite total de usos y el límite por cliente deben ser mayores a cero.', 1;

        IF @LimiteUsosTotal < @UsosActuales
            ;THROW 50059, 'El límite total de usos no puede ser menor que los usos ya consumidos del cupón.', 1;

        IF @IDCategoria IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE IDCategoria = @IDCategoria)
            ;THROW 50012, 'La categoría asociada al cupón no existe.', 1;

        UPDATE dbo.Cupones
        SET Codigo = @Codigo,
            TipoDescuento = @TipoDescuento,
            ValorDescuento = @ValorDescuento,
            MontoMinimoCompra = @MontoMinimoCompra,
            IDCategoria = @IDCategoria,
            FechaInicio = @FechaInicio,
            FechaFin = @FechaFin,
            LimiteUsosTotal = @LimiteUsosTotal,
            LimiteUsosPorCliente = @LimiteUsosPorCliente,
            Activo = @Activo
        WHERE IDCupon = @IDCupon;

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
            'CUPONES',
            CASE WHEN @Activo = 0 AND @ActivoAnt = 1 THEN 'DESACTIVAR' ELSE 'MODIFICAR' END,
            CAST(@IDCupon AS VARCHAR(50)),
            CONCAT(N'{"Codigo":"', @CodigoAnt, N'","TipoDescuento":"', @TipoAnt, N'","ValorDescuento":', @ValorAnt, N',"MontoMinimoCompra":', @MinimoAnt, N',"Activo":', @ActivoAnt, N'}'),
            CONCAT(N'{"Codigo":"', @Codigo, N'","TipoDescuento":"', @TipoDescuento, N'","ValorDescuento":', @ValorDescuento, N',"MontoMinimoCompra":', @MontoMinimoCompra, N',"Activo":', @Activo, N'}')
        );

        COMMIT TRANSACTION;

        SELECT
            c.IDCupon,
            c.Codigo,
            c.TipoDescuento,
            c.ValorDescuento,
            c.MontoMinimoCompra,
            c.IDCategoria,
            cat.NombreCategoria,
            c.FechaInicio,
            c.FechaFin,
            c.LimiteUsosTotal,
            c.UsosActuales,
            c.LimiteUsosPorCliente,
            c.Activo
        FROM dbo.Cupones AS c
        LEFT JOIN dbo.Categorias AS cat ON cat.IDCategoria = c.IDCategoria
        WHERE c.IDCupon = @IDCupon;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 3. SP_Cupones_CambiarEstadoActivo
-- Desactiva o reactiva lógicamente un cupón sin borrado físico y registra en
-- dbo.Bitacora (RF-05, RF-09).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Cupones_CambiarEstadoActivo
    @IDUsuario INT,
    @IDCupon INT,
    @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Codigo VARCHAR(30);
        DECLARE @ActivoAnterior BIT;

        SELECT
            @Codigo = Codigo,
            @ActivoAnterior = Activo
        FROM dbo.Cupones
        WHERE IDCupon = @IDCupon;

        IF @Codigo IS NULL
            ;THROW 50058, 'El cupón especificado no existe.', 1;

        UPDATE dbo.Cupones
        SET Activo = @Activo
        WHERE IDCupon = @IDCupon;

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
            'CUPONES',
            CASE WHEN @Activo = 0 THEN 'DESACTIVAR' ELSE 'MODIFICAR' END,
            CAST(@IDCupon AS VARCHAR(50)),
            CONCAT(N'{"Codigo":"', @Codigo, N'","Activo":', @ActivoAnterior, N'}'),
            CONCAT(N'{"Codigo":"', @Codigo, N'","Activo":', @Activo, N'}')
        );

        COMMIT TRANSACTION;

        SELECT
            c.IDCupon,
            c.Codigo,
            c.Activo
        FROM dbo.Cupones AS c
        WHERE c.IDCupon = @IDCupon;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 4. SP_Cupones_Listar
-- Listado de cupones con paginación y filtros del lado del servidor.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Cupones_Listar
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 15,
    @Activo BIT = NULL,
    @SoloVigentes BIT = 0,
    @TipoDescuento VARCHAR(20) = NULL,
    @Busqueda VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @NumeroPagina < 1 SET @NumeroPagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 15;

    DECLARE @Offset INT = (@NumeroPagina - 1) * @TamanoPagina;
    SET @Busqueda = NULLIF(LTRIM(RTRIM(@Busqueda)), '');

    -- Recordset 1: Total de cupones filtrados
    SELECT COUNT(1) AS TotalRegistros
    FROM dbo.Cupones AS c
    WHERE (@Activo IS NULL OR c.Activo = @Activo)
      AND (@TipoDescuento IS NULL OR c.TipoDescuento = @TipoDescuento)
      AND (@Busqueda IS NULL OR c.Codigo LIKE '%' + @Busqueda + '%')
      AND (
          @SoloVigentes = 0
          OR (
              c.Activo = 1
              AND SYSDATETIME() BETWEEN c.FechaInicio AND c.FechaFin
              AND c.UsosActuales < c.LimiteUsosTotal
          )
      );

    -- Recordset 2: Página de cupones
    SELECT
        c.IDCupon,
        c.Codigo,
        c.TipoDescuento,
        c.ValorDescuento,
        c.MontoMinimoCompra,
        c.IDCategoria,
        cat.NombreCategoria,
        c.FechaInicio,
        c.FechaFin,
        c.LimiteUsosTotal,
        c.UsosActuales,
        (c.LimiteUsosTotal - c.UsosActuales) AS UsosRestantes,
        c.LimiteUsosPorCliente,
        c.Activo,
        CAST(
            CASE
                WHEN c.Activo = 1
                 AND SYSDATETIME() BETWEEN c.FechaInicio AND c.FechaFin
                 AND c.UsosActuales < c.LimiteUsosTotal
                    THEN 1
                ELSE 0
            END
            AS BIT
        ) AS EstaVigente
    FROM dbo.Cupones AS c
    LEFT JOIN dbo.Categorias AS cat ON cat.IDCategoria = c.IDCategoria
    WHERE (@Activo IS NULL OR c.Activo = @Activo)
      AND (@TipoDescuento IS NULL OR c.TipoDescuento = @TipoDescuento)
      AND (@Busqueda IS NULL OR c.Codigo LIKE '%' + @Busqueda + '%')
      AND (
          @SoloVigentes = 0
          OR (
              c.Activo = 1
              AND SYSDATETIME() BETWEEN c.FechaInicio AND c.FechaFin
              AND c.UsosActuales < c.LimiteUsosTotal
          )
      )
    ORDER BY c.IDCupon DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

-- ----------------------------------------------------------------------------
-- 5. SP_Cupones_ObtenerPorID
-- Devuelve el detalle de un cupón junto con el historial de usos registrados
-- en dbo.CuponesUso.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Cupones_ObtenerPorID
    @IDCupon INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cupones WHERE IDCupon = @IDCupon)
        ;THROW 50058, 'El cupón solicitado no existe.', 1;

    -- Recordset 1: Datos del cupón
    SELECT
        c.IDCupon,
        c.Codigo,
        c.TipoDescuento,
        c.ValorDescuento,
        c.MontoMinimoCompra,
        c.IDCategoria,
        cat.NombreCategoria,
        c.FechaInicio,
        c.FechaFin,
        c.LimiteUsosTotal,
        c.UsosActuales,
        (c.LimiteUsosTotal - c.UsosActuales) AS UsosRestantes,
        c.LimiteUsosPorCliente,
        c.Activo
    FROM dbo.Cupones AS c
    LEFT JOIN dbo.Categorias AS cat ON cat.IDCategoria = c.IDCategoria
    WHERE c.IDCupon = @IDCupon;

    -- Recordset 2: Historial de usos del cupón
    SELECT
        cu.IDCuponUso,
        cu.IDCupon,
        cu.IDUsuario,
        u.NombreCompleto AS NombreCliente,
        u.Correo AS CorreoCliente,
        cu.IDPedido,
        p.Subtotal AS SubtotalPedido,
        p.MontoDescuento,
        p.Total AS TotalPedido,
        cu.FechaUso
    FROM dbo.CuponesUso AS cu
    INNER JOIN dbo.Usuarios AS u ON u.IDUsuario = cu.IDUsuario
    INNER JOIN dbo.Pedidos AS p ON p.IDPedido = cu.IDPedido
    WHERE cu.IDCupon = @IDCupon
    ORDER BY cu.FechaUso DESC;
END;
GO

-- ----------------------------------------------------------------------------
-- 6. SP_Cupones_ValidarYAplicarEnCarrito
-- Valida un código de cupón frente al carrito activo del cliente o invitado.
-- Cumple el criterio de aceptación RF-05:
--   - "Un cupón vencido, agotado o que no cumple el mínimo se rechaza con un
--     mensaje específico."
--   - "Un descuento nunca deja el total del pedido por debajo de cero."
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Cupones_ValidarYAplicarEnCarrito
    @Codigo VARCHAR(30),
    @IDUsuario INT = NULL,
    @TokenInvitado VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Codigo = LTRIM(RTRIM(UPPER(@Codigo)));
    SET @TokenInvitado = NULLIF(LTRIM(RTRIM(@TokenInvitado)), '');

    IF @Codigo = ''
        ;THROW 50050, 'Debe ingresar un código de cupón.', 1;

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

    IF @IDCarrito IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.CarritoDetalle WHERE IDCarrito = @IDCarrito)
        ;THROW 50035, 'El carrito se encuentra vacío; agregue productos antes de aplicar un cupón.', 1;

    DECLARE @IDCategoriaCupon INT;
    SELECT @IDCategoriaCupon = IDCategoria
    FROM dbo.Cupones
    WHERE Codigo = @Codigo;

    DECLARE @SubtotalTotal DECIMAL(12,2) = 0.00;
    DECLARE @SubtotalCategoria DECIMAL(12,2) = 0.00;

    SELECT
        @SubtotalTotal = CAST(ISNULL(SUM(CAST(cd.Cantidad AS DECIMAL(12,2)) * v.Precio), 0.00) AS DECIMAL(12,2)),
        @SubtotalCategoria = CAST(
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

    DECLARE @IDCupon INT;
    DECLARE @TipoDescuento VARCHAR(20);
    DECLARE @ValorDescuento DECIMAL(12,2);
    DECLARE @MontoMinimoCompra DECIMAL(12,2);
    DECLARE @EsValido BIT;
    DECLARE @MensajeValidacion NVARCHAR(200);
    DECLARE @MontoDescuento DECIMAL(12,2);
    DECLARE @TotalConDescuento DECIMAL(12,2);

    SELECT
        @IDCupon = calc.IDCupon,
        @TipoDescuento = calc.TipoDescuento,
        @ValorDescuento = calc.ValorDescuento,
        @MontoMinimoCompra = calc.MontoMinimoCompra,
        @EsValido = calc.EsValido,
        @MensajeValidacion = calc.MensajeValidacion,
        @MontoDescuento = calc.MontoDescuento,
        @TotalConDescuento = calc.TotalConDescuento
    FROM dbo.FU_Cupones_CalculoDescuento(
        @Codigo,
        @IDUsuario,
        @SubtotalTotal,
        @SubtotalCategoria
    ) AS calc;

    -- Si no es válido, rechazar con código 50060 y el mensaje específico de negocio
    IF @EsValido = 0
        ;THROW 50060, @MensajeValidacion, 1;

    SELECT
        @IDCarrito AS IDCarrito,
        @IDCupon AS IDCupon,
        @Codigo AS Codigo,
        @TipoDescuento AS TipoDescuento,
        @ValorDescuento AS ValorDescuento,
        @MontoMinimoCompra AS MontoMinimoCompra,
        @IDCategoriaCupon AS IDCategoria,
        @EsValido AS EsValido,
        @MensajeValidacion AS MensajeValidacion,
        @SubtotalTotal AS SubtotalCarrito,
        @SubtotalCategoria AS SubtotalCategoriaElegible,
        @MontoDescuento AS MontoDescuento,
        iva.MontoSinIVA AS TotalSinIVA,
        iva.MontoIVA AS MontoIVA,
        @TotalConDescuento AS TotalConDescuento
    FROM dbo.FU_Finanzas_DesgloseIVA(@TotalConDescuento) AS iva;
END;
GO
