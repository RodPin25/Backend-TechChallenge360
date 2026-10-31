USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 1: AUTENTICACIÓN, USUARIOS Y DIRECCIONES (RF-01)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. REGISTRAR CLIENTE
-- Registra un nuevo usuario asignándole por defecto el rol 'Cliente'.
-- Nota: La contraseña ya debe venir encriptada con Bcrypt desde el Backend.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_RegistrarCliente
    @Correo VARCHAR(120),
    @PasswordHash VARCHAR(255),
    @NombreCompleto NVARCHAR(120),
    @Telefono VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validar que el correo no esté registrado
        IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
        BEGIN
            ;THROW 50001, 'El correo electrónico ya se encuentra registrado.', 1;
        END

        -- 2. Obtener el identificador del rol 'Cliente'
        DECLARE @IDRolCliente INT;
        SELECT @IDRolCliente = IDRol 
        FROM dbo.Roles 
        WHERE NombreRol = 'Cliente';

        IF @IDRolCliente IS NULL
        BEGIN
            ;THROW 50002, 'El rol de Cliente no está configurado en el sistema.', 1;
        END

        -- 3. Insertar usuario
        INSERT INTO dbo.Usuarios (IDRol, Correo, PasswordHash, NombreCompleto, Telefono, Activo)
        VALUES (@IDRolCliente, @Correo, @PasswordHash, @NombreCompleto, @Telefono, 1);

        DECLARE @NuevoID INT = SCOPE_IDENTITY();

        -- 4. Registrar en Bitácora inmutable
        INSERT INTO dbo.Bitacora (IDUsuario, Modulo, Accion, IDRegistroAfectado, ValorAnterior, ValorNuevo)
        VALUES (
            @NuevoID, 
            'USUARIOS', 
            'CREAR', 
            CAST(@NuevoID AS VARCHAR(50)), 
            NULL, 
            CONCAT('{"Correo":"', @Correo, '","Nombre":"', @NombreCompleto, '"}')
        );

        COMMIT TRANSACTION;

        -- Retornar datos del usuario creado (excluyendo el hash por seguridad)
        SELECT 
            u.IDUsuario,
            u.Correo,
            u.NombreCompleto,
            u.Telefono,
            r.NombreRol,
            u.Activo,
            u.FechaCreacion
        FROM dbo.Usuarios u
        INNER JOIN dbo.Roles r ON u.IDRol = r.IDRol
        WHERE u.IDUsuario = @NuevoID;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2. OBTENER USUARIO POR CORREO (Para Login en Node.js)
-- Devuelve los datos del usuario junto a su PasswordHash para validación en backend.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_ObtenerPorCorreo
    @Correo VARCHAR(120)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.IDUsuario,
        u.IDRol,
        r.NombreRol,
        u.Correo,
        u.PasswordHash,
        u.NombreCompleto,
        u.Telefono,
        u.Activo,
        u.FechaCreacion
    FROM dbo.Usuarios u
    INNER JOIN dbo.Roles r ON u.IDRol = r.IDRol
    WHERE u.Correo = @Correo;
END;
GO

-- ----------------------------------------------------------------------------
-- 3. OBTENER PERFIL DE USUARIO POR ID (Para middleware de autenticación /me)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_ObtenerPorId
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        u.IDUsuario,
        u.IDRol,
        r.NombreRol,
        u.Correo,
        u.NombreCompleto,
        u.Telefono,
        u.Activo,
        u.FechaCreacion
    FROM dbo.Usuarios u
    INNER JOIN dbo.Roles r ON u.IDRol = r.IDRol
    WHERE u.IDUsuario = @IDUsuario;
END;
GO

-- ----------------------------------------------------------------------------
-- 4. CREAR DIRECCIÓN DE ENTREGA
-- Si se marca como principal, desmarca las anteriores del mismo usuario.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Direcciones_Crear
    @IDUsuario INT,
    @DireccionLinea NVARCHAR(200),
    @Municipio NVARCHAR(100),
    @Departamento NVARCHAR(100),
    @CodigoPostal VARCHAR(10) = NULL,
    @Referencia NVARCHAR(200) = NULL,
    @EsPrincipal BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validar que el usuario exista y esté activo
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IDUsuario = @IDUsuario AND Activo = 1)
        BEGIN
            ;THROW 50003, 'El usuario especificado no existe o está inactivo.', 1;
        END

        -- 2. Si no tiene direcciones previas, forzar que esta sea la principal
        IF NOT EXISTS (SELECT 1 FROM dbo.Direcciones WHERE IDUsuario = @IDUsuario AND Activo = 1)
        BEGIN
            SET @EsPrincipal = 1;
        END

        -- 3. Si se definió como principal, desmarcar cualquier otra previa
        IF @EsPrincipal = 1
        BEGIN
            UPDATE dbo.Direcciones
            SET EsPrincipal = 0
            WHERE IDUsuario = @IDUsuario;
        END

        -- 4. Insertar nueva dirección
        INSERT INTO dbo.Direcciones (
            IDUsuario, 
            DireccionLinea, 
            Municipio, 
            Departamento, 
            CodigoPostal, 
            Referencia, 
            EsPrincipal, 
            Activo
        )
        VALUES (
            @IDUsuario, 
            @DireccionLinea, 
            @Municipio, 
            @Departamento, 
            @CodigoPostal, 
            @Referencia, 
            @EsPrincipal, 
            1
        );

        DECLARE @NuevoIDDireccion INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT 
            IDDireccion,
            IDUsuario,
            DireccionLinea,
            Municipio,
            Departamento,
            CodigoPostal,
            Referencia,
            EsPrincipal,
            Activo
        FROM dbo.Direcciones
        WHERE IDDireccion = @NuevoIDDireccion;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 5. LISTAR DIRECCIONES ACTIVAS DE UN USUARIO
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Direcciones_ListarPorUsuario
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        IDDireccion,
        IDUsuario,
        DireccionLinea,
        Municipio,
        Departamento,
        CodigoPostal,
        Referencia,
        EsPrincipal,
        Activo
    FROM dbo.Direcciones
    WHERE IDUsuario = @IDUsuario AND Activo = 1
    ORDER BY EsPrincipal DESC, IDDireccion DESC;
END;
GO

-- ============================================================================
-- MÓDULO 2: CATÁLOGO Y PRODUCTOS (RF-02)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. LISTAR PRODUCTOS CON PAGINACIÓN Y FILTROS DEL LADO DEL SERVIDOR
-- Permite búsqueda por texto, filtro de categoría, rango de precios y stock.
-- Retorna el total de coincidencias para que el frontend arme la paginación.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ListarProductos
    @Buscar NVARCHAR(100) = NULL,
    @IDCategoria INT = NULL,
    @PrecioMin DECIMAL(12,2) = NULL,
    @PrecioMax DECIMAL(12,2) = NULL,
    @SoloConStock BIT = 0,
    @Pagina INT = 1,
    @TamanoPagina INT = 12,
    @OrdenarPor VARCHAR(20) = 'FECHA_DESC' -- 'PRECIO_ASC', 'PRECIO_DESC', 'NOMBRE_ASC', 'FECHA_DESC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Normalizar paginación defensiva
    IF @Pagina < 1 SET @Pagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 50 SET @TamanoPagina = 12;

    DECLARE @Offset INT = (@Pagina - 1) * @TamanoPagina;

    -- Consulta base con Common Table Expression (CTE)
    ;WITH ProductosFiltrados AS (
        SELECT 
            p.IDProducto,
            p.NombreProducto,
            p.Descripcion,
            p.FechaCreacion,
            c.IDCategoria,
            c.NombreCategoria,
            MIN(v.Precio) AS PrecioMinimo,
            MAX(v.Precio) AS PrecioMaximo,
            SUM(dbo.FN_Inventario_StockDisponible(v.IDVariante)) AS StockTotalDisponible
        FROM dbo.Productos p
        INNER JOIN dbo.Categorias c ON p.IDCategoria = c.IDCategoria
        INNER JOIN dbo.Variantes v ON p.IDProducto = v.IDProducto
        WHERE p.Activo = 1 
          AND c.Activo = 1 
          AND v.Activo = 1
          AND (@Buscar IS NULL OR p.NombreProducto LIKE '%' + @Buscar + '%' OR p.Descripcion LIKE '%' + @Buscar + '%')
          AND (@IDCategoria IS NULL OR p.IDCategoria = @IDCategoria)
        GROUP BY 
            p.IDProducto, 
            p.NombreProducto, 
            p.Descripcion, 
            p.FechaCreacion, 
            c.IDCategoria, 
            c.NombreCategoria
        HAVING 
            (@PrecioMin IS NULL OR MIN(v.Precio) >= @PrecioMin)
            AND (@PrecioMax IS NULL OR MAX(v.Precio) <= @PrecioMax)
            AND (@SoloConStock = 0 OR SUM(dbo.FN_Inventario_StockDisponible(v.IDVariante)) > 0)
    )
    SELECT 
        pf.*,
        COUNT(1) OVER() AS TotalRegistros,
        @Pagina AS PaginaActual,
        CEILING(CAST(COUNT(1) OVER() AS FLOAT) / @TamanoPagina) AS TotalPaginas
    FROM ProductosFiltrados pf
    ORDER BY 
        CASE WHEN @OrdenarPor = 'PRECIO_ASC' THEN pf.PrecioMinimo END ASC,
        CASE WHEN @OrdenarPor = 'PRECIO_DESC' THEN pf.PrecioMaximo END DESC,
        CASE WHEN @OrdenarPor = 'NOMBRE_ASC' THEN pf.NombreProducto END ASC,
        CASE WHEN @OrdenarPor = 'FECHA_DESC' THEN pf.FechaCreacion END DESC
    OFFSET @Offset ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

-- ----------------------------------------------------------------------------
-- 2. OBTENER DETALLE COMPLETO DE UN PRODUCTO (Variantes y Atributos)
-- Ejecuta consultas múltiples para que el Service arme el objeto compuesto.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_ObtenerDetalleProducto
    @IDProducto INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Encabezado del Producto
    SELECT 
        p.IDProducto,
        p.NombreProducto,
        p.Descripcion,
        p.FechaCreacion,
        p.Activo,
        c.IDCategoria,
        c.NombreCategoria
    FROM dbo.Productos p
    INNER JOIN dbo.Categorias c ON p.IDCategoria = c.IDCategoria
    WHERE p.IDProducto = @IDProducto;

    -- 2. Variantes con su Stock Disponible calculado
    SELECT 
        v.IDVariante,
        v.IDProducto,
        v.SKU,
        v.NombreVariante,
        v.Precio,
        v.StockFisico,
        dbo.FN_Inventario_StockDisponible(v.IDVariante) AS StockDisponible,
        v.Activo
    FROM dbo.Variantes v
    WHERE v.IDProducto = @IDProducto AND v.Activo = 1;

    -- 3. Atributos dinámicos por variante (Talla, Color, Material, etc.)
    SELECT 
        va.IDVarianteAtributo,
        va.IDVariante,
        va.Clave,
        va.Valor
    FROM dbo.VarianteAtributos va
    INNER JOIN dbo.Variantes v ON va.IDVariante = v.IDVariante
    WHERE v.IDProducto = @IDProducto AND v.Activo = 1;
END;
GO

-- ----------------------------------------------------------------------------
-- 3. DESACTIVACIÓN LÓGICA DE PRODUCTO (Soft Delete con Bitácora)
-- Cumple con la regla: si tiene pedidos históricos, solo se desactiva.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Catalogo_DesactivarProducto
    @IDProducto INT,
    @IDUsuarioOperador INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validar que el producto exista y esté activo
        IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE IDProducto = @IDProducto AND Activo = 1)
        BEGIN
            ;THROW 50010, 'El producto no existe o ya se encuentra inactivo.', 1;
        END

        -- 2. Desactivación lógica del producto
        UPDATE dbo.Productos
        SET Activo = 0
        WHERE IDProducto = @IDProducto;

        -- 3. Desactivación en cascada de sus variantes
        UPDATE dbo.Variantes
        SET Activo = 0
        WHERE IDProducto = @IDProducto;

        -- 4. Registrar evento inmutable en Bitácora
        INSERT INTO dbo.Bitacora (
            IDUsuario, 
            Modulo, 
            Accion, 
            IDRegistroAfectado, 
            ValorAnterior, 
            ValorNuevo
        )
        VALUES (
            @IDUsuarioOperador, 
            'CATALOGO', 
            'DESACTIVAR', 
            CAST(@IDProducto AS VARCHAR(50)), 
            '{"Activo": 1}', 
            '{"Activo": 0}'
        );

        COMMIT TRANSACTION;

        SELECT 
            @IDProducto AS IDProductoAfectado, 
            'Producto y sus variantes desactivados exitosamente.' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 3: INVENTARIO, RESERVAS TEMPORALES Y KARDEX (RF-03, RF-06)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. RESERVAR STOCK CON CONCURRENCIA SEGURA (TTL de 15 minutos)
-- Bloquea la variante con UPDLOCK + ROWLOCK para serializar compras simultáneas
-- de la última unidad y evitar sobreventa.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ReservarStock
    @IDVariante INT,
    @Cantidad INT,
    @IDUsuario INT = NULL,
    @TokenSesion VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validaciones defensivas iniciales
    IF @Cantidad <= 0
    BEGIN
        ;THROW 50020, 'La cantidad a reservar debe ser mayor a cero.', 1;
    END

    IF @IDUsuario IS NULL AND @TokenSesion IS NULL
    BEGIN
        ;THROW 50021, 'Debe proporcionar un IDUsuario o un TokenSesion para asociar la reserva.', 1;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Bloqueo pesimista exclusivo de la fila de la variante
        -- UPDLOCK evita bloqueos de lectura compartida conflictivos y ROWLOCK minimiza la contención.
        DECLARE @StockFisicoActual INT;
        DECLARE @EsActiva BIT;

        SELECT 
            @StockFisicoActual = StockFisico,
            @EsActiva = Activo
        FROM dbo.Variantes WITH (UPDLOCK, ROWLOCK)
        WHERE IDVariante = @IDVariante;

        IF @StockFisicoActual IS NULL
        BEGIN
            ;THROW 50022, 'La variante de producto especificada no existe.', 1;
        END

        IF @EsActiva = 0
        BEGIN
            ;THROW 50023, 'La variante de producto no está disponible para la venta.', 1;
        END

        -- 2. Calcular reservas activas vigentes dentro de la transacción protegida
        DECLARE @ReservasActivas INT = 0;

        SELECT @ReservasActivas = ISNULL(SUM(Cantidad), 0)
        FROM dbo.ReservasExistencia WITH (UPDLOCK)
        WHERE IDVariante = @IDVariante
          AND Estado = 'ACTIVA'
          AND FechaExpiracion > SYSDATETIME();

        -- 3. Validar disponibilidad real
        DECLARE @StockDisponible INT = @StockFisicoActual - @ReservasActivas;

        IF @StockDisponible < @Cantidad
        BEGIN
            DECLARE @MsgError NVARCHAR(200) = CONCAT(
                'Existencias insuficientes. Disponibles: ', @StockDisponible, 
                ', Solicitadas: ', @Cantidad
            );
            ;THROW 50024, @MsgError, 1;
        END

        -- 4. Crear la reserva temporal con TTL de 15 minutos
        DECLARE @FechaExpiracion DATETIME2(0) = DATEADD(MINUTE, 15, SYSDATETIME());
        DECLARE @NuevoIDReserva BIGINT;

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
            SYSDATETIME(),
            @FechaExpiracion,
            'ACTIVA'
        );

        SET @NuevoIDReserva = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        -- Retornar la confirmación con la fecha límite exacta
        SELECT 
            @NuevoIDReserva AS IDReserva,
            @IDVariante AS IDVariante,
            @Cantidad AS CantidadReservada,
            @FechaExpiracion AS FechaExpiracion,
            DATEDIFF(SECOND, SYSDATETIME(), @FechaExpiracion) AS SegundosRestantes,
            'ACTIVA' AS Estado;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2. LIBERAR RESERVAS EXPIRADAS (Limpieza Periódica)
-- Actualiza a 'LIBERADA' todas las reservas cuyo tiempo de 15 minutos venció.
-- Puede ejecutarse por un cron/tarea periódica de Node.js o SQL Agent.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_LiberarReservasExpiradas
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ReservasLiberadas INT = 0;

    UPDATE dbo.ReservasExistencia
    SET Estado = 'LIBERADA'
    WHERE Estado = 'ACTIVA'
      AND FechaExpiracion <= SYSDATETIME();

    SET @ReservasLiberadas = @@ROWCOUNT;

    SELECT 
        @ReservasLiberadas AS TotalReservasLiberadas,
        SYSDATETIME() AS FechaEjecucion;
END;
GO

-- ----------------------------------------------------------------------------
-- 3. REGISTRAR MOVIMIENTO EN KARDEX Y ACTUALIZAR STOCK FÍSICO
-- Procedimiento de auditoría física para ajustes manuales de almacén o recepciones.
-- Tipos permitidos: 'AJUSTE_ENTRADA', 'AJUSTE_SALIDA'
-- (Nota: 'VENTA' y 'DEVOLUCION' se manejan desde Checkout y Devoluciones).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_RegistrarAjusteManual
    @IDVariante INT,
    @TipoMovimiento VARCHAR(25), -- 'AJUSTE_ENTRADA' o 'AJUSTE_SALIDA'
    @Cantidad INT,
    @Motivo NVARCHAR(250),
    @IDUsuarioOperador INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 1. Validaciones de negocio
    IF @TipoMovimiento NOT IN ('AJUSTE_ENTRADA', 'AJUSTE_SALIDA')
    BEGIN
        ;THROW 50030, 'El tipo de movimiento manual solo puede ser AJUSTE_ENTRADA o AJUSTE_SALIDA.', 1;
    END

    IF @Cantidad <= 0
    BEGIN
        ;THROW 50031, 'La cantidad del ajuste debe ser mayor a cero.', 1;
    END

    IF TRIM(ISNULL(@Motivo, '')) = ''
    BEGIN
        ;THROW 50032, 'Debe especificar un motivo obligatorio para el ajuste de inventario.', 1;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 2. Bloquear y leer existencias actuales
        DECLARE @StockAnterior INT;

        SELECT @StockAnterior = StockFisico
        FROM dbo.Variantes WITH (UPDLOCK, ROWLOCK)
        WHERE IDVariante = @IDVariante;

        IF @StockAnterior IS NULL
        BEGIN
            ;THROW 50033, 'La variante de producto especificada no existe.', 1;
        END

        -- 3. Calcular nuevo balance
        DECLARE @StockActual INT;

        IF @TipoMovimiento = 'AJUSTE_ENTRADA'
        BEGIN
            SET @StockActual = @StockAnterior + @Cantidad;
        END
        ELSE -- 'AJUSTE_SALIDA'
        BEGIN
            IF @StockAnterior < @Cantidad
            BEGIN
                ;THROW 50034, 'No es posible realizar un ajuste de salida superior al stock físico en bodega.', 1;
            END
            SET @StockActual = @StockAnterior - @Cantidad;
        END

        -- 4. Actualizar tabla Variantes
        UPDATE dbo.Variantes
        SET StockFisico = @StockActual
        WHERE IDVariante = @IDVariante;

        -- 5. Registrar en Kardex
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
            @IDUsuarioOperador,
            @Motivo,
            SYSDATETIME()
        );

        DECLARE @NuevoIDKardex BIGINT = SCOPE_IDENTITY();

        -- 6. Auditoría en Bitácora
        INSERT INTO dbo.Bitacora (
            IDUsuario, 
            Modulo, 
            Accion, 
            IDRegistroAfectado, 
            ValorAnterior, 
            ValorNuevo
        )
        VALUES (
            @IDUsuarioOperador,
            'INVENTARIO',
            'MODIFICAR',
            CAST(@IDVariante AS VARCHAR(50)),
            CONCAT('{"StockFisico":', @StockAnterior, '}'),
            CONCAT('{"StockFisico":', @StockActual, ',"Tipo":"', @TipoMovimiento, '","Kardex":', @NuevoIDKardex, '}')
        );

        COMMIT TRANSACTION;

        SELECT 
            @NuevoIDKardex AS IDKardex,
            @IDVariante AS IDVariante,
            @TipoMovimiento AS TipoMovimiento,
            @Cantidad AS Cantidad,
            @StockAnterior AS StockAnterior,
            @StockActual AS StockActual,
            @Motivo AS Motivo;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 4. CONSULTAR HISTORIAL DE KARDEX POR VARIANTE (Paginado para Admin/Operador)
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Inventario_ConsultarKardex
    @IDVariante INT,
    @Pagina INT = 1,
    @TamanoPagina INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF @Pagina < 1 SET @Pagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 20;

    DECLARE @Offset INT = (@Pagina - 1) * @TamanoPagina;

    SELECT 
        k.IDKardex,
        k.IDVariante,
        v.SKU,
        v.NombreVariante,
        k.TipoMovimiento,
        k.Cantidad,
        k.StockAnterior,
        k.StockActual,
        k.IDPedido,
        k.IDDevolucion,
        k.Motivo,
        k.FechaMovimiento,
        u.NombreCompleto AS UsuarioResponsable,
        COUNT(1) OVER() AS TotalRegistros
    FROM dbo.Kardex k
    INNER JOIN dbo.Variantes v ON k.IDVariante = v.IDVariante
    INNER JOIN dbo.Usuarios u ON k.IDUsuario = u.IDUsuario
    WHERE k.IDVariante = @IDVariante
    ORDER BY k.IDKardex DESC
    OFFSET @Offset ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO