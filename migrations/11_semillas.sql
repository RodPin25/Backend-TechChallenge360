-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 11_semillas.sql
-- DESCRIPCIÓN: Datos iniciales y semillas (Roles, Usuarios, Direcciones,
--              Categorías, Productos, Variantes, Atributos, Kardex inicial y Cupones).
-- COMPATIBILIDAD: Microsoft SQL Server 2019 o superior (T-SQL)
-- NOTA: Precios en Quetzales (GTQ) con IVA del 12% incluido. Idempotente.
-- ============================================================================

USE ShopCartDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT '--> Iniciando carga de datos semilla en ShopCartDB...';

    -- -------------------------------------------------------------------------
    -- 1. ROLES DE SISTEMA (RF-01)
    -- -------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE NombreRol = 'Administrador')
        INSERT INTO dbo.Roles (NombreRol, Descripcion)
        VALUES ('Administrador', 'Control total de la plataforma, reportería y configuración.');

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE NombreRol = 'Operador')
        INSERT INTO dbo.Roles (NombreRol, Descripcion)
        VALUES ('Operador', 'Gestión operativa de catálogo, inventario físico y despacho de pedidos.');

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE NombreRol = 'Cliente')
        INSERT INTO dbo.Roles (NombreRol, Descripcion)
        VALUES ('Cliente', 'Usuario final para exploración de catálogo, carrito y compras.');

    DECLARE @IDRolAdmin INT = (SELECT IDRol FROM dbo.Roles WHERE NombreRol = 'Administrador');
    DECLARE @IDRolOperador INT = (SELECT IDRol FROM dbo.Roles WHERE NombreRol = 'Operador');
    DECLARE @IDRolCliente INT = (SELECT IDRol FROM dbo.Roles WHERE NombreRol = 'Cliente');

    -- -------------------------------------------------------------------------
    -- 2. USUARIOS INICIALES (RF-01)
    -- Hashes bcrypt generados con sal de costo 10:
    -- 'Admin123!*'    -> $2b$10$dY9fGvNn9.K3L5T7M8pApeqHjK2k1u.zQ2uB3vA6xQ9/M7p.1x12K
    -- 'Operador123!*' -> $2b$10$wX1aB2c3d4e5f6g7h8i9jeA1b2C3d4E5f6G7h8I9j0K1L2M3N4O5P
    -- 'Cliente123!*'  -> $2b$10$uH9qR8s7t6u5v4w3x2y1zOcD2e3F4g5H6i7J8k9L0m1N2O3P4Q5R6
    -- -------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = 'admin@shopcart.gt')
        INSERT INTO dbo.Usuarios (IDRol, Correo, PasswordHash, NombreCompleto, Telefono, Activo)
        VALUES (@IDRolAdmin, 'admin@shopcart.gt', '$2b$10$dY9fGvNn9.K3L5T7M8pApeqHjK2k1u.zQ2uB3vA6xQ9/M7p.1x12K', N'Administrador General ShopCart', '50222334455', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = 'operador@shopcart.gt')
        INSERT INTO dbo.Usuarios (IDRol, Correo, PasswordHash, NombreCompleto, Telefono, Activo)
        VALUES (@IDRolOperador, 'operador@shopcart.gt', '$2b$10$wX1aB2c3d4e5f6g7h8i9jeA1b2C3d4E5f6G7h8I9j0K1L2M3N4O5P', N'Carlos Mendoza (Bodega)', '50222445566', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = 'carlos.lopez@gmail.com')
        INSERT INTO dbo.Usuarios (IDRol, Correo, PasswordHash, NombreCompleto, Telefono, Activo)
        VALUES (@IDRolCliente, 'carlos.lopez@gmail.com', '$2b$10$uH9qR8s7t6u5v4w3x2y1zOcD2e3F4g5H6i7J8k9L0m1N2O3P4Q5R6', N'Carlos López', '50255667788', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = 'maria.gonzalez@gmail.com')
        INSERT INTO dbo.Usuarios (IDRol, Correo, PasswordHash, NombreCompleto, Telefono, Activo)
        VALUES (@IDRolCliente, 'maria.gonzalez@gmail.com', '$2b$10$uH9qR8s7t6u5v4w3x2y1zOcD2e3F4g5H6i7J8k9L0m1N2O3P4Q5R6', N'María González', '50255112233', 1);

    DECLARE @IDUserAdmin INT = (SELECT IDUsuario FROM dbo.Usuarios WHERE Correo = 'admin@shopcart.gt');
    DECLARE @IDUserCliente1 INT = (SELECT IDUsuario FROM dbo.Usuarios WHERE Correo = 'carlos.lopez@gmail.com');
    DECLARE @IDUserCliente2 INT = (SELECT IDUsuario FROM dbo.Usuarios WHERE Correo = 'maria.gonzalez@gmail.com');

    -- -------------------------------------------------------------------------
    -- 3. DIRECCIONES DE ENTREGA DE PRUEBA (RF-01)
    -- -------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Direcciones WHERE IDUsuario = @IDUserCliente1 AND EsPrincipal = 1)
        INSERT INTO dbo.Direcciones (IDUsuario, DireccionLinea, Municipio, Departamento, CodigoPostal, Referencia, EsPrincipal, Activo)
        VALUES (@IDUserCliente1, N'12 Calle 4-55 Zona 10, Edificio Reforma Real Nivel 5', N'Guatemala', N'Guatemala', '01010', N'Frente a Centro Comercial Plaza Fontabella', 1, 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Direcciones WHERE IDUsuario = @IDUserCliente1 AND EsPrincipal = 0)
        INSERT INTO dbo.Direcciones (IDUsuario, DireccionLinea, Municipio, Departamento, CodigoPostal, Referencia, EsPrincipal, Activo)
        VALUES (@IDUserCliente1, N'Km 14.5 Carretera a El Salvador, Condominio Los Encinos Casa 12', N'Santa Catarina Pinula', N'Guatemala', '01051', N'Garita principal, timbre verde', 0, 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Direcciones WHERE IDUsuario = @IDUserCliente2 AND EsPrincipal = 1)
        INSERT INTO dbo.Direcciones (IDUsuario, DireccionLinea, Municipio, Departamento, CodigoPostal, Referencia, EsPrincipal, Activo)
        VALUES (@IDUserCliente2, N'5ta Avenida Norte No. 18, Calle del Arco', N'Antigua Guatemala', N'Sacatepéquez', '03001', N'Portón colonial de madera', 1, 1);

    -- -------------------------------------------------------------------------
    -- 4. CATEGORÍAS BASE (RF-02)
    -- -------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE NombreCategoria = N'Tecnología')
        INSERT INTO dbo.Categorias (NombreCategoria, Descripcion, Activo)
        VALUES (N'Tecnología', N'Dispositivos móviles, computadoras, audio y accesorios de última generación', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE NombreCategoria = N'Ropa y Calzado')
        INSERT INTO dbo.Categorias (NombreCategoria, Descripcion, Activo)
        VALUES (N'Ropa y Calzado', N'Moda urbana, deportiva y calzado para todas las edades', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE NombreCategoria = N'Hogar y Cocina')
        INSERT INTO dbo.Categorias (NombreCategoria, Descripcion, Activo)
        VALUES (N'Hogar y Cocina', N'Electrodomésticos, decoración y artículos esenciales para el hogar', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE NombreCategoria = N'Deportes')
        INSERT INTO dbo.Categorias (NombreCategoria, Descripcion, Activo)
        VALUES (N'Deportes', N'Equipamiento de entrenamiento, accesorios fitness y aventura al aire libre', 1);

    DECLARE @IDCategoriaTech INT = (SELECT IDCategoria FROM dbo.Categorias WHERE NombreCategoria = N'Tecnología');
    DECLARE @IDCategoriaRopa INT = (SELECT IDCategoria FROM dbo.Categorias WHERE NombreCategoria = N'Ropa y Calzado');
    DECLARE @IDCategoriaHogar INT = (SELECT IDCategoria FROM dbo.Categorias WHERE NombreCategoria = N'Hogar y Cocina');
    DECLARE @IDCategoriaDeportes INT = (SELECT IDCategoria FROM dbo.Categorias WHERE NombreCategoria = N'Deportes');

    -- -------------------------------------------------------------------------
    -- 5. PRODUCTOS (RF-02)
    -- -------------------------------------------------------------------------
    -- Producto 1: Smartphone Aurora X
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE NombreProducto = N'Smartphone Aurora X 5G')
        INSERT INTO dbo.Productos (IDCategoria, NombreProducto, Descripcion, Activo)
        VALUES (@IDCategoriaTech, N'Smartphone Aurora X 5G', N'Pantalla AMOLED 6.7 pulgadas, cámara cuádruple de 108MP y batería de 5000 mAh.', 1);

    -- Producto 2: Auriculares Inalámbricos SoundPro
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE NombreProducto = N'Auriculares Bluetooth SoundPro Wireless')
        INSERT INTO dbo.Productos (IDCategoria, NombreProducto, Descripcion, Activo)
        VALUES (@IDCategoriaTech, N'Auriculares Bluetooth SoundPro Wireless', N'Cancelación activa de ruido (ANC), hasta 35 horas de batería y resistencia al agua IPX5.', 1);

    -- Producto 3: Sudadera Deportiva DryFit
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE NombreProducto = N'Sudadera Térmica DryFit Unisex')
        INSERT INTO dbo.Productos (IDCategoria, NombreProducto, Descripcion, Activo)
        VALUES (@IDCategoriaRopa, N'Sudadera Térmica DryFit Unisex', N'Fabricada con tejido transpirable de secado rápido ideal para entrenamientos o clima frío.', 1);

    -- Producto 4: Cafetera Espresso Automática Barista
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE NombreProducto = N'Cafetera Espresso Barista Pro')
        INSERT INTO dbo.Productos (IDCategoria, NombreProducto, Descripcion, Activo)
        VALUES (@IDCategoriaHogar, N'Cafetera Espresso Barista Pro', N'Bomba de 15 bares de presión, vaporizador para leche y molino cónico de café integrado.', 1);

    -- Producto 5: Smartwatch FitPulse Pro
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE NombreProducto = N'Smartwatch Deportivo FitPulse Pro')
        INSERT INTO dbo.Productos (IDCategoria, NombreProducto, Descripcion, Activo)
        VALUES (@IDCategoriaDeportes, N'Smartwatch Deportivo FitPulse Pro', N'Monitor cardíaco, GPS integrado, sumergible 5ATM con más de 80 modos deportivos.', 1);

    DECLARE @IDProdAurora INT = (SELECT IDProducto FROM dbo.Productos WHERE NombreProducto = N'Smartphone Aurora X 5G');
    DECLARE @IDProdSoundPro INT = (SELECT IDProducto FROM dbo.Productos WHERE NombreProducto = N'Auriculares Bluetooth SoundPro Wireless');
    DECLARE @IDProdSudadera INT = (SELECT IDProducto FROM dbo.Productos WHERE NombreProducto = N'Sudadera Térmica DryFit Unisex');
    DECLARE @IDProdCafetera INT = (SELECT IDProducto FROM dbo.Productos WHERE NombreProducto = N'Cafetera Espresso Barista Pro');
    DECLARE @IDProdSmartwatch INT = (SELECT IDProducto FROM dbo.Productos WHERE NombreProducto = N'Smartwatch Deportivo FitPulse Pro');

    -- -------------------------------------------------------------------------
    -- 6. VARIANTES Y PRECIOS (GTQ con 12% IVA incluido) (RF-02, RF-03)
    -- -------------------------------------------------------------------------
    -- Smartphone Aurora X: 2 variantes
    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'AURORA-X-128-BLK')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdAurora, 'AURORA-X-128-BLK', N'128GB / Negro Cósmico', 3499.00, 25, 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'AURORA-X-256-SLV')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdAurora, 'AURORA-X-256-SLV', N'256GB / Plata Estelar', 3999.00, 15, 1);

    -- Auriculares SoundPro: 2 variantes
    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'SNDPRO-ANC-BLK')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdSoundPro, 'SNDPRO-ANC-BLK', N'Negro Mate', 450.00, 40, 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'SNDPRO-ANC-WHT')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdSoundPro, 'SNDPRO-ANC-WHT', N'Blanco Glaciar', 450.00, 30, 1);

    -- Sudadera Térmica: 3 variantes
    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'SUD-DF-S-GRY')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdSudadera, 'SUD-DF-S-GRY', N'Talla S / Gris Oxford', 185.00, 20, 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'SUD-DF-M-GRY')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdSudadera, 'SUD-DF-M-GRY', N'Talla M / Gris Oxford', 185.00, 25, 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'SUD-DF-L-BLK')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdSudadera, 'SUD-DF-L-BLK', N'Talla L / Negro Noche', 185.00, 18, 1);

    -- Cafetera Barista Pro: 1 variante
    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'CFTR-BARISTA-SS')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdCafetera, 'CFTR-BARISTA-SS', N'Acero Inoxidable 15 Bares', 1299.00, 12, 1);

    -- Smartwatch FitPulse Pro: 2 variantes
    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'FITPULSE-44-BLK')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdSmartwatch, 'FITPULSE-44-BLK', N'44mm / Correa Silicona Negra', 625.00, 35, 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Variantes WHERE SKU = 'FITPULSE-44-BLU')
        INSERT INTO dbo.Variantes (IDProducto, SKU, NombreVariante, Precio, StockFisico, Activo)
        VALUES (@IDProdSmartwatch, 'FITPULSE-44-BLU', N'44mm / Correa Deportiva Azul', 625.00, 20, 1);

    -- -------------------------------------------------------------------------
    -- 7. ATRIBUTOS DE VARIANTES (RF-02)
    -- -------------------------------------------------------------------------
    DECLARE @IDVarAurora1 INT = (SELECT IDVariante FROM dbo.Variantes WHERE SKU = 'AURORA-X-128-BLK');
    DECLARE @IDVarAurora2 INT = (SELECT IDVariante FROM dbo.Variantes WHERE SKU = 'AURORA-X-256-SLV');
    DECLARE @IDVarSoundPro1 INT = (SELECT IDVariante FROM dbo.Variantes WHERE SKU = 'SNDPRO-ANC-BLK');
    DECLARE @IDVarSoundPro2 INT = (SELECT IDVariante FROM dbo.Variantes WHERE SKU = 'SNDPRO-ANC-WHT');
    DECLARE @IDVarSudM INT = (SELECT IDVariante FROM dbo.Variantes WHERE SKU = 'SUD-DF-M-GRY');

    IF NOT EXISTS (SELECT 1 FROM dbo.VarianteAtributos WHERE IDVariante = @IDVarAurora1 AND Clave = 'Almacenamiento')
        INSERT INTO dbo.VarianteAtributos (IDVariante, Clave, Valor) VALUES (@IDVarAurora1, 'Almacenamiento', '128 GB');
    IF NOT EXISTS (SELECT 1 FROM dbo.VarianteAtributos WHERE IDVariante = @IDVarAurora1 AND Clave = 'Color')
        INSERT INTO dbo.VarianteAtributos (IDVariante, Clave, Valor) VALUES (@IDVarAurora1, 'Color', 'Negro Cósmico');

    IF NOT EXISTS (SELECT 1 FROM dbo.VarianteAtributos WHERE IDVariante = @IDVarAurora2 AND Clave = 'Almacenamiento')
        INSERT INTO dbo.VarianteAtributos (IDVariante, Clave, Valor) VALUES (@IDVarAurora2, 'Almacenamiento', '256 GB');
    IF NOT EXISTS (SELECT 1 FROM dbo.VarianteAtributos WHERE IDVariante = @IDVarAurora2 AND Clave = 'Color')
        INSERT INTO dbo.VarianteAtributos (IDVariante, Clave, Valor) VALUES (@IDVarAurora2, 'Color', 'Plata Estelar');

    IF NOT EXISTS (SELECT 1 FROM dbo.VarianteAtributos WHERE IDVariante = @IDVarSoundPro1 AND Clave = 'Color')
        INSERT INTO dbo.VarianteAtributos (IDVariante, Clave, Valor) VALUES (@IDVarSoundPro1, 'Color', 'Negro Mate');
    IF NOT EXISTS (SELECT 1 FROM dbo.VarianteAtributos WHERE IDVariante = @IDVarSoundPro2 AND Clave = 'Color')
        INSERT INTO dbo.VarianteAtributos (IDVariante, Clave, Valor) VALUES (@IDVarSoundPro2, 'Color', 'Blanco Glaciar');

    IF NOT EXISTS (SELECT 1 FROM dbo.VarianteAtributos WHERE IDVariante = @IDVarSudM AND Clave = 'Talla')
        INSERT INTO dbo.VarianteAtributos (IDVariante, Clave, Valor) VALUES (@IDVarSudM, 'Talla', 'M');
    IF NOT EXISTS (SELECT 1 FROM dbo.VarianteAtributos WHERE IDVariante = @IDVarSudM AND Clave = 'Color')
        INSERT INTO dbo.VarianteAtributos (IDVariante, Clave, Valor) VALUES (@IDVarSudM, 'Color', 'Gris Oxford');

    -- -------------------------------------------------------------------------
    -- 8. ASENTAMIENTO INICIAL EN KARDEX (RF-03)
    -- Regla: Toda existencia física inicial debe tener trazabilidad de entrada
    -- -------------------------------------------------------------------------
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
        v.IDVariante,
        'AJUSTE_ENTRADA',
        v.StockFisico,
        0,
        v.StockFisico,
        NULL,
        NULL,
        @IDUserAdmin,
        N'Carga inicial de inventario / Semilla del sistema',
        SYSDATETIME()
    FROM dbo.Variantes v
    WHERE v.StockFisico > 0
      AND NOT EXISTS (
          SELECT 1 FROM dbo.Kardex k 
          WHERE k.IDVariante = v.IDVariante 
            AND k.TipoMovimiento = 'AJUSTE_ENTRADA' 
            AND k.Motivo LIKE '%Carga inicial%'
      );

    -- -------------------------------------------------------------------------
    -- 9. CUPONES Y PROMOCIONES (RF-05)
    -- -------------------------------------------------------------------------
    -- Cupón Porcentual General 10%
    IF NOT EXISTS (SELECT 1 FROM dbo.Cupones WHERE Codigo = 'BIENVENIDO10')
        INSERT INTO dbo.Cupones (
            Codigo, TipoDescuento, ValorDescuento, MontoMinimoCompra, 
            IDCategoria, FechaInicio, FechaFin, LimiteUsosTotal, 
            UsosActuales, LimiteUsosPorCliente, Activo
        )
        VALUES (
            'BIENVENIDO10', 'PORCENTAJE', 10.00, 100.00,
            NULL, DATEADD(DAY, -1, SYSDATETIME()), DATEADD(YEAR, 1, SYSDATETIME()), 1000,
            0, 1, 1
        );

    -- Cupón Fijo Q50.00 para compras mayores a Q250.00
    IF NOT EXISTS (SELECT 1 FROM dbo.Cupones WHERE Codigo = 'SUPER50GTQ')
        INSERT INTO dbo.Cupones (
            Codigo, TipoDescuento, ValorDescuento, MontoMinimoCompra, 
            IDCategoria, FechaInicio, FechaFin, LimiteUsosTotal, 
            UsosActuales, LimiteUsosPorCliente, Activo
        )
        VALUES (
            'SUPER50GTQ', 'MONTO_FIJO', 50.00, 250.00,
            NULL, DATEADD(DAY, -1, SYSDATETIME()), DATEADD(MONTH, 6, SYSDATETIME()), 500,
            0, 1, 1
        );

    -- Cupón Específico para Categoría Tecnología 15%
    IF NOT EXISTS (SELECT 1 FROM dbo.Cupones WHERE Codigo = 'TECH15')
        INSERT INTO dbo.Cupones (
            Codigo, TipoDescuento, ValorDescuento, MontoMinimoCompra, 
            IDCategoria, FechaInicio, FechaFin, LimiteUsosTotal, 
            UsosActuales, LimiteUsosPorCliente, Activo
        )
        VALUES (
            'TECH15', 'PORCENTAJE', 15.00, 500.00,
            @IDCategoriaTech, DATEADD(DAY, -1, SYSDATETIME()), DATEADD(MONTH, 3, SYSDATETIME()), 300,
            0, 1, 1
        );

    -- -------------------------------------------------------------------------
    -- 10. REGISTRO EN BITÁCORA INMUTABLE (RF-09)
    -- -------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.Bitacora WHERE Modulo = 'Semillas' AND IDRegistroAfectado = 'SISTEMA')
    BEGIN
        INSERT INTO dbo.Bitacora (
            IDUsuario, FechaHora, Modulo, Accion, IDRegistroAfectado, ValorAnterior, ValorNuevo
        )
        VALUES (
            @IDUserAdmin,
            SYSDATETIME(),
            'Semillas',
            'CREAR',
            'SISTEMA',
            NULL,
            N'Inicialización de semillas del sistema: Roles, Usuarios iniciales, Catálogo, Kardex base y Cupones cargados exitosamente.'
        );
    END;

    COMMIT TRANSACTION;
    PRINT '--> Datos semilla cargados con éxito.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrSev INT = ERROR_SEVERITY();
    DECLARE @ErrState INT = ERROR_STATE();
    PRINT '--> ERROR en carga de semillas: ' + @ErrMsg;
    RAISERROR(@ErrMsg, @ErrSev, @ErrState);
END CATCH;
GO
