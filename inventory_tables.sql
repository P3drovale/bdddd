-- =====================================================
-- SISTEMA DE INVENTARIO MEJORADO - DENTAL CLINIC
-- =====================================================

-- TABLA: inventory_categories
CREATE TABLE inventory_categories (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id BIGINT UNSIGNED NULL,
    category_code VARCHAR(20) NOT NULL UNIQUE,
    level TINYINT UNSIGNED NOT NULL DEFAULT 1,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    FOREIGN KEY (parent_id) REFERENCES inventory_categories(id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_parent (parent_id),
    INDEX idx_active (is_active),
    INDEX idx_code (category_code),
    INDEX idx_level (level),
    
    CONSTRAINT chk_level CHECK (level BETWEEN 1 AND 5),
    CONSTRAINT chk_sort_order CHECK (sort_order >= 0)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- TABLA: inventory_items (Mejorada con controles de seguridad)
CREATE TABLE inventory_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    barcode VARCHAR(100) UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    category_id BIGINT UNSIGNED NOT NULL,
    unit_of_measure ENUM('piece', 'box', 'bottle', 'tube', 'vial', 'kit', 'pack', 'ml', 'gr', 'unit') NOT NULL DEFAULT 'piece',
    
    -- Control de stock mejorado
    minimum_stock DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0,
    maximum_stock DECIMAL(10,2) UNSIGNED,
    current_stock DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0,
    reserved_stock DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0,
    available_stock DECIMAL(10,2) UNSIGNED GENERATED ALWAYS AS (current_stock - reserved_stock) STORED,
    
    -- Costos y precios
    unit_cost DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0,
    last_purchase_cost DECIMAL(10,2) UNSIGNED,
    
    -- Información del proveedor
    primary_supplier VARCHAR(100),
    supplier_code VARCHAR(50),
    
    -- Control de vencimiento
    has_expiration BOOLEAN NOT NULL DEFAULT FALSE,
    expiration_date DATE,
    expiration_alert_days INT UNSIGNED DEFAULT 30,
    
    -- Ubicación y estado
    location VARCHAR(100),
    storage_conditions TEXT,
    is_controlled BOOLEAN NOT NULL DEFAULT FALSE,
    requires_prescription BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Auditoría
    created_by BIGINT UNSIGNED,
    updated_by BIGINT UNSIGNED,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    FOREIGN KEY (category_id) REFERENCES inventory_categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_code (code),
    INDEX idx_barcode (barcode),
    INDEX idx_category (category_id),
    INDEX idx_stock_level (current_stock, minimum_stock),
    INDEX idx_expiration (expiration_date, has_expiration),
    INDEX idx_active (is_active),
    INDEX idx_supplier (primary_supplier),
    INDEX idx_controlled (is_controlled),
    
    CONSTRAINT chk_stock CHECK (
        current_stock >= 0 AND 
        minimum_stock >= 0 AND 
        reserved_stock >= 0 AND
        reserved_stock <= current_stock AND
        (maximum_stock IS NULL OR maximum_stock >= minimum_stock)
    ),
    CONSTRAINT chk_cost CHECK (unit_cost >= 0 AND (last_purchase_cost IS NULL OR last_purchase_cost >= 0)),
    CONSTRAINT chk_expiration CHECK (
        (has_expiration = FALSE) OR 
        (has_expiration = TRUE AND expiration_alert_days IS NOT NULL AND expiration_alert_days > 0)
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- TABLA: inventory_movements (Con validaciones mejoradas)
CREATE TABLE inventory_movements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    item_id BIGINT UNSIGNED NOT NULL,
    movement_type ENUM('purchase', 'consumption', 'adjustment', 'transfer', 'return', 'waste', 'expired') NOT NULL,
    movement_category ENUM('in', 'out', 'adjustment') NOT NULL,
    
    -- Cantidades y costos
    quantity DECIMAL(10,2) NOT NULL,
    unit_cost DECIMAL(10,2) UNSIGNED,
    total_cost DECIMAL(12,2) UNSIGNED GENERATED ALWAYS AS (ABS(quantity) * IFNULL(unit_cost, 0)) STORED,
    
    -- Control de stock con validación automática
    previous_stock DECIMAL(10,2) UNSIGNED NOT NULL,
    new_stock DECIMAL(10,2) UNSIGNED NOT NULL,
    
    -- Información del movimiento
    reason VARCHAR(255) NOT NULL,
    reference_document VARCHAR(100),
    batch_number VARCHAR(50),
    expiration_date DATE,
    
    -- Relaciones
    appointment_id BIGINT UNSIGNED,
    patient_id BIGINT UNSIGNED,
    treatment_id BIGINT UNSIGNED,
    supplier_id BIGINT UNSIGNED,
    
    -- Ubicación
    from_location VARCHAR(100),
    to_location VARCHAR(100),
    
    -- Control de aprobación mejorado
    user_id BIGINT UNSIGNED NOT NULL,
    approved_by BIGINT UNSIGNED,
    approval_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_approved BOOLEAN NOT NULL DEFAULT TRUE,
    approval_date TIMESTAMP NULL,
    
    -- Metadatos
    notes TEXT,
    metadata JSON,
    
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    FOREIGN KEY (item_id) REFERENCES inventory_items(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_item (item_id),
    INDEX idx_type (movement_type, movement_category),
    INDEX idx_date (created_at),
    INDEX idx_user (user_id),
    INDEX idx_approval (is_approved, approval_required),
    INDEX idx_appointment (appointment_id),
    INDEX idx_patient (patient_id),
    INDEX idx_batch (batch_number),
    INDEX idx_reference (reference_document),
    
    CONSTRAINT chk_quantity CHECK (
        (movement_category = 'in' AND quantity > 0) OR
        (movement_category = 'out' AND quantity < 0) OR
        (movement_category = 'adjustment')
    ),
    CONSTRAINT chk_stock_values CHECK (previous_stock >= 0 AND new_stock >= 0),
    CONSTRAINT chk_approval_logic CHECK (
        (approval_required = FALSE) OR 
        (approval_required = TRUE AND ((is_approved = FALSE AND approved_by IS NULL) OR (is_approved = TRUE AND approved_by IS NOT NULL)))
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- TABLA: inventory_batches (Control de lotes FIFO)
CREATE TABLE inventory_batches (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    item_id BIGINT UNSIGNED NOT NULL,
    batch_number VARCHAR(50) NOT NULL,
    expiration_date DATE NOT NULL,
    purchase_date DATE NOT NULL,
    quantity_received DECIMAL(10,2) UNSIGNED NOT NULL,
    quantity_current DECIMAL(10,2) UNSIGNED NOT NULL,
    unit_cost DECIMAL(10,2) UNSIGNED NOT NULL,
    supplier VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    FOREIGN KEY (item_id) REFERENCES inventory_items(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    UNIQUE KEY uk_item_batch (item_id, batch_number),
    INDEX idx_expiration (expiration_date, is_active),
    INDEX idx_quantity (quantity_current),
    INDEX idx_fifo (item_id, expiration_date, quantity_current),
    
    CONSTRAINT chk_batch_quantity CHECK (
        quantity_received > 0 AND 
        quantity_current >= 0 AND 
        quantity_current <= quantity_received
    ),
    CONSTRAINT chk_batch_dates CHECK (expiration_date > purchase_date)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- TABLA: inventory_alerts (Sistema de alertas inteligente)
CREATE TABLE inventory_alerts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    item_id BIGINT UNSIGNED NOT NULL,
    alert_type ENUM('low_stock', 'expiring_soon', 'expired', 'overstock', 'inactive_item', 'batch_depleted') NOT NULL,
    alert_level ENUM('info', 'warning', 'critical') NOT NULL DEFAULT 'warning',
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    threshold_value DECIMAL(10,2),
    current_value DECIMAL(10,2),
    expiration_date DATE,
    batch_number VARCHAR(50),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by BIGINT UNSIGNED,
    resolved_at TIMESTAMP NULL,
    auto_resolve_date TIMESTAMP NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    
    FOREIGN KEY (item_id) REFERENCES inventory_items(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_item (item_id),
    INDEX idx_type_level (alert_type, alert_level),
    INDEX idx_status (is_read, is_resolved),
    INDEX idx_expiration (expiration_date),
    INDEX idx_created (created_at),
    INDEX idx_auto_resolve (auto_resolve_date),
    
    UNIQUE KEY uk_item_type_active (item_id, alert_type, is_resolved)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TRIGGERS PARA AUTOMATIZACIÓN INTELIGENTE
-- =====================================================

DELIMITER $$

-- Trigger principal: Actualización automática de stock con validaciones
CREATE TRIGGER tr_inventory_movements_after_insert 
AFTER INSERT ON inventory_movements
FOR EACH ROW
BEGIN
    DECLARE item_min_stock DECIMAL(10,2);
    DECLARE item_name VARCHAR(150);
    
    -- Actualizar stock del artículo con costo promedio ponderado
    UPDATE inventory_items 
    SET current_stock = NEW.new_stock,
        unit_cost = CASE 
            WHEN NEW.movement_category = 'in' AND NEW.unit_cost IS NOT NULL THEN 
                CASE 
                    WHEN current_stock > 0 THEN 
                        ((current_stock * unit_cost) + (ABS(NEW.quantity) * NEW.unit_cost)) / (current_stock + ABS(NEW.quantity))
                    ELSE NEW.unit_cost
                END
            ELSE unit_cost
        END,
        last_purchase_cost = CASE 
            WHEN NEW.movement_type = 'purchase' AND NEW.unit_cost IS NOT NULL THEN NEW.unit_cost
            ELSE last_purchase_cost
        END,
        updated_at = NOW()
    WHERE id = NEW.item_id;
    
    -- Obtener datos para alertas
    SELECT minimum_stock, name INTO item_min_stock, item_name 
    FROM inventory_items WHERE id = NEW.item_id;
    
    -- Resolver alertas de stock bajo si se repone
    IF NEW.movement_category = 'in' AND NEW.new_stock > item_min_stock THEN
        UPDATE inventory_alerts 
        SET is_resolved = TRUE, resolved_at = NOW(), auto_resolve_date = NOW()
        WHERE item_id = NEW.item_id AND alert_type = 'low_stock' AND is_resolved = FALSE;
    END IF;
    
    -- Generar alerta de stock bajo/crítico
    IF NEW.new_stock <= item_min_stock THEN
        INSERT INTO inventory_alerts (
            item_id, alert_type, alert_level, title, message, 
            threshold_value, current_value, created_at
        ) VALUES (
            NEW.item_id, 
            'low_stock', 
            CASE WHEN NEW.new_stock = 0 THEN 'critical' ELSE 'warning' END,
            CASE WHEN NEW.new_stock = 0 THEN CONCAT('SIN STOCK: ', item_name) ELSE CONCAT('Stock bajo: ', item_name) END,
            CONCAT('Artículo "', item_name, '" - Stock actual: ', NEW.new_stock, ', Mínimo: ', item_min_stock),
            item_min_stock, 
            NEW.new_stock, 
            NOW()
        )
        ON DUPLICATE KEY UPDATE 
            alert_level = CASE WHEN NEW.new_stock = 0 THEN 'critical' ELSE 'warning' END,
            current_value = NEW.new_stock,
            is_resolved = FALSE,
            updated_at = NOW();
    END IF;
    
    -- Actualizar lote si aplica
    IF NEW.batch_number IS NOT NULL AND NEW.movement_category = 'out' THEN
        UPDATE inventory_batches 
        SET quantity_current = quantity_current + NEW.quantity,
            updated_at = NOW()
        WHERE item_id = NEW.item_id AND batch_number = NEW.batch_number;
    END IF;
END$$

-- Trigger de validación pre-inserción (Crítico para integridad)
CREATE TRIGGER tr_inventory_movements_before_insert 
BEFORE INSERT ON inventory_movements
FOR EACH ROW
BEGIN
    DECLARE current_stock_val DECIMAL(10,2);
    DECLARE item_active BOOLEAN;
    
    -- Validar que el artículo esté activo
    SELECT current_stock, is_active INTO current_stock_val, item_active 
    FROM inventory_items WHERE id = NEW.item_id;
    
    IF item_active = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se pueden realizar movimientos en artículos inactivos';
    END IF;
    
    -- Validar coherencia de stock anterior
    IF NEW.previous_stock != current_stock_val THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock anterior no coincide. Actualice y reintente';
    END IF;
    
    -- Validar que no se produzca stock negativo
    IF NEW.new_stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock resultante no puede ser negativo';
    END IF;
    
    -- Validar coherencia matemática de movimientos
    IF NEW.movement_category IN ('in', 'out') AND NEW.new_stock != (NEW.previous_stock + NEW.quantity) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error en cálculo de stock resultante';
    END IF;
    
    -- Validar aprobación para movimientos críticos
    IF NEW.movement_type IN ('waste', 'expired', 'adjustment') AND ABS(NEW.quantity) > 100 AND NEW.approval_required = FALSE THEN
        SET NEW.approval_required = TRUE;
        SET NEW.is_approved = FALSE;
    END IF;
END$$

-- Trigger para auto-resolución de alertas expiradas
CREATE TRIGGER tr_inventory_alerts_before_update
BEFORE UPDATE ON inventory_alerts
FOR EACH ROW
BEGIN
    -- Auto-resolver alertas de vencimiento si el stock llegó a cero
    IF NEW.alert_type = 'expiring_soon' AND OLD.is_resolved = FALSE THEN
        IF (SELECT current_stock FROM inventory_items WHERE id = NEW.item_id) = 0 THEN
            SET NEW.is_resolved = TRUE;
            SET NEW.auto_resolve_date = NOW();
        END IF;
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- PROCEDIMIENTOS ALMACENADOS OPTIMIZADOS
-- =====================================================

DELIMITER $$

-- Generar alertas de vencimiento (Ejecutar diariamente)
CREATE PROCEDURE sp_generate_expiration_alerts()
BEGIN
    -- Limpiar alertas auto-resueltas antiguas
    DELETE FROM inventory_alerts 
    WHERE auto_resolve_date IS NOT NULL AND auto_resolve_date < DATE_SUB(NOW(), INTERVAL 30 DAY);
    
    -- Alertas para artículos próximos a vencer
    INSERT INTO inventory_alerts (
        item_id, alert_type, alert_level, title, message, 
        expiration_date, created_at
    )
    SELECT 
        i.id,
        'expiring_soon',
        CASE 
            WHEN DATEDIFF(i.expiration_date, CURDATE()) <= 7 THEN 'critical'
            WHEN DATEDIFF(i.expiration_date, CURDATE()) <= 15 THEN 'warning'
            ELSE 'info'
        END,
        CONCAT('Vence: ', i.name, ' (', DATEDIFF(i.expiration_date, CURDATE()), ' días)'),
        CONCAT('Artículo "', i.name, '" vence ', DATE_FORMAT(i.expiration_date, '%d/%m/%Y')),
        i.expiration_date,
        NOW()
    FROM inventory_items i
    WHERE i.has_expiration = TRUE 
      AND i.expiration_date IS NOT NULL
      AND i.expiration_date <= DATE_ADD(CURDATE(), INTERVAL IFNULL(i.expiration_alert_days, 30) DAY)
      AND i.current_stock > 0
      AND i.is_active = TRUE
    ON DUPLICATE KEY UPDATE 
        alert_level = VALUES(alert_level),
        message = VALUES(message),
        is_resolved = FALSE,
        updated_at = NOW();
        
    -- Alertas para artículos vencidos
    INSERT INTO inventory_alerts (
        item_id, alert_type, alert_level, title, message, 
        expiration_date, created_at
    )
    SELECT 
        i.id,
        'expired',
        'critical',
        CONCAT('VENCIDO: ', i.name),
        CONCAT('Artículo "', i.name, '" venció ', DATE_FORMAT(i.expiration_date, '%d/%m/%Y')),
        i.expiration_date,
        NOW()
    FROM inventory_items i
    WHERE i.has_expiration = TRUE 
      AND i.expiration_date < CURDATE()
      AND i.current_stock > 0
      AND i.is_active = TRUE
    ON DUPLICATE KEY UPDATE 
        is_resolved = FALSE,
        updated_at = NOW();
        
    -- Alertas para lotes agotados
    INSERT INTO inventory_alerts (
        item_id, alert_type, alert_level, title, message, 
        batch_number, created_at
    )
    SELECT 
        b.item_id,
        'batch_depleted',
        'info',
        CONCAT('Lote agotado: ', i.name),
        CONCAT('Lote "', b.batch_number, '" del artículo "', i.name, '" se ha agotado'),
        b.batch_number,
        NOW()
    FROM inventory_batches b
    INNER JOIN inventory_items i ON b.item_id = i.id
    WHERE b.quantity_current = 0 
      AND b.is_active = TRUE
    ON DUPLICATE KEY UPDATE updated_at = NOW();
    
    -- Desactivar lotes agotados
    UPDATE inventory_batches 
    SET is_active = FALSE, updated_at = NOW()
    WHERE quantity_current = 0 AND is_active = TRUE;
END$$

-- Reporte de stock crítico optimizado
CREATE PROCEDURE sp_critical_stock_report()
BEGIN
    SELECT 
        i.code,
        i.name,
        c.name AS category,
        i.current_stock,
        i.minimum_stock,
        i.unit_of_measure,
        i.location,
        i.primary_supplier,
        CASE 
            WHEN i.current_stock = 0 THEN 'SIN STOCK'
            WHEN i.current_stock <= i.minimum_stock * 0.5 THEN 'CRÍTICO'
            ELSE 'BAJO'
        END AS status,
        DATEDIFF(CURDATE(), IFNULL(
            (SELECT MAX(created_at) FROM inventory_movements m WHERE m.item_id = i.id AND m.movement_type = 'purchase'),
            i.created_at
        )) AS days_since_last_purchase,
        i.unit_cost * (i.minimum_stock * 2) AS recommended_purchase_value
    FROM inventory_items i
    INNER JOIN inventory_categories c ON i.category_id = c.id
    WHERE i.current_stock <= i.minimum_stock 
      AND i.is_active = TRUE
    ORDER BY 
        CASE 
            WHEN i.current_stock = 0 THEN 1
            WHEN i.current_stock <= i.minimum_stock * 0.5 THEN 2
            ELSE 3
        END,
        i.current_stock ASC,
        i.name;
END$$

-- Movimiento de inventario con validaciones
CREATE PROCEDURE sp_create_inventory_movement(
    IN p_item_id BIGINT UNSIGNED,
    IN p_movement_type VARCHAR(20),
    IN p_quantity DECIMAL(10,2),
    IN p_reason VARCHAR(255),
    IN p_user_id BIGINT UNSIGNED,
    IN p_unit_cost DECIMAL(10,2),
    IN p_batch_number VARCHAR(50),
    OUT p_movement_id BIGINT UNSIGNED,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE current_stock_val DECIMAL(10,2);
    DECLARE new_stock_val DECIMAL(10,2);
    DECLARE movement_category_val VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Error al procesar movimiento de inventario';
        SET p_movement_id = NULL;
    END;
    
    START TRANSACTION;
    
    -- Obtener stock actual
    SELECT current_stock INTO current_stock_val 
    FROM inventory_items WHERE id = p_item_id AND is_active = TRUE;
    
    IF current_stock_val IS NULL THEN
        SET p_success = FALSE;
        SET p_message = 'Artículo no encontrado o inactivo';
        ROLLBACK;
    ELSE
        -- Determinar categoría de movimiento
        SET movement_category_val = CASE 
            WHEN p_movement_type IN ('purchase', 'return') THEN 'in'
            WHEN p_movement_type IN ('consumption', 'waste', 'expired', 'transfer') THEN 'out'
            ELSE 'adjustment'
        END;
        
        -- Calcular nuevo stock
        SET new_stock_val = current_stock_val + p_quantity;
        
        -- Validar stock suficiente para salidas
        IF movement_category_val = 'out' AND new_stock_val < 0 THEN
            SET p_success = FALSE;
            SET p_message = 'Stock insuficiente para el movimiento';
            ROLLBACK;
        ELSE
            -- Insertar movimiento
            INSERT INTO inventory_movements (
                item_id, movement_type, movement_category, quantity, 
                previous_stock, new_stock, reason, user_id, unit_cost, 
                batch_number, created_at
            ) VALUES (
                p_item_id, p_movement_type, movement_category_val, p_quantity,
                current_stock_val, new_stock_val, p_reason, p_user_id, 
                p_unit_cost, p_batch_number, NOW()
            );
            
            SET p_movement_id = LAST_INSERT_ID();
            SET p_success = TRUE;
            SET p_message = 'Movimiento registrado exitosamente';
            COMMIT;
        END IF;
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- VISTAS OPTIMIZADAS PARA CONSULTAS FRECUENTES
-- =====================================================

-- Vista de inventario con alertas
CREATE VIEW v_inventory_status AS
SELECT 
    i.id,
    i.code,
    i.name,
    c.name AS category_name,
    i.current_stock,
    i.minimum_stock,
    i.available_stock,
    i.unit_of_measure,
    i.unit_cost,
    i.location,
    i.has_expiration,
    i.expiration_date,
    CASE 
        WHEN i.current_stock = 0 THEN 'SIN STOCK'
        WHEN i.current_stock <= i.minimum_stock * 0.5 THEN 'CRÍTICO'
        WHEN i.current_stock <= i.minimum_stock THEN 'BAJO'
        WHEN i.maximum_stock IS NOT NULL AND i.current_stock >= i.maximum_stock THEN 'EXCESO'
        ELSE 'NORMAL'
    END AS stock_status,
    (SELECT COUNT(*) FROM inventory_alerts a 
     WHERE a.item_id = i.id AND a.is_resolved = FALSE) AS active_alerts,
    i.is_active
FROM inventory_items i
INNER JOIN inventory_categories c ON i.category_id = c.id;

-- Vista de alertas pendientes
CREATE VIEW v_pending_alerts AS
SELECT 
    a.id,
    a.alert_type,
    a.alert_level,
    a.title,
    a.message,
    i.code AS item_code,
    i.name AS item_name,
    c.name AS category_name,
    a.current_value,
    a.threshold_value,
    a.expiration_date,
    a.created_at,
    CASE 
        WHEN a.alert_type = 'expired' THEN 1
        WHEN a.alert_type = 'expiring_soon' AND a.alert_level = 'critical' THEN 2
        WHEN a.alert_level = 'critical' THEN 3
        WHEN a.alert_level = 'warning' THEN 4
        ELSE 5
    END AS priority_order
FROM inventory_alerts a
INNER JOIN inventory_items i ON a.item_id = i.id
INNER JOIN inventory_categories c ON i.category_id = c.id
WHERE a.is_resolved = FALSE
ORDER BY priority_order, a.created_at;