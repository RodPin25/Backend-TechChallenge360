

-- ============================================================================
-- MODULO 2
-- ============================================================================
-- ============================================================================
-- FUNCIÓN AUXILIAR: CALCULAR STOCK DISPONIBLE (RF-02, RF-03)
-- StockDisponible = StockFisico - ReservasActivasNoExpiradas
-- ============================================================================

CREATE OR ALTER FUNCTION dbo.FN_Inventario_StockDisponible (@IDVariante INT)
RETURNS INT
AS
BEGIN
    DECLARE @StockFisico INT = 0;
    DECLARE @ReservasActivas INT = 0;

    -- 1. Obtener existencias físicas actuales
    SELECT @StockFisico = StockFisico
    FROM dbo.Variantes
    WHERE IDVariante = @IDVariante;

    -- 2. Sumar cantidades con reserva temporal activa vigente
    SELECT @ReservasActivas = ISNULL(SUM(Cantidad), 0)
    FROM dbo.ReservasExistencia
    WHERE IDVariante = @IDVariante
      AND Estado = 'ACTIVA'
      AND FechaExpiracion > SYSDATETIME();

    DECLARE @Disponible INT = @StockFisico - @ReservasActivas;

    RETURN CASE WHEN @Disponible < 0 THEN 0 ELSE @Disponible END;
END;
GO