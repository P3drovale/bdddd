-- SISTEMA DE GESTIÓN CLÍNICA DENTAL LARANA
-- TABLAS DE SISTEMA: LOGS, NOTIFICACIONES Y CONFIGURACIONES
-- =====================================================

-- TABLA: notifications
CREATE TABLE notifications (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('info', 'warning', 'error', 'success', 'reminder') NOT NULL DEFAULT 'info',
    method ENUM('email', 'sms', 'whatsapp', 'system') NOT NULL,
    related_entity VARCHAR(50),
    related_id BIGINT UNSIGNED,
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NULL,
    read_at TIMESTAMP NULL,
    retry_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_notifications_user_unread (user_id, is_read),
    INDEX idx_notifications_related (related_entity, related_id),
    INDEX idx_notifications_pending (is_sent, send_at),
    CONSTRAINT chk_notifications_retry CHECK (retry_count <= 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLA: appointment_reminders
CREATE TABLE appointment_reminders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id BIGINT UNSIGNED NOT NULL,
    reminder_type ENUM('email', 'sms', 'whatsapp') NOT NULL,
    hours_before TINYINT UNSIGNED NOT NULL DEFAULT 24,
    send_at TIMESTAMP NOT NULL,
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NULL,
    error_message TEXT,
    retry_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE,
    INDEX idx_reminders_pending (is_sent, send_at),
    INDEX idx_reminders_appointment (appointment_id),
    CONSTRAINT chk_reminders_retry CHECK (retry_count <= 5),
    CONSTRAINT chk_reminders_hours CHECK (hours_before IN (1, 2, 6, 12, 24, 48, 72))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- AUDITORÍA Y LOGS MEJORADOS
-- =====================================================

-- TABLA: audit_logs - Mejorada con control de versiones JWT y metadatos
CREATE TABLE audit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NULL,
    jwt_version INT UNSIGNED NULL COMMENT 'Versión JWT para invalidar sesiones comprometidas',
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id BIGINT UNSIGNED NULL,
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    session_id VARCHAR(255),
    module VARCHAR(50),
    risk_level ENUM('low', 'medium', 'high', 'critical') DEFAULT 'low',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_audit_user_date (user_id, created_at),
    INDEX idx_audit_table_action (table_name, action),
    INDEX idx_audit_risk (risk_level, created_at),
    INDEX idx_audit_session (session_id),
    CONSTRAINT chk_audit_json_old CHECK (old_values IS NULL OR JSON_VALID(old_values)),
    CONSTRAINT chk_audit_json_new CHECK (new_values IS NULL OR JSON_VALID(new_values))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLA: login_attempts - Control de seguridad
CREATE TABLE login_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(191),
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    is_successful BOOLEAN NOT NULL DEFAULT FALSE,
    failure_reason VARCHAR(100),
    blocked_until TIMESTAMP NULL COMMENT 'Hasta cuándo está bloqueado',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_login_ip_date (ip_address, created_at),
    INDEX idx_login_email_date (email, created_at),
    INDEX idx_login_blocked (blocked_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLA: password_resets - Control de tokens
CREATE TABLE password_resets (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(191) NOT NULL,
    token VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45),
    used_at TIMESTAMP NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_password_token (token),
    INDEX idx_password_email_expires (email, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- SOPORTE TÉCNICO
-- =====================================================

-- TABLA: support_tickets
CREATE TABLE support_tickets (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_number VARCHAR(20) NOT NULL UNIQUE,
    user_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category ENUM('technical', 'billing', 'feature_request', 'bug_report', 'other') NOT NULL DEFAULT 'technical',
    priority ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
    status ENUM('open', 'in_progress', 'waiting_response', 'resolved', 'closed') NOT NULL DEFAULT 'open',
    assigned_to BIGINT UNSIGNED NULL,
    resolution TEXT,
    estimated_hours DECIMAL(4,2),
    actual_hours DECIMAL(4,2),
    resolved_at TIMESTAMP NULL,
    closed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_tickets_status_priority (status, priority),
    INDEX idx_tickets_assigned_status (assigned_to, status),
    INDEX idx_tickets_category_date (category, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLA: support_ticket_messages
CREATE TABLE support_ticket_messages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    message TEXT NOT NULL,
    is_internal BOOLEAN NOT NULL DEFAULT FALSE,
    is_solution BOOLEAN NOT NULL DEFAULT FALSE,
    attachments JSON COMMENT 'URLs de archivos adjuntos',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    INDEX idx_ticket_messages_ticket_date (ticket_id, created_at),
    CONSTRAINT chk_ticket_attachments CHECK (attachments IS NULL OR JSON_VALID(attachments))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- CONFIGURACIONES DEL SISTEMA
-- =====================================================

-- TABLA: system_configurations - Mejorada con validaciones
CREATE TABLE system_configurations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(50) NOT NULL DEFAULT 'general',
    key_name VARCHAR(100) NOT NULL,
    value TEXT,
    default_value TEXT,
    description TEXT,
    data_type ENUM('string', 'integer', 'decimal', 'boolean', 'json', 'encrypted') NOT NULL DEFAULT 'string',
    validation_rule VARCHAR(255) COMMENT 'Regex o regla de validación',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si es visible en frontend',
    requires_restart BOOLEAN NOT NULL DEFAULT FALSE,
    last_modified_by BIGINT UNSIGNED,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_config_category_key (category, key_name),
    FOREIGN KEY (last_modified_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_config_category_active (category, is_active),
    INDEX idx_config_public (is_public)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLA: system_maintenance - Ventanas de mantenimiento
CREATE TABLE system_maintenance (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    maintenance_type ENUM('scheduled', 'emergency', 'update') NOT NULL,
    starts_at TIMESTAMP NOT NULL,
    ends_at TIMESTAMP NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    affected_modules JSON COMMENT 'Módulos afectados',
    notification_sent BOOLEAN NOT NULL DEFAULT FALSE,
    created_by BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
    INDEX idx_maintenance_active_dates (is_active, starts_at, ends_at),
    CONSTRAINT chk_maintenance_dates CHECK (ends_at > starts_at),
    CONSTRAINT chk_maintenance_modules CHECK (affected_modules IS NULL OR JSON_VALID(affected_modules))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TRIGGERS PARA AUDITORÍA AUTOMÁTICA
-- =====================================================

DELIMITER //

-- Trigger para auditar cambios críticos en usuarios
CREATE TRIGGER tr_users_audit
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF OLD.email != NEW.email OR OLD.is_active != NEW.is_active OR OLD.role != NEW.role THEN
        INSERT INTO audit_logs (
            user_id, action, table_name, record_id, 
            old_values, new_values, risk_level
        ) VALUES (
            NEW.id, 'update', 'users', NEW.id,
            JSON_OBJECT(
                'email', OLD.email,
                'is_active', OLD.is_active,
                'role', OLD.role
            ),
            JSON_OBJECT(
                'email', NEW.email,
                'is_active', NEW.is_active,
                'role', NEW.role
            ),
            'high'
        );
    END IF;
END//

-- Trigger para crear recordatorios automáticos de citas
CREATE TRIGGER tr_appointment_reminders
AFTER INSERT ON appointments
FOR EACH ROW
BEGIN
    -- Recordatorio 24 horas antes
    INSERT INTO appointment_reminders (
        appointment_id, reminder_type, hours_before, send_at
    ) VALUES (
        NEW.id, 'email', 24, 
        TIMESTAMP(NEW.appointment_date, NEW.appointment_time) - INTERVAL 24 HOUR
    );
    
    -- Recordatorio 2 horas antes para citas del día siguiente
    IF NEW.appointment_date = CURDATE() + INTERVAL 1 DAY THEN
        INSERT INTO appointment_reminders (
            appointment_id, reminder_type, hours_before, send_at
        ) VALUES (
            NEW.id, 'sms', 2,
            TIMESTAMP(NEW.appointment_date, NEW.appointment_time) - INTERVAL 2 HOUR
        );
    END IF;
END//

DELIMITER ;

-- =====================================================
-- DATOS INICIALES DE CONFIGURACIÓN
-- =====================================================

INSERT INTO system_configurations (category, key_name, value, description, data_type, is_public) VALUES
('clinic', 'clinic_name', 'Clínica Dental Larana', 'Nombre de la clínica', 'string', true),
('clinic', 'clinic_address', 'Av. Principal 123, Lima', 'Dirección de la clínica', 'string', true),
('clinic', 'clinic_phone', '+51 999 888 777', 'Teléfono principal', 'string', true),
('clinic', 'clinic_email', 'info@dentalarana.com', 'Email de contacto', 'string', true),

('appointments', 'default_duration', '60', 'Duración por defecto de citas (minutos)', 'integer', false),
('appointments', 'max_daily_appointments', '20', 'Máximo de citas por día', 'integer', false),
('appointments', 'allow_weekend_appointments', 'false', 'Permitir citas en fines de semana', 'boolean', false),
('appointments', 'advance_booking_days', '30', 'Días máximos para agendar con anticipación', 'integer', false),

('notifications', 'email_enabled', 'true', 'Habilitar notificaciones por email', 'boolean', false),
('notifications', 'sms_enabled', 'false', 'Habilitar notificaciones por SMS', 'boolean', false),
('notifications', 'reminder_hours_before', '24', 'Horas antes para recordatorios por defecto', 'integer', false),

('security', 'max_login_attempts', '5', 'Máximo intentos de login antes de bloqueo', 'integer', false),
('security', 'lockout_duration_minutes', '30', 'Duración del bloqueo en minutos', 'integer', false),
('security', 'password_expiry_days', '90', 'Días para expiración de contraseña', 'integer', false),
('security', 'jwt_expiry_hours', '8', 'Horas de validez del JWT', 'integer', false),

('billing', 'tax_rate', '18.00', 'Tasa de IGV (%)', 'decimal', false),
('billing', 'currency', 'PEN', 'Moneda por defecto', 'string', true),
('billing', 'invoice_prefix', 'F001', 'Prefijo de facturas', 'string', false),

('system', 'timezone', 'America/Lima', 'Zona horaria del sistema', 'string', false),
('system', 'date_format', 'd/m/Y', 'Formato de fecha', 'string', true),
('system', 'maintenance_mode', 'false', 'Modo mantenimiento activo', 'boolean', false);


-- =====================================================
-- TABLAS DE SOPORTE NECESARIAS
-- (Estas tablas son referenciadas por las tablas anteriores)
-- =====================================================

-- TABLA: users (Solo estructura básica - ya existe en el sistema)
-- Necesaria para: notifications.user_id, audit_logs.user_id, support_tickets.user_id, etc.
/*
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    dni CHAR(8) NOT NULL UNIQUE,
    email VARCHAR(191) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    -- ... otros campos
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
*/

-- TABLA: appointments (Solo estructura básica - ya existe en el sistema)
-- Necesaria para: appointment_reminders.appointment_id
/*
CREATE TABLE appointments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_code VARCHAR(15) NOT NULL UNIQUE,
    patient_id BIGINT UNSIGNED NOT NULL,
    dentist_id BIGINT UNSIGNED NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    -- ... otros campos
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
*/