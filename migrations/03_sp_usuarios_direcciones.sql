-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 03_sp_usuarios_direcciones.sql
-- DESCRIPCIÓN: Procedimientos almacenados para Autenticación, Usuarios, Roles
--              y Gestión de Direcciones de Entrega (RF-01, RF-09).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior
-- ============================================================================

USE ShopCartDB;
GO

-- ============================================================================
-- MÓDULO 1: USUARIOS, ROLES Y SEGURIDAD (RF-01)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SP_Usuarios_RegistrarCliente
-- Registra un nuevo usuario con rol 'Cliente', valida unicidad de correo y
-- registra el evento en la Bitácora.
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

        SET @Correo = LTRIM(RTRIM(LOWER(@Correo)));
        SET @NombreCompleto = LTRIM(RTRIM(@NombreCompleto));

        IF @Correo = '' OR @NombreCompleto = '' OR ISNULL(@PasswordHash, '') = ''
            THROW 50001, 'El correo, nombre completo y contraseña son obligatorios.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
            THROW 50002, 'El correo electrónico ya se encuentra registrado.', 1;

        DECLARE @IDRolCliente INT;
        SELECT @IDRolCliente = IDRol
        FROM dbo.Roles
        WHERE NombreRol = 'Cliente';

        IF @IDRolCliente IS NULL
            THROW 50003, 'El rol de Cliente no está configurado en el sistema.', 1;

        INSERT INTO dbo.Usuarios (
            IDRol,
            Correo,
            PasswordHash,
            NombreCompleto,
            Telefono,
            Activo,
            FechaCreacion
        )
        VALUES (
            @IDRolCliente,
            @Correo,
            @PasswordHash,
            @NombreCompleto,
            @Telefono,
            1,
            SYSDATETIME()
        );

        DECLARE @IDUsuarioNuevo INT = SCOPE_IDENTITY();

        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Accion,
            IDRegistroAfectado,
            ValorAnterior,
            ValorNuevo
        )
        VALUES (
            @IDUsuarioNuevo,
            'USUARIOS',
            'CREAR',
            CAST(@IDUsuarioNuevo AS VARCHAR(50)),
            NULL,
            CONCAT(N'{"Correo":"', @Correo, N'","Rol":"Cliente","NombreCompleto":"', @NombreCompleto, N'"}')
        );

        COMMIT TRANSACTION;

        SELECT
            u.IDUsuario,
            u.IDRol,
            r.NombreRol,
            u.Correo,
            u.NombreCompleto,
            u.Telefono,
            u.Activo,
            u.FechaCreacion
        FROM dbo.Usuarios AS u
        INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
        WHERE u.IDUsuario = @IDUsuarioNuevo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 2. SP_Usuarios_ObtenerPorCorreo
-- Obtiene las credenciales y rol de un usuario por su correo para el flujo de
-- inicio de sesión (Login) en el backend.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_ObtenerPorCorreo
    @Correo VARCHAR(120)
AS
BEGIN
    SET NOCOUNT ON;

    SET @Correo = LTRIM(RTRIM(LOWER(@Correo)));

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
    FROM dbo.Usuarios AS u
    INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
    WHERE u.Correo = @Correo;
END;
GO

-- ----------------------------------------------------------------------------
-- 3. SP_Usuarios_ObtenerPerfilPorID
-- Obtiene el perfil del usuario autenticado (/me) sin exponer PasswordHash,
-- e incluye un segundo recordset con su dirección principal activa.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_ObtenerPerfilPorID
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IDUsuario = @IDUsuario)
        THROW 50004, 'El usuario solicitado no existe.', 1;

    -- Recordset 1: Datos del perfil
    SELECT
        u.IDUsuario,
        u.IDRol,
        r.NombreRol,
        u.Correo,
        u.NombreCompleto,
        u.Telefono,
        u.Activo,
        u.FechaCreacion
    FROM dbo.Usuarios AS u
    INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
    WHERE u.IDUsuario = @IDUsuario;

    -- Recordset 2: Dirección principal activa (si tiene)
    SELECT TOP (1)
        d.IDDireccion,
        d.IDUsuario,
        d.DireccionLinea,
        d.Municipio,
        d.Departamento,
        d.CodigoPostal,
        d.Referencia,
        d.EsPrincipal
    FROM dbo.Direcciones AS d
    WHERE d.IDUsuario = @IDUsuario
      AND d.Activo = 1
    ORDER BY d.EsPrincipal DESC, d.IDDireccion DESC;
END;
GO

-- ----------------------------------------------------------------------------
-- 4. SP_Usuarios_ActualizarPerfil
-- Permite al usuario autenticado actualizar sus datos básicos y opcionalmente
-- su hash de contraseña, dejando rastro en Bitácora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_ActualizarPerfil
    @IDUsuario INT,
    @NombreCompleto NVARCHAR(120),
    @Telefono VARCHAR(20) = NULL,
    @PasswordHash VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NombreAnterior NVARCHAR(120);
        DECLARE @TelefonoAnterior VARCHAR(20);
        DECLARE @Activo BIT;

        SELECT
            @NombreAnterior = NombreCompleto,
            @TelefonoAnterior = Telefono,
            @Activo = Activo
        FROM dbo.Usuarios
        WHERE IDUsuario = @IDUsuario;

        IF @NombreAnterior IS NULL
            THROW 50004, 'El usuario solicitado no existe.', 1;

        IF @Activo = 0
            THROW 50005, 'La cuenta de usuario se encuentra desactivada.', 1;

        SET @NombreCompleto = LTRIM(RTRIM(@NombreCompleto));
        IF @NombreCompleto = ''
            THROW 50001, 'El nombre completo no puede estar vacío.', 1;

        UPDATE dbo.Usuarios
        SET NombreCompleto = @NombreCompleto,
            Telefono = @Telefono,
            PasswordHash = COALESCE(NULLIF(@PasswordHash, ''), PasswordHash)
        WHERE IDUsuario = @IDUsuario;

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
            'USUARIOS',
            'MODIFICAR',
            CAST(@IDUsuario AS VARCHAR(50)),
            CONCAT(N'{"NombreCompleto":"', @NombreAnterior, N'","Telefono":"', ISNULL(@TelefonoAnterior, ''), N'"}'),
            CONCAT(N'{"NombreCompleto":"', @NombreCompleto, N'","Telefono":"', ISNULL(@Telefono, ''), N'","CambioPassword":', CASE WHEN NULLIF(@PasswordHash, '') IS NOT NULL THEN 'true' ELSE 'false' END, N'}')
        );

        COMMIT TRANSACTION;

        SELECT
            u.IDUsuario,
            u.IDRol,
            r.NombreRol,
            u.Correo,
            u.NombreCompleto,
            u.Telefono,
            u.Activo,
            u.FechaCreacion
        FROM dbo.Usuarios AS u
        INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
        WHERE u.IDUsuario = @IDUsuario;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 5. SP_Usuarios_CrearUsuarioPorAdmin
-- Permite a un Administrador dar de alta usuarios con rol específico
-- ('Cliente', 'Operador', 'Administrador') y auditar la acción en Bitácora.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_CrearUsuarioPorAdmin
    @IDUsuarioAdmin INT,
    @IDRol INT,
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

        SET @Correo = LTRIM(RTRIM(LOWER(@Correo)));
        SET @NombreCompleto = LTRIM(RTRIM(@NombreCompleto));

        IF @Correo = '' OR @NombreCompleto = '' OR ISNULL(@PasswordHash, '') = ''
            THROW 50001, 'El correo, nombre completo y contraseña son obligatorios.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
            THROW 50002, 'El correo electrónico ya se encuentra registrado.', 1;

        DECLARE @NombreRol VARCHAR(30);
        SELECT @NombreRol = NombreRol
        FROM dbo.Roles
        WHERE IDRol = @IDRol;

        IF @NombreRol IS NULL
            THROW 50003, 'El rol especificado no existe.', 1;

        INSERT INTO dbo.Usuarios (
            IDRol,
            Correo,
            PasswordHash,
            NombreCompleto,
            Telefono,
            Activo,
            FechaCreacion
        )
        VALUES (
            @IDRol,
            @Correo,
            @PasswordHash,
            @NombreCompleto,
            @Telefono,
            1,
            SYSDATETIME()
        );

        DECLARE @IDUsuarioCreado INT = SCOPE_IDENTITY();

        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Accion,
            IDRegistroAfectado,
            ValorAnterior,
            ValorNuevo
        )
        VALUES (
            @IDUsuarioAdmin,
            'USUARIOS',
            'CREAR',
            CAST(@IDUsuarioCreado AS VARCHAR(50)),
            NULL,
            CONCAT(N'{"Correo":"', @Correo, N'","IDRol":', @IDRol, N',"Rol":"', @NombreRol, N'","NombreCompleto":"', @NombreCompleto, N'"}')
        );

        COMMIT TRANSACTION;

        SELECT
            u.IDUsuario,
            u.IDRol,
            r.NombreRol,
            u.Correo,
            u.NombreCompleto,
            u.Telefono,
            u.Activo,
            u.FechaCreacion
        FROM dbo.Usuarios AS u
        INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
        WHERE u.IDUsuario = @IDUsuarioCreado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 6. SP_Usuarios_CambiarEstadoActivo
-- Permite al Administrador activar/desactivar lógicamente a un usuario sin
-- borrarlo físicamente y cambiar opcionalmente su rol (RF-01, RF-09).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_CambiarEstadoActivo
    @IDUsuarioAdmin INT,
    @IDUsuarioObjetivo INT,
    @Activo BIT,
    @IDRol INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @IDUsuarioAdmin = @IDUsuarioObjetivo AND @Activo = 0
            THROW 50006, 'Un administrador no puede desactivar su propia cuenta.', 1;

        DECLARE @ActivoAnterior BIT;
        DECLARE @IDRolAnterior INT;
        DECLARE @CorreoObjetivo VARCHAR(120);

        SELECT
            @ActivoAnterior = Activo,
            @IDRolAnterior = IDRol,
            @CorreoObjetivo = Correo
        FROM dbo.Usuarios
        WHERE IDUsuario = @IDUsuarioObjetivo;

        IF @CorreoObjetivo IS NULL
            THROW 50004, 'El usuario objetivo no existe.', 1;

        IF @IDRol IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE IDRol = @IDRol)
            THROW 50003, 'El rol especificado no existe.', 1;

        DECLARE @IDRolFinal INT = ISNULL(@IDRol, @IDRolAnterior);

        UPDATE dbo.Usuarios
        SET Activo = @Activo,
            IDRol = @IDRolFinal
        WHERE IDUsuario = @IDUsuarioObjetivo;

        INSERT INTO dbo.Bitacora (
            IDUsuario,
            Modulo,
            Accion,
            IDRegistroAfectado,
            ValorAnterior,
            ValorNuevo
        )
        VALUES (
            @IDUsuarioAdmin,
            'USUARIOS',
            CASE WHEN @Activo = 0 THEN 'DESACTIVAR' ELSE 'MODIFICAR' END,
            CAST(@IDUsuarioObjetivo AS VARCHAR(50)),
            CONCAT(N'{"Correo":"', @CorreoObjetivo, N'","Activo":', @ActivoAnterior, N',"IDRol":', @IDRolAnterior, N'}'),
            CONCAT(N'{"Correo":"', @CorreoObjetivo, N'","Activo":', @Activo, N',"IDRol":', @IDRolFinal, N'}')
        );

        COMMIT TRANSACTION;

        SELECT
            u.IDUsuario,
            u.IDRol,
            r.NombreRol,
            u.Correo,
            u.NombreCompleto,
            u.Telefono,
            u.Activo,
            u.FechaCreacion
        FROM dbo.Usuarios AS u
        INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
        WHERE u.IDUsuario = @IDUsuarioObjetivo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 7. SP_Usuarios_ListarUsuarios
-- Listado de usuarios con paginación y filtros del lado del servidor para el
-- panel de Administración.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_ListarUsuarios
    @NumeroPagina INT = 1,
    @TamanoPagina INT = 10,
    @IDRol INT = NULL,
    @Activo BIT = NULL,
    @Busqueda NVARCHAR(120) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @NumeroPagina < 1 SET @NumeroPagina = 1;
    IF @TamanoPagina < 1 OR @TamanoPagina > 100 SET @TamanoPagina = 10;

    DECLARE @Offset INT = (@NumeroPagina - 1) * @TamanoPagina;
    SET @Busqueda = NULLIF(LTRIM(RTRIM(@Busqueda)), '');

    -- Recordset 1: Total de registros para paginación
    SELECT COUNT(1) AS TotalRegistros
    FROM dbo.Usuarios AS u
    WHERE (@IDRol IS NULL OR u.IDRol = @IDRol)
      AND (@Activo IS NULL OR u.Activo = @Activo)
      AND (
          @Busqueda IS NULL
          OR u.NombreCompleto LIKE N'%' + @Busqueda + N'%'
          OR u.Correo LIKE '%' + @Busqueda + '%'
      );

    -- Recordset 2: Página de usuarios
    SELECT
        u.IDUsuario,
        u.IDRol,
        r.NombreRol,
        u.Correo,
        u.NombreCompleto,
        u.Telefono,
        u.Activo,
        u.FechaCreacion
    FROM dbo.Usuarios AS u
    INNER JOIN dbo.Roles AS r ON r.IDRol = u.IDRol
    WHERE (@IDRol IS NULL OR u.IDRol = @IDRol)
      AND (@Activo IS NULL OR u.Activo = @Activo)
      AND (
          @Busqueda IS NULL
          OR u.NombreCompleto LIKE N'%' + @Busqueda + N'%'
          OR u.Correo LIKE '%' + @Busqueda + '%'
      )
    ORDER BY u.FechaCreacion DESC, u.IDUsuario DESC
    OFFSET @Offset ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

-- ----------------------------------------------------------------------------
-- 8. SP_Usuarios_ListarRoles
-- Devuelve el catálogo completo de roles del sistema.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Usuarios_ListarRoles
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.IDRol,
        r.NombreRol,
        r.Descripcion
    FROM dbo.Roles AS r
    ORDER BY r.IDRol ASC;
END;
GO

-- ============================================================================
-- MÓDULO 1.1: DIRECCIONES DE ENTREGA (RF-01, RF-06)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 9. SP_Direcciones_Crear
-- Registra una dirección de entrega para el usuario. Garantiza que exista una
-- única dirección principal activa por cliente.
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

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE IDUsuario = @IDUsuario AND Activo = 1)
            THROW 50004, 'El usuario no existe o se encuentra inactivo.', 1;

        SET @DireccionLinea = LTRIM(RTRIM(@DireccionLinea));
        SET @Municipio = LTRIM(RTRIM(@Municipio));
        SET @Departamento = LTRIM(RTRIM(@Departamento));

        IF @DireccionLinea = '' OR @Municipio = '' OR @Departamento = ''
            THROW 50007, 'La dirección, municipio y departamento son obligatorios.', 1;

        -- Si el cliente no tiene ninguna dirección activa, esta será la principal automáticamente
        IF NOT EXISTS (SELECT 1 FROM dbo.Direcciones WHERE IDUsuario = @IDUsuario AND Activo = 1)
            SET @EsPrincipal = 1;

        -- Si la nueva dirección será principal, desmarcar las anteriores del mismo cliente
        IF @EsPrincipal = 1
        BEGIN
            UPDATE dbo.Direcciones
            SET EsPrincipal = 0
            WHERE IDUsuario = @IDUsuario
              AND Activo = 1
              AND EsPrincipal = 1;
        END

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

        DECLARE @IDDireccionNueva INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT
            d.IDDireccion,
            d.IDUsuario,
            d.DireccionLinea,
            d.Municipio,
            d.Departamento,
            d.CodigoPostal,
            d.Referencia,
            d.EsPrincipal,
            d.Activo
        FROM dbo.Direcciones AS d
        WHERE d.IDDireccion = @IDDireccionNueva;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 10. SP_Direcciones_ListarPorUsuario
-- Lista todas las direcciones activas pertenecientes exclusivamente al usuario.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Direcciones_ListarPorUsuario
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.IDDireccion,
        d.IDUsuario,
        d.DireccionLinea,
        d.Municipio,
        d.Departamento,
        d.CodigoPostal,
        d.Referencia,
        d.EsPrincipal,
        d.Activo
    FROM dbo.Direcciones AS d
    WHERE d.IDUsuario = @IDUsuario
      AND d.Activo = 1
    ORDER BY d.EsPrincipal DESC, d.IDDireccion DESC;
END;
GO

-- ----------------------------------------------------------------------------
-- 11. SP_Direcciones_Actualizar
-- Actualiza los datos de una dirección verificando estrictamente que pertenezca
-- al usuario autenticado (prevención de IDOR en RF-01).
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Direcciones_Actualizar
    @IDDireccion INT,
    @IDUsuario INT,
    @DireccionLinea NVARCHAR(200),
    @Municipio NVARCHAR(100),
    @Departamento NVARCHAR(100),
    @CodigoPostal VARCHAR(10) = NULL,
    @Referencia NVARCHAR(200) = NULL,
    @EsPrincipal BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EsPrincipalActual BIT;

        SELECT @EsPrincipalActual = EsPrincipal
        FROM dbo.Direcciones
        WHERE IDDireccion = @IDDireccion
          AND IDUsuario = @IDUsuario
          AND Activo = 1;

        IF @EsPrincipalActual IS NULL
            THROW 50008, 'La dirección no existe o no pertenece al usuario autenticado.', 1;

        SET @DireccionLinea = LTRIM(RTRIM(@DireccionLinea));
        SET @Municipio = LTRIM(RTRIM(@Municipio));
        SET @Departamento = LTRIM(RTRIM(@Departamento));

        IF @DireccionLinea = '' OR @Municipio = '' OR @Departamento = ''
            THROW 50007, 'La dirección, municipio y departamento son obligatorios.', 1;

        DECLARE @NuevoEsPrincipal BIT = ISNULL(@EsPrincipal, @EsPrincipalActual);

        IF @NuevoEsPrincipal = 1 AND @EsPrincipalActual = 0
        BEGIN
            UPDATE dbo.Direcciones
            SET EsPrincipal = 0
            WHERE IDUsuario = @IDUsuario
              AND Activo = 1
              AND IDDireccion <> @IDDireccion;
        END

        UPDATE dbo.Direcciones
        SET DireccionLinea = @DireccionLinea,
            Municipio = @Municipio,
            Departamento = @Departamento,
            CodigoPostal = @CodigoPostal,
            Referencia = @Referencia,
            EsPrincipal = @NuevoEsPrincipal
        WHERE IDDireccion = @IDDireccion
          AND IDUsuario = @IDUsuario;

        COMMIT TRANSACTION;

        SELECT
            d.IDDireccion,
            d.IDUsuario,
            d.DireccionLinea,
            d.Municipio,
            d.Departamento,
            d.CodigoPostal,
            d.Referencia,
            d.EsPrincipal,
            d.Activo
        FROM dbo.Direcciones AS d
        WHERE d.IDDireccion = @IDDireccion;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 12. SP_Direcciones_EstablecerPrincipal
-- Alterna de forma atómica la dirección principal del cliente autenticado.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Direcciones_EstablecerPrincipal
    @IDDireccion INT,
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Direcciones
            WHERE IDDireccion = @IDDireccion
              AND IDUsuario = @IDUsuario
              AND Activo = 1
        )
            THROW 50008, 'La dirección no existe o no pertenece al usuario autenticado.', 1;

        UPDATE dbo.Direcciones
        SET EsPrincipal = CASE WHEN IDDireccion = @IDDireccion THEN 1 ELSE 0 END
        WHERE IDUsuario = @IDUsuario
          AND Activo = 1;

        COMMIT TRANSACTION;

        SELECT
            d.IDDireccion,
            d.IDUsuario,
            d.DireccionLinea,
            d.Municipio,
            d.Departamento,
            d.CodigoPostal,
            d.Referencia,
            d.EsPrincipal,
            d.Activo
        FROM dbo.Direcciones AS d
        WHERE d.IDDireccion = @IDDireccion;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ----------------------------------------------------------------------------
-- 13. SP_Direcciones_Desactivar
-- Desactiva lógicamente (Activo = 0) una dirección del cliente. Si era la
-- dirección principal, promueve la dirección activa más reciente del usuario.
-- ----------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.SP_Direcciones_Desactivar
    @IDDireccion INT,
    @IDUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @EraPrincipal BIT;

        SELECT @EraPrincipal = EsPrincipal
        FROM dbo.Direcciones
        WHERE IDDireccion = @IDDireccion
          AND IDUsuario = @IDUsuario
          AND Activo = 1;

        IF @EraPrincipal IS NULL
            THROW 50008, 'La dirección no existe o no pertenece al usuario autenticado.', 1;

        UPDATE dbo.Direcciones
        SET Activo = 0,
            EsPrincipal = 0
        WHERE IDDireccion = @IDDireccion
          AND IDUsuario = @IDUsuario;

        IF @EraPrincipal = 1
        BEGIN
            DECLARE @IDDireccionSucesora INT;
            SELECT TOP (1) @IDDireccionSucesora = IDDireccion
            FROM dbo.Direcciones
            WHERE IDUsuario = @IDUsuario
              AND Activo = 1
            ORDER BY IDDireccion DESC;

            IF @IDDireccionSucesora IS NOT NULL
            BEGIN
                UPDATE dbo.Direcciones
                SET EsPrincipal = 1
                WHERE IDDireccion = @IDDireccionSucesora;
            END
        END

        COMMIT TRANSACTION;

        SELECT
            @IDDireccion AS IDDireccionDesactivada,
            CAST(1 AS BIT) AS Desactivada;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO
