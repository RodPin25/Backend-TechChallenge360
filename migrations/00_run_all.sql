-- ============================================================================
-- PROYECTO: ShopCart (Tech Challenge 360 - Grupo Pentandra)
-- ARCHIVO: 00_run_all.sql
-- DESCRIPCIÓN: Script maestro para ejecutar todas las migraciones en SQL Server.
-- MODO DE USO: Requiere habilitar el modo SQLCMD en SQL Server Management Studio (SSMS)
--              o ejecutar mediante la utilidad de línea de comandos sqlcmd:
--              sqlcmd -S localhost -U sa -P TuPassword -i migrations/00_run_all.sql
-- ============================================================================

:setvar CURRENT_PATH "."

PRINT '--------------------------------------------------------------';
PRINT '  EJECUTANDO MIGRACIONES DE SHOPCART EN SQL SERVER (SQLCMD)   ';
PRINT '--------------------------------------------------------------';
GO

PRINT '>> [1/11] 01_Tablas.sql...';
:r 01_Tablas.sql
GO

PRINT '>> [2/11] 02_funciones.sql...';
:r 02_funciones.sql
GO

PRINT '>> [3/11] 03_sp_usuarios_direcciones.sql...';
:r 03_sp_usuarios_direcciones.sql
GO

PRINT '>> [4/11] 04_sp_catalogo_productos.sql...';
:r 04_sp_catalogo_productos.sql
GO

PRINT '>> [5/11] 05_sp_inventario_kardex.sql...';
:r 05_sp_inventario_kardex.sql
GO

PRINT '>> [6/11] 06_sp_carrito_compras.sql...';
:r 06_sp_carrito_compras.sql
GO

PRINT '>> [7/11] 07_sp_cupones_promociones.sql...';
:r 07_sp_cupones_promociones.sql
GO

PRINT '>> [8/11] 08_sp_checkout_pedidos.sql...';
:r 08_sp_checkout_pedidos.sql
GO

PRINT '>> [9/11] 09_sp_devoluciones.sql...';
:r 09_sp_devoluciones.sql
GO

PRINT '>> [10/11] 10_vistas_dashboard_auditoria.sql...';
:r 10_vistas_dashboard_auditoria.sql
GO

PRINT '>> [11/11] 11_semillas.sql...';
:r 11_semillas.sql
GO

PRINT '--------------------------------------------------------------';
PRINT '  ¡MIGRACIONES Y SEMILLAS APLICADAS SATISFACTORIAMENTE!       ';
PRINT '--------------------------------------------------------------';
GO
