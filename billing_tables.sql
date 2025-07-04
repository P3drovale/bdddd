-- =====================================================
-- TABLAS RELACIONADAS CON FACTURACIÓN - MEJORADAS
-- Sistema de Gestión de Clínica Dental Larana
-- =====================================================

-- =====================================================
-- TABLA: payment_methods
-- Descripción: Métodos de pago disponibles (flexibilidad)
-- =====================================================
CREATE TABLE payment_methods (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE COMMENT 'Código único del método',
    name VARCHAR(50) NOT NULL COMMENT 'Nombre del método de pago',
    type ENUM('cash', 'card', 'transfer', 'digital') NOT NULL COMMENT 'Tipo de método',
    requires_reference BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si requiere número de referencia',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Estado del método',
    display_order TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Orden de visualización',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_payment_methods_active (is_active),
    INDEX idx_payment_methods_type (type)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Métodos de pago disponibles';

-- =====================================================
-- TABLA: services (MEJORADA)
-- Descripción: Servicios odontológicos ofrecidos
-- =====================================================
CREATE TABLE services (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE COMMENT 'Código único del servicio',
    name VARCHAR(100) NOT NULL COMMENT 'Nombre del servicio',
    description TEXT COMMENT 'Descripción detallada',
    category VARCHAR(50) NOT NULL COMMENT 'Categoría del servicio',
    price DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Precio base en soles',
    duration_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 30 COMMENT 'Duración estimada en minutos',
    requires_lab BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si requiere laboratorio',
    requires_materials BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si consume materiales del inventario',
    igv_exempt BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si está exento de IGV',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Estado del servicio',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    INDEX idx_services_active (is_active),
    INDEX idx_services_code (code),
    INDEX idx_services_category (category),
    INDEX idx_services_price (price),
    
    CONSTRAINT chk_services_price CHECK (price >= 0),
    CONSTRAINT chk_services_duration CHECK (duration_minutes BETWEEN 5 AND 480)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Servicios odontológicos';

-- =====================================================
-- TABLA: invoices (MEJORADA)
-- Descripción: Facturas y boletas electrónicas
-- =====================================================
CREATE TABLE invoices (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    invoice_number VARCHAR(20) NOT NULL UNIQUE COMMENT 'Número de comprobante electrónico',
    series VARCHAR(4) NOT NULL COMMENT 'Serie del comprobante (B001, F001, etc)',
    correlative VARCHAR(8) NOT NULL COMMENT 'Correlativo numérico',
    invoice_type ENUM('boleta', 'factura') NOT NULL COMMENT 'Tipo de comprobante SUNAT',
    patient_id BIGINT UNSIGNED NOT NULL,
    appointment_id BIGINT UNSIGNED NULL COMMENT 'Cita asociada',
    issue_date DATE NOT NULL COMMENT 'Fecha de emisión',
    due_date DATE COMMENT 'Fecha de vencimiento para facturas',
    
    -- Montos calculados
    subtotal DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Subtotal sin impuestos',
    discount_amount DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Monto de descuento',
    tax_amount DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Monto de IGV (18%)',
    total_amount DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Total a pagar',
    
    -- Estado de pago
    payment_status ENUM('pending', 'partial', 'paid', 'overdue', 'cancelled') NOT NULL DEFAULT 'pending',
    payment_method_id BIGINT UNSIGNED NULL COMMENT 'Método de pago utilizado',
    payment_reference VARCHAR(100) COMMENT 'Referencia de pago (número de operación, etc)',
    payment_date DATE COMMENT 'Fecha de pago efectivo',
    
    -- Estado SUNAT
    sunat_status ENUM('pending', 'accepted', 'rejected', 'sent') NOT NULL DEFAULT 'pending',
    sunat_response TEXT COMMENT 'Respuesta de SUNAT',
    sunat_sent_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Fecha de envío a SUNAT',
    sunat_hash VARCHAR(255) COMMENT 'Hash del XML para validación',
    
    -- Archivos generados
    xml_filename VARCHAR(255) COMMENT 'Nombre del archivo XML generado',
    pdf_filename VARCHAR(255) COMMENT 'Nombre del archivo PDF generado',
    
    -- Auditoría
    created_by BIGINT UNSIGNED NOT NULL,
    approved_by BIGINT UNSIGNED NULL COMMENT 'Usuario que aprobó la factura',
    approved_at TIMESTAMP NULL DEFAULT NULL,
    cancelled_by BIGINT UNSIGNED NULL COMMENT 'Usuario que canceló',
    cancelled_at TIMESTAMP NULL DEFAULT NULL,
    cancellation_reason TEXT COMMENT 'Motivo de cancelación',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (cancelled_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_invoices_number (invoice_number),
    INDEX idx_invoices_series_correlative (series, correlative),
    INDEX idx_invoices_patient (patient_id),
    INDEX idx_invoices_date (issue_date),
    INDEX idx_invoices_status (payment_status),
    INDEX idx_invoices_sunat (sunat_status),
    INDEX idx_invoices_appointment (appointment_id),
    INDEX idx_invoices_created_by (created_by),
    INDEX idx_invoices_payment_date (payment_date),
    
    CONSTRAINT chk_invoices_amounts CHECK (
        subtotal >= 0 AND 
        discount_amount >= 0 AND 
        tax_amount >= 0 AND 
        total_amount >= 0 AND
        total_amount = (subtotal - discount_amount + tax_amount)
    ),
    CONSTRAINT chk_invoices_due_date CHECK (due_date IS NULL OR due_date >= issue_date),
    CONSTRAINT chk_invoices_series_format CHECK (
        series REGEXP '^[BF][0-9]{3}$'
    ),
    CONSTRAINT chk_invoices_correlative_format CHECK (
        correlative REGEXP '^[0-9]{1,8}$'
    ),
    CONSTRAINT chk_invoices_payment_reference CHECK (
        payment_method_id IS NULL OR 
        (payment_reference IS NOT NULL AND LENGTH(payment_reference) >= 3)
        OR payment_reference IS NULL
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Facturas y boletas';

-- =====================================================
-- TABLA: invoice_details (MEJORADA)
-- Descripción: Detalle de servicios en cada factura
-- =====================================================
CREATE TABLE invoice_details (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    invoice_id BIGINT UNSIGNED NOT NULL,
    service_id BIGINT UNSIGNED NOT NULL,
    quantity SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Cantidad de servicios',
    unit_price DECIMAL(8,2) UNSIGNED NOT NULL COMMENT 'Precio unitario',
    discount_percentage DECIMAL(5,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Porcentaje de descuento',
    discount_amount DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Monto de descuento aplicado',
    subtotal DECIMAL(10,2) UNSIGNED NOT NULL COMMENT 'Subtotal antes de impuestos',
    tax_percentage DECIMAL(5,2) UNSIGNED NOT NULL DEFAULT 18.00 COMMENT 'Porcentaje de IGV',
    tax_amount DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Monto de IGV',
    total_price DECIMAL(10,2) UNSIGNED NOT NULL COMMENT 'Precio total línea',
    
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_invoice_details_invoice (invoice_id),
    INDEX idx_invoice_details_service (service_id),
    
    CONSTRAINT chk_invoice_details_quantity CHECK (quantity > 0),
    CONSTRAINT chk_invoice_details_price CHECK (unit_price >= 0),
    CONSTRAINT chk_invoice_details_discount_pct CHECK (discount_percentage BETWEEN 0 AND 100),
    CONSTRAINT chk_invoice_details_tax_pct CHECK (tax_percentage BETWEEN 0 AND 25),
    CONSTRAINT chk_invoice_details_amounts CHECK (
        discount_amount >= 0 AND
        tax_amount >= 0 AND
        subtotal >= 0 AND
        total_price >= 0
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Detalles de facturas';

-- =====================================================
-- TABLA: invoice_payments
-- Descripción: Registro de pagos por factura
-- =====================================================
CREATE TABLE invoice_payments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    invoice_id BIGINT UNSIGNED NOT NULL,
    payment_method_id BIGINT UNSIGNED NOT NULL,
    amount DECIMAL(10,2) UNSIGNED NOT NULL COMMENT 'Monto del pago',
    payment_date DATE NOT NULL COMMENT 'Fecha del pago',
    reference VARCHAR(100) COMMENT 'Número de referencia/operación',
    notes TEXT COMMENT 'Observaciones del pago',
    processed_by BIGINT UNSIGNED NOT NULL COMMENT 'Usuario que registró el pago',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (processed_by) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_invoice_payments_invoice (invoice_id),
    INDEX idx_invoice_payments_date (payment_date),
    INDEX idx_invoice_payments_method (payment_method_id),
    
    CONSTRAINT chk_invoice_payments_amount CHECK (amount > 0)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Pagos realizados por factura';

-- =====================================================
-- TRIGGERS PARA INTEGRIDAD Y AUTOMATIZACIÓN
-- =====================================================

-- Trigger para validar correlatividad de facturas
DELIMITER $$

CREATE TRIGGER trg_invoices_correlative_check
    BEFORE INSERT ON invoices
    FOR EACH ROW
BEGIN
    DECLARE last_correlative INT DEFAULT 0;
    DECLARE next_correlative INT;
    
    -- Obtener el último correlativo de la serie
    SELECT CAST(correlative AS UNSIGNED) INTO last_correlative
    FROM invoices 
    WHERE series = NEW.series 
    ORDER BY CAST(correlative AS UNSIGNED) DESC 
    LIMIT 1;
    
    SET next_correlative = COALESCE(last_correlative, 0) + 1;
    
    -- Si no se especifica correlativo, asignar el siguiente
    IF NEW.correlative IS NULL OR NEW.correlative = '' THEN
        SET NEW.correlative = LPAD(next_correlative, 8, '0');
    ELSE
        -- Validar que el correlativo sea secuencial
        IF CAST(NEW.correlative AS UNSIGNED) != next_correlative THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'El correlativo debe ser secuencial';
        END IF;
    END IF;
    
    -- Generar número de factura completo
    SET NEW.invoice_number = CONCAT(NEW.series, '-', NEW.correlative);
END$$

-- Trigger para actualizar totales de factura
CREATE TRIGGER trg_invoice_details_update_totals
    AFTER INSERT ON invoice_details
    FOR EACH ROW
BEGIN
    CALL sp_update_invoice_totals(NEW.invoice_id);
END$$

CREATE TRIGGER trg_invoice_details_update_totals_upd
    AFTER UPDATE ON invoice_details
    FOR EACH ROW
BEGIN
    CALL sp_update_invoice_totals(NEW.invoice_id);
END$$

CREATE TRIGGER trg_invoice_details_update_totals_del
    AFTER DELETE ON invoice_details
    FOR EACH ROW
BEGIN
    CALL sp_update_invoice_totals(OLD.invoice_id);
END$$

DELIMITER ;

-- =====================================================
-- PROCEDIMIENTOS ALMACENADOS
-- =====================================================

DELIMITER $$

-- Procedimiento para actualizar totales de factura
CREATE PROCEDURE sp_update_invoice_totals(IN p_invoice_id BIGINT UNSIGNED)
BEGIN
    DECLARE v_subtotal DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_discount DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_tax DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;
    
    -- Calcular totales desde los detalles
    SELECT 
        COALESCE(SUM(subtotal), 0.00),
        COALESCE(SUM(discount_amount), 0.00),
        COALESCE(SUM(tax_amount), 0.00),
        COALESCE(SUM(total_price), 0.00)
    INTO v_subtotal, v_discount, v_tax, v_total
    FROM invoice_details 
    WHERE invoice_id = p_invoice_id;
    
    -- Actualizar factura
    UPDATE invoices 
    SET 
        subtotal = v_subtotal,
        discount_amount = v_discount,
        tax_amount = v_tax,
        total_amount = v_total,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_invoice_id;
END$$

-- Procedimiento para calcular montos de detalle
CREATE PROCEDURE sp_calculate_invoice_detail_amounts(
    IN p_quantity SMALLINT UNSIGNED,
    IN p_unit_price DECIMAL(8,2),
    IN p_discount_percentage DECIMAL(5,2),
    IN p_tax_percentage DECIMAL(5,2),
    OUT p_subtotal DECIMAL(10,2),
    OUT p_discount_amount DECIMAL(8,2),
    OUT p_tax_amount DECIMAL(8,2),
    OUT p_total DECIMAL(10,2)
)
BEGIN
    DECLARE v_gross_amount DECIMAL(10,2);
    
    -- Monto bruto
    SET v_gross_amount = p_quantity * p_unit_price;
    
    -- Descuento
    SET p_discount_amount = v_gross_amount * (p_discount_percentage / 100);
    
    -- Subtotal después del descuento
    SET p_subtotal = v_gross_amount - p_discount_amount;
    
    -- Impuesto sobre el subtotal
    SET p_tax_amount = p_subtotal * (p_tax_percentage / 100);
    
    -- Total final
    SET p_total = p_subtotal + p_tax_amount;
END$$

DELIMITER ;

-- =====================================================
-- DATOS INICIALES PARA MÉTODOS DE PAGO
-- =====================================================

INSERT INTO payment_methods (code, name, type, requires_reference, display_order) VALUES
('CASH', 'Efectivo', 'cash', FALSE, 1),
('CARD_VISA', 'Tarjeta Visa', 'card', TRUE, 2),
('CARD_MC', 'Tarjeta Mastercard', 'card', TRUE, 3),
('TRANSFER', 'Transferencia Bancaria', 'transfer', TRUE, 4),
('YAPE', 'Yape', 'digital', TRUE, 5),
('PLIN', 'Plin', 'digital', TRUE, 6),
('DEPOSIT', 'Depósito Bancario', 'transfer', TRUE, 7);

-- =====================================================
-- COMENTARIOS DE MEJORAS IMPLEMENTADAS
-- =====================================================

/*
MEJORAS IMPLEMENTADAS:

1. FLEXIBILIDAD EN MÉTODOS DE PAGO:
   - Tabla payment_methods separada para mayor flexibilidad
   - Soporte para múltiples pagos por factura (invoice_payments)

2. VALIDACIONES SUNAT:
   - Validación de formato de series (B001, F001, etc.)
   - Validación de correlativos numéricos
   - Control de correlatividad secuencial mediante trigger

3. CÁLCULOS AUTOMÁTICOS:
   - Triggers para actualizar totales automáticamente
   - Procedimientos para cálculos consistentes
   - Separación clara de montos (subtotal, descuento, impuestos)

4. TRAZABILIDAD MEJORADA:
   - Campos de auditoría completos (creado, aprobado, cancelado)
   - Registro detallado de pagos con usuario responsable
   - Referencias de pago para trazabilidad

5. RENDIMIENTO:
   - Índices compuestos para consultas frecuentes
   - Índices por fecha, estado, paciente

6. INTEGRIDAD DE DATOS:
   - Constraints mejorados para validar montos
   - Validación de referencias de pago cuando es requerido
   - Control de estados y transiciones

7. CUMPLIMIENTO FISCAL:
   - Soporte para exención de IGV por servicio
   - Hash de XML para validación de integridad
   - Campos específicos para respuesta SUNAT
*/