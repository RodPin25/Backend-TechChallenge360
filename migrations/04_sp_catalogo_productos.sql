-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 04_sp_catalogo_productos.sql
-- DESCRIPCIÓN: Procedimientos almacenados para Categorías, Productos,
--              Variantes, Atributos e Historial de Precios (RF-02, RF-03, RF-09).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 2.1: CATEGORÍAS (RF-02, RF-09)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SP_Catalogo_CrearCategoria
-- Crea una categoría en el catálogo validando unicidad y registrando Bitácora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CrearCategoria
    @IDUsuario INT,
    @NombreCategoria NVARCHAR(100),
    @Descripcion NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @NombreCategoria = LTRIM(RTRIM(@NombreCategoria));

        IF @NombreCategoria = ''
            THROW 50010, 'El nombre de la categoría es obligatorio.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Categorias WHERE NombreCategoria = @NombreCategoria)
            THROW 50011, 'Ya existe una categoría con ese nombre.', 1;

        INSERT INTO dbo.Categorias (
            NombreCategoria,
            Descripcion,
            Activo
        )
        VALUES (
            @NombreCategoria,
            @Descripcion,
            1
        );

        DECLARE @IDCategoriaNueva INT = SCOPE_IDENTITY();

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
            'CATEGORIAS',
            'CREAR',
            CAST(@IDCategoriaNueva AS VARCHAR(50)),
            NULL,
            CONCAT(N'{"NombreCategoria":"', @NombreCategoria, N'","Descripcion":"', ISNULL(@Descripcion, N''), N'","Activo":1}')
        );

        COMMIT TRANSACTION;

        SELECT
            c.IDCategoria,
            c.NombreCategoria,
            c.Descripcion,
            c.Activo
        FROM dbo.Categorias AS c
        WHERE c.IDCategoria = @IDCategoriaNueva;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2. SP_Catalogo_ActualizarCategoria
-- Actualiza nombre, descripción y estado Activo de una categoría con auditoría.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ActualizarCategoria
    @IDUsuario INT,
    @IDCategoria INT,
    @NombreCategoria NVARCHAR(100),
    @Descripcion NVARCHAR(250) = NULL,
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreAnterior NVARCHAR(100);
        DECLARE @DescripcionAnterior NVARCHAR(250);
        DECLARE @ActivoAnterior BIT;

        SELECT
            @NombreAnterior = NombreCategoria,
            @DescripcionAnterior = Descripcion,
            @ActivoAnterior = Activo
        FROM dbo.Categorias
        WHERE IDCategoria = @IDCategoria;

        IF @NombreAnterior IS NULL
            THROW 50012, 'La categoría especificada no existe.', 1;

        SET @NombreCategoria = LTRIM(RTRIM(@NombreCategoria));
        IF @NombreCategoria = ''
            THROW 50010, 'El nombre de la categoría es obligatorio.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.Categorias
            WHERE NombreCategoria = @NombreCategoria
              AND IDCategoria <> @IDCategoria
        )
            THROW 50011, 'Ya existe otra categoría con ese nombre.', 1;

        UPDATE dbo.Categorias
        SET NombreCategoria = @NombreCategoria,
            Descripcion = @Descripcion,
            Activo = @Activo
        WHERE IDCategoria = @IDCategoria;

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
            'CATEGORIAS',
            CASE WHEN @Activo = 0 AND @ActivoAnterior = 1 THEN 'DESACTIVAR' ELSE 'MODIFICAR' END,
            CAST(@IDCategoria AS VARCHAR(50)),
            CONCAT(N'{"NombreCategoria":"', @NombreAnterior, N'","Descripcion":"', ISNULL(@DescripcionAnterior, N''), N'","Activo":', @ActivoAnterior, N'}'),
            CONCAT(N'{"NombreCategoria":"', @NombreCategoria, N'","Descripcion":"', ISNULL(@Descripcion, N''), N'","Activo":', @Activo, N'}')
        );

        COMMIT TRANSACTION;

        SELECT
            c.IDCategoria,
            c.NombreCategoria,
            c.Descripcion,
            c.Activo
        FROM dbo.Categorias AS c
        WHERE c.IDCategoria = @IDCategoria;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 3. SP_Catalogo_ListarCategorias
-- Lista categorías con conteo de productos activos asociados.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ListarCategorias
    @SoloActivas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.IDCategoria,
        c.NombreCategoria,
        c.Descripcion,
        c.Activo,
        COUNT(p.IDProducto) AS TotalProductosActivos
    FROM dbo.Categorias AS c
    LEFT JOIN dbo.Productos AS p
        ON p.IDCategoria = c.IDCategoria
       AND p.Activo = 1
    WHERE (@SoloActivas = 0 OR c.Activo = 1)
    GROUP BY
        c.IDCategoria,
        c.NombreCategoria,
        c.Descripcion,
        c.Activo
    ORDER BY c.NombreCategoria ASC;
END;
GO

-- ============================================================================
-- MÓDULO 2.2: PRODUCTOS (RF-02, RF-09)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4. SP_Catalogo_CrearProducto
-- Crea un producto base en el catálogo y registra en Bitácora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CrearProducto
    @IDUsuario INT,
    @IDCategoria INT,
    @NombreProducto NVARCHAR(150),
    @Descripcion NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @NombreProducto = LTRIM(RTRIM(@NombreProducto));
        IF @NombreProducto = ''
            THROW 50013, 'El nombre del producto es obligatorio.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE IDCategoria = @IDCategoria)
            THROW 50012, 'La categoría especificada no existe.', 1;

        INSERT INTO dbo.Productos (
            IDCategoria,
            NombreProducto,
            Descripcion,
            Activo,
            FechaCreacion
        )
        VALUES (
            @IDCategoria,
            @NombreProducto,
            @Descripcion,
            1,
            SYSDATETIME()
        );

        DECLARE @IDProductoNuevo INT = SCOPE_IDENTITY();

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
            'PRODUCTOS',
            'CREAR',
            CAST(@IDProductoNuevo AS VARCHAR(50)),
            NULL,
            CONCAT(N'{"IDCategoria":', @IDCategoria, N',"NombreProducto":"', @NombreProducto, N'","Activo":1}')
        );

        COMMIT TRANSACTION;

        SELECT
            p.IDProducto,
            p.IDCategoria,
            c.NombreCategoria,
            p.NombreProducto,
            p.Descripcion,
            p.Activo,
            p.FechaCreacion
        FROM dbo.Productos AS p
        INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
        WHERE p.IDProducto = @IDProductoNuevo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 5. SP_Catalogo_ActualizarProducto
-- Actualiza los datos maestros de un producto y registra auditoría en Bitácora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ActualizarProducto
    @IDUsuario INT,
    @IDProducto INT,
    @IDCategoria INT,
    @NombreProducto NVARCHAR(150),
    @Descripcion NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IDCategoriaAnt INT;
        DECLARE @NombreAnt NVARCHAR(150);

        SELECT
            @IDCategoriaAnt = IDCategoria,
            @NombreAnt = NombreProducto
        FROM dbo.Productos
        WHERE IDProducto = @IDProducto;

        IF @NombreAnt IS NULL
            THROW 50014, 'El producto especificado no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE IDCategoria = @IDCategoria)
            THROW 50012, 'La categoría especificada no existe.', 1;

        SET @NombreProducto = LTRIM(RTRIM(@NombreProducto));
        IF @NombreProducto = ''
            THROW 50013, 'El nombre del producto es obligatorio.', 1;

        UPDATE dbo.Productos
        SET IDCategoria = @IDCategoria,
            NombreProducto = @NombreProducto,
            Descripcion = @Descripcion
        WHERE IDProducto = @IDProducto;

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
            'PRODUCTOS',
            'MODIFICAR',
            CAST(@IDProducto AS VARCHAR(50)),
            CONCAT(N'{"IDCategoria":', @IDCategoriaAnt, N',"NombreProducto":"', @NombreAnt, N'"}'),
            CONCAT(N'{"IDCategoria":', @IDCategoria, N',"NombreProducto":"', @NombreProducto, N'"}')
        );

        COMMIT TRANSACTION;

        SELECT
            p.IDProducto,
            p.IDCategoria,
            c.NombreCategoria,
            p.NombreProducto,
            p.Descripcion,
            p.Activo,
            p.FechaCreacion
        FROM dbo.Productos AS p
        INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
        WHERE p.IDProducto = @IDProducto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 6. SP_Catalogo_CambiarEstadoProducto
-- Desactivación lógica (Soft Delete, Activo = 0) o reactivación de un producto
-- sin borrado físico para preservar historial comercial (RF-02, RF-09).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CambiarEstadoProducto
    @IDUsuario INT,
    @IDProducto INT,
    @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ActivoAnterior BIT;
        DECLARE @NombreProducto NVARCHAR(150);

        SELECT
            @ActivoAnterior = Activo,
            @NombreProducto = NombreProducto
        FROM dbo.Productos
        WHERE IDProducto = @IDProducto;

        IF @NombreProducto IS NULL
            THROW 50014, 'El producto especificado no existe.', 1;

        UPDATE dbo.Productos
        SET Activo = @Activo
        WHERE IDProducto = @IDProducto;

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
            'PRODUCTOS',
            CASE WHEN @Activo = 0 THEN 'DESACTIVAR' ELSE 'MODIFICAR' END,
            CAST(@IDProducto AS VARCHAR(50)),
            CONCAT(N'{"NombreProducto":"', @NombreProducto, N'","Activo":', @ActivoAnterior, N'}'),
            CONCAT(N'{"NombreProducto":"', @NombreProducto, N'","Activo":', @Activo, N'}')
        );

        COMMIT TRANSACTION;

        SELECT
            p.IDProducto,
            p.NombreProducto,
            p.Activo
        FROM dbo.Productos AS p
        WHERE p.IDProducto = @IDProducto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 7. SP_Catalogo_ListarProductos
-- Listado de catálogo con búsqueda por texto, filtros por categoría, rango de
-- precios, disponibilidad en tiempo real (descontando reservas activas),
-- ordenamiento y paginación del lado del servidor (< 1 segundo).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ListarProductos
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 12,
    @Busqueda NVARCHAR(150) = NULL,
    @IDCategoria INT = NULL,
    @PrecioMinimo DECIMAL(12,2) = NULL,
    @PrecioMaximo DECIMAL(12,2) = NULL,
    @SoloDisponibles BIT = 0,
    @SoloActivos BIT = 1,
    @OrdenarPor VARCHAR(30) = 'RECIENTES' -- 'PRECIO_ASC', 'PRECIO_DESC', 'NOMBRE_ASC', 'NOMBRE_DESC', 'RECIENTES'
AS
BEGIN
    SET NOCOUNT ON;

    IF @NumeroPagina < 1 SET @NumeroPagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 12;

    DECLARE @Offset INT = (@NumeroPagina - 1) * @TamanoPagina;
    SET @Busqueda = NULLIF(LTRIM(RTRIM(@Busqueda)), '');

    -- CTE que agrega métricas de variantes e inventario disponible por producto
    ;WITH ProductosConMetricas AS (
        SELECT
            p.IDProducto,
            p.IDCategoria,
            c.NombreCategoria,
            p.NombreProducto,
            p.Descripcion,
            p.Activo,
            p.FechaCreacion,
            ISNULL(agg.TotalVariantesActivas, 0) AS TotalVariantesActivas,
            ISNULL(agg.PrecioMinimo, 0.00) AS PrecioDesde,
            ISNULL(agg.PrecioMaximo, 0.00) AS PrecioHasta,
            ISNULL(agg.StockFisicoTotal, 0) AS StockFisicoTotal,
            ISNULL(agg.StockDisponibleTotal, 0) AS StockDisponibleTotal
        FROM dbo.Productos AS p
        INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
        OUTER APPLY (
            SELECT
                COUNT(v.IDVariante) AS TotalVariantesActivas,
                MIN(v.Precio) AS PrecioMinimo,
                MAX(v.Precio) AS PrecioMaximo,
                SUM(v.StockFisico) AS StockFisicoTotal,
                SUM(disp.StockDisponible) AS StockDisponibleTotal
            FROM dbo.Variantes AS v
            CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(v.IDVariante) AS disp
            WHERE v.IDProducto = p.IDProducto
              AND (@SoloActivos = 0 OR v.Activo = 1)
        ) AS agg
        WHERE (@SoloActivos = 0 OR (p.Activo = 1 AND c.Activo = 1))
          AND (@IDCategoria IS NULL OR p.IDCategoria = @IDCategoria)
          AND (
              @Busqueda IS NULL
              OR p.NombreProducto LIKE N'%' + @Busqueda + N'%'
              OR p.Descripcion LIKE N'%' + @Busqueda + N'%'
              OR EXISTS (
                  SELECT 1
                  FROM dbo.Variantes AS vbusq
                  WHERE vbusq.IDProducto = p.IDProducto
                    AND (vbusq.SKU LIKE '%' + @Busqueda + '%' OR vbusq.NombreVariante LIKE N'%' + @Busqueda + N'%')
              )
          )
          AND (@PrecioMinimo IS NULL OR agg.PrecioMaximo >= @PrecioMinimo)
          AND (@PrecioMaximo IS NULL OR agg.PrecioMinimo <= @PrecioMaximo)
          AND (@SoloDisponibles = 0 OR ISNULL(agg.StockDisponibleTotal, 0) > 0)
    )
    SELECT
        IDProducto,
        IDCategoria,
        NombreCategoria,
        NombreProducto,
        Descripcion,
        Activo,
        FechaCreacion,
        TotalVariantesActivas,
        PrecioDesde,
        PrecioHasta,
        StockFisicoTotal,
        StockDisponibleTotal
    INTO #ProductosFiltrados
    FROM ProductosConMetricas;

    -- Recordset 1: Total de registros para paginación
    SELECT COUNT(1) AS TotalRegistros
    FROM #ProductosFiltrados;

    -- Recordset 2: Página de productos ordenada
    SELECT
        pf.IDProducto,
        pf.IDCategoria,
        pf.NombreCategoria,
        pf.NombreProducto,
        pf.Descripcion,
        pf.Activo,
        pf.FechaCreacion,
        pf.TotalVariantesActivas,
        pf.PrecioDesde,
        pf.PrecioHasta,
        iva.MontoSinIVA AS PrecioDesdeSinIVA,
        iva.MontoIVA AS PrecioDesdeIVA,
        pf.StockFisicoTotal,
        pf.StockDisponibleTotal,
        CAST(CASE WHEN pf.StockDisponibleTotal > 0 THEN 1 ELSE 0 END AS BIT) AS TieneDisponibilidad
    FROM #ProductosFiltrados AS pf
    CROSS APPLY dbo.FU_Finanzas_DesgloseIVA(pf.PrecioDesde) AS iva
    ORDER BY
        CASE WHEN @OrdenarPor = 'PRECIO_ASC' THEN pf.PrecioDesde END ASC,
        CASE WHEN @OrdenarPor = 'PRECIO_DESC' THEN pf.PrecioDesde END DESC,
        CASE WHEN @OrdenarPor = 'NOMBRE_ASC' THEN pf.NombreProducto END ASC,
        CASE WHEN @OrdenarPor = 'NOMBRE_DESC' THEN pf.NombreProducto END DESC,
        CASE WHEN @OrdenarPor = 'RECIENTES' OR @OrdenarPor IS NULL THEN pf.FechaCreacion END DESC,
        pf.IDProducto DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;

    DROP TABLE #ProductosFiltrados;
END;
GO

-- ----------------------------------------------------------------------------
-- 8. SP_Catalogo_ObtenerDetalleProducto
-- Devuelve 3 recordsets limpios para el driver mssql:
--   1) Datos del Producto y Categoría
--   2) Variantes con su Precio, IVA y StockDisponible real
--   3) Atributos (Clave/Valor) de las variantes del producto
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ObtenerDetalleProducto
    @IDProducto INT,
    @IncluirInactivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Productos AS p
        INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
        WHERE p.IDProducto = @IDProducto
          AND (@IncluirInactivos = 1 OR (p.Activo = 1 AND c.Activo = 1))
    )
        THROW 50014, 'El producto solicitado no existe o no se encuentra disponible.', 1;

    -- Recordset 1: Maestro del producto
    SELECT
        p.IDProducto,
        p.IDCategoria,
        c.NombreCategoria,
        p.NombreProducto,
        p.Descripcion,
        p.Activo,
        p.FechaCreacion
    FROM dbo.Productos AS p
    INNER JOIN dbo.Categorias AS c ON c.IDCategoria = p.IDCategoria
    WHERE p.IDProducto = @IDProducto;

    -- Recordset 2: Variantes con precio vigente y disponibilidad real
    SELECT
        v.IDVariante,
        v.IDProducto,
        v.SKU,
        v.NombreVariante,
        v.Precio,
        iva.MontoSinIVA AS PrecioSinIVA,
        iva.MontoIVA AS MontoIVAUnitario,
        disp.StockFisico,
        disp.StockReservado,
        disp.StockDisponible,
        v.Activo
    FROM dbo.Variantes AS v
    CROSS APPLY dbo.FU_Finanzas_DesgloseIVA(v.Precio) AS iva
    CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(v.IDVariante) AS disp
    WHERE v.IDProducto = @IDProducto
      AND (@IncluirInactivos = 1 OR v.Activo = 1)
    ORDER BY v.IDVariante ASC;

    -- Recordset 3: Atributos de cada variante del producto
    SELECT
        va.IDVarianteAtributo,
        va.IDVariante,
        va.Clave,
        va.Valor,
        va.Activo
    FROM dbo.VarianteAtributos AS va
    INNER JOIN dbo.Variantes AS v ON v.IDVariante = va.IDVariante
    WHERE v.IDProducto = @IDProducto
      AND (@IncluirInactivos = 1 OR (v.Activo = 1 AND va.Activo = 1))
    ORDER BY va.IDVariante ASC, va.Clave ASC;
END;
GO

-- ============================================================================
-- MÓDULO 2.3: VARIANTES, ATRIBUTOS E HISTORIAL DE PRECIOS (RF-02, RF-03, RF-09)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 9. SP_Catalogo_CrearVariante
-- Crea una variante con SKU único, precio en GTQ y stock inicial opcional.
-- Si @StockInicial > 0, registra automáticamente el asiento 'AJUSTE_ENTRADA'
-- en dbo.Kardex para garantizar que StockFisico coincida siempre con el Kardex.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_CrearVariante
    @IDUsuario INT,
    @IDProducto INT,
    @SKU VARCHAR(50),
    @NombreVariante NVARCHAR(100),
    @Precio DECIMAL(12,2),
    @StockInicial INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @SKU = LTRIM(RTRIM(UPPER(@SKU)));
        SET @NombreVariante = LTRIM(RTRIM(@NombreVariante));

        IF @SKU = '' OR @NombreVariante = ''
            THROW 50015, 'El código SKU y el nombre de la variante son obligatorios.', 1;

        IF @Precio < 0.00
            THROW 50016, 'El precio de la variante no puede ser negativo.', 1;

        IF @StockInicial < 0
            THROW 50017, 'La existencia inicial no puede ser negativa.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE IDProducto = @IDProducto)
            THROW 50014, 'El producto asociado no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = @SKU)
            THROW 50018, 'El código SKU ya está asignado a otra variante.', 1;

        INSERT INTO dbo.Variantes (
            IDProducto,
            SKU,
            NombreVariante,
            Precio,
            StockFisico,
            Activo
        )
        VALUES (
            @IDProducto,
            @SKU,
            @NombreVariante,
            @Precio,
            @StockInicial,
            1
        );

        DECLARE @IDVarianteNueva INT = SCOPE_IDENTITY();

        -- Si nace con existencia inicial > 0, registrar movimiento inicial en Kardex (RF-03)
        IF @StockInicial > 0
        BEGIN
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
                @IDVarianteNueva,
                'AJUSTE_ENTRADA',
                @StockInicial,
                0,
                @StockInicial,
                NULL,
                NULL,
                @IDUsuario,
                N'Inventario inicial al crear la variante SKU ' + @SKU,
                SYSDATETIME()
            );
        END

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
            'VARIANTES',
            'CREAR',
            CAST(@IDVarianteNueva AS VARCHAR(50)),
            NULL,
            CONCAT(N'{"IDProducto":', @IDProducto, N',"SKU":"', @SKU, N'","NombreVariante":"', @NombreVariante, N'","Precio":', @Precio, N',"StockInicial":', @StockInicial, N'}')
        );

        COMMIT TRANSACTION;

        SELECT
            v.IDVariante,
            v.IDProducto,
            v.SKU,
            v.NombreVariante,
            v.Precio,
            disp.StockFisico,
            disp.StockReservado,
            disp.StockDisponible,
            v.Activo
        FROM dbo.Variantes AS v
        CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(v.IDVariante) AS disp
        WHERE v.IDVariante = @IDVarianteNueva;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 10. SP_Catalogo_ActualizarVariante
-- Actualiza SKU, nombre, precio y estado Activo de una variante.
-- Si el precio cambia, registra automáticamente en dbo.HistorialPrecios y en
-- dbo.Bitacora con módulo 'PRECIOS' sin alterar pedidos previos (RF-02, RF-09).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ActualizarVariante
    @IDUsuario INT,
    @IDVariante INT,
    @SKU VARCHAR(50),
    @NombreVariante NVARCHAR(100),
    @Precio DECIMAL(12,2),
    @Activo BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @SKUAnterior VARCHAR(50);
        DECLARE @NombreAnterior NVARCHAR(100);
        DECLARE @PrecioAnterior DECIMAL(12,2);
        DECLARE @ActivoAnterior BIT;

        SELECT
            @SKUAnterior = SKU,
            @NombreAnterior = NombreVariante,
            @PrecioAnterior = Precio,
            @ActivoAnterior = Activo
        FROM dbo.Variantes WITH (UPDLOCK, ROWLOCK)
        WHERE IDVariante = @IDVariante;

        IF @SKUAnterior IS NULL
            THROW 50019, 'La variante especificada no existe.', 1;

        SET @SKU = LTRIM(RTRIM(UPPER(@SKU)));
        SET @NombreVariante = LTRIM(RTRIM(@NombreVariante));

        IF @SKU = '' OR @NombreVariante = ''
            THROW 50015, 'El código SKU y el nombre de la variante son obligatorios.', 1;

        IF @Precio < 0.00
            THROW 50016, 'El precio de la variante no puede ser negativo.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.Variantes
            WHERE SKU = @SKU
              AND IDVariante <> @IDVariante
        )
            THROW 50018, 'El código SKU ya está asignado a otra variante.', 1;

        UPDATE dbo.Variantes
        SET SKU = @SKU,
            NombreVariante = @NombreVariante,
            Precio = @Precio,
            Activo = @Activo
        WHERE IDVariante = @IDVariante;

        -- Si hubo cambio de precio, registrar en HistorialPrecios y Bitácora de Precios
        IF @Precio <> @PrecioAnterior
        BEGIN
            INSERT INTO dbo.HistorialPrecios (
                IDVariante,
                PrecioAnterior,
                PrecioNuevo,
                IDUsuario,
                FechaModificacion
            )
            VALUES (
                @IDVariante,
                @PrecioAnterior,
                @Precio,
                @IDUsuario,
                SYSDATETIME()
            );

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
                'PRECIOS',
                'MODIFICAR',
                CAST(@IDVariante AS VARCHAR(50)),
                CONCAT(N'{"SKU":"', @SKUAnterior, N'","Precio":', @PrecioAnterior, N'}'),
                CONCAT(N'{"SKU":"', @SKU, N'","Precio":', @Precio, N'}')
            );
        END

        -- Registro en Bitácora por actualización o desactivación de la variante
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
            'VARIANTES',
            CASE WHEN @Activo = 0 AND @ActivoAnterior = 1 THEN 'DESACTIVAR' ELSE 'MODIFICAR' END,
            CAST(@IDVariante AS VARCHAR(50)),
            CONCAT(N'{"SKU":"', @SKUAnterior, N'","NombreVariante":"', @NombreAnterior, N'","Precio":', @PrecioAnterior, N',"Activo":', @ActivoAnterior, N'}'),
            CONCAT(N'{"SKU":"', @SKU, N'","NombreVariante":"', @NombreVariante, N'","Precio":', @Precio, N',"Activo":', @Activo, N'}')
        );

        COMMIT TRANSACTION;

        SELECT
            v.IDVariante,
            v.IDProducto,
            v.SKU,
            v.NombreVariante,
            v.Precio,
            disp.StockFisico,
            disp.StockReservado,
            disp.StockDisponible,
            v.Activo
        FROM dbo.Variantes AS v
        CROSS APPLY dbo.FU_Inventario_DetalleDisponibilidad(v.IDVariante) AS disp
        WHERE v.IDVariante = @IDVariante;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 11. SP_Catalogo_GuardarAtributoVariante
-- Crea o actualiza un atributo (ej. Clave = 'Talla', Valor = 'L') para una
-- variante específica.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_GuardarAtributoVariante
    @IDVariante INT,
    @Clave NVARCHAR(50),
    @Valor NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE IDVariante = @IDVariante)
            THROW 50019, 'La variante especificada no existe.', 1;

        SET @Clave = LTRIM(RTRIM(@Clave));
        SET @Valor = LTRIM(RTRIM(@Valor));

        IF @Clave = '' OR @Valor = ''
            THROW 50020, 'La clave y el valor del atributo son obligatorios.', 1;

        DECLARE @IDVarianteAtributo INT;

        SELECT @IDVarianteAtributo = IDVarianteAtributo
        FROM dbo.VarianteAtributos
        WHERE IDVariante = @IDVariante
          AND Clave = @Clave;

        IF @IDVarianteAtributo IS NOT NULL
        BEGIN
            UPDATE dbo.VarianteAtributos
            SET Valor = @Valor,
                Activo = 1
            WHERE IDVarianteAtributo = @IDVarianteAtributo;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.VarianteAtributos (
                IDVariante,
                Clave,
                Valor,
                Activo
            )
            VALUES (
                @IDVariante,
                @Clave,
                @Valor,
                1
            );

            SET @IDVarianteAtributo = SCOPE_IDENTITY();
        END

        COMMIT TRANSACTION;

        SELECT
            va.IDVarianteAtributo,
            va.IDVariante,
            va.Clave,
            va.Valor,
            va.Activo
        FROM dbo.VarianteAtributos AS va
        WHERE va.IDVarianteAtributo = @IDVarianteAtributo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 12. SP_Catalogo_EliminarAtributoVariante
-- Desactiva lógicamente (Activo = 0) un atributo descriptivo de una variante
-- y devuelve los atributos activos restantes de dicha variante.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_EliminarAtributoVariante
    @IDVarianteAtributo INT,
    @IDVariante INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.VarianteAtributos
            WHERE IDVarianteAtributo = @IDVarianteAtributo
              AND IDVariante = @IDVariante
              AND Activo = 1
        )
            THROW 50021, 'El atributo especificado no existe o ya se encuentra inactivo para esta variante.', 1;

        UPDATE dbo.VarianteAtributos
        SET Activo = 0
        WHERE IDVarianteAtributo = @IDVarianteAtributo
          AND IDVariante = @IDVariante;

        COMMIT TRANSACTION;

        SELECT
            va.IDVarianteAtributo,
            va.IDVariante,
            va.Clave,
            va.Valor,
            va.Activo
        FROM dbo.VarianteAtributos AS va
        WHERE va.IDVariante = @IDVariante
          AND va.Activo = 1
        ORDER BY va.Clave ASC;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 13. SP_Catalogo_ObtenerHistorialPrecios
-- Consulta el historial de cambios de precio por variante o producto con
-- trazabilidad del usuario que realizó cada modificación (RF-02, RF-09).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ObtenerHistorialPrecios
    @IDVariante INT = NULL,
    @IDProducto INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        hp.IDHistorialPrecio,
        hp.IDVariante,
        v.SKU,
        v.NombreVariante,
        p.IDProducto,
        p.NombreProducto,
        hp.PrecioAnterior,
        hp.PrecioNuevo,
        hp.IDUsuario,
        u.NombreCompleto AS ModificadoPor,
        u.Correo AS CorreoModificador,
        hp.FechaModificacion
    FROM dbo.HistorialPrecios AS hp
    INNER JOIN dbo.Variantes AS v ON v.IDVariante = hp.IDVariante
    INNER JOIN dbo.Productos AS p ON p.IDProducto = v.IDProducto
    INNER JOIN dbo.Usuarios AS u ON u.IDUsuario = hp.IDUsuario
    WHERE (@IDVariante IS NULL OR hp.IDVariante = @IDVariante)
      AND (@IDProducto IS NULL OR v.IDProducto = @IDProducto)
    ORDER BY hp.FechaModificacion DESC, hp.IDHistorialPrecio DESC;
END;
GO
