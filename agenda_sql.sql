-- =====================================================
-- SISTEMA DE AGENDA - CITAS Y PROGRAMACIÓN
-- Clínica Dental Larana - Módulo de Agenda MEJORADO
-- =====================================================

-- =====================================================
-- TABLA: appointment_statuses
-- Descripción: Estados posibles de las citas
-- =====================================================
CREATE TABLE appointment_statuses (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE COMMENT 'Nombre del estado',
    display_name VARCHAR(100) NOT NULL COMMENT 'Nombre para mostrar',
    description TEXT COMMENT 'Descripción del estado',
    color CHAR(7) NOT NULL DEFAULT '#6B7280' COMMENT 'Color hexadecimal para UI',
    can_modify BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Si se puede modificar la cita en este estado',
    can_cancel BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Si se puede cancelar la cita en este estado',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Estado activo del status',
    display_order TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Orden de visualización',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_appointment_statuses_active (is_active),
    INDEX idx_appointment_statuses_order (display_order),
    CONSTRAINT chk_appointment_statuses_color CHECK (color REGEXP '^#[0-9A-Fa-f]{6}$')
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Estados de citas';

-- =====================================================
-- TABLA: appointments
-- Descripción: Citas médicas programadas
-- =====================================================
CREATE TABLE appointments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_code VARCHAR(15) NOT NULL UNIQUE COMMENT 'Código único (formato: CITA-YYYYMM-XXXX)',
    patient_id BIGINT UNSIGNED NOT NULL COMMENT 'ID del paciente',
    dentist_id BIGINT UNSIGNED NOT NULL COMMENT 'ID del odontólogo',
    appointment_date DATE NOT NULL COMMENT 'Fecha de la cita',
    appointment_time TIME NOT NULL COMMENT 'Hora de la cita',
    duration_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 30 COMMENT 'Duración en minutos',
    end_time TIME GENERATED ALWAYS AS (ADDTIME(appointment_time, SEC_TO_TIME(duration_minutes * 60))) STORED COMMENT 'Hora calculada de fin',
    reason TEXT COMMENT 'Motivo de la consulta',
    notes TEXT COMMENT 'Notas adicionales',
    status_id BIGINT UNSIGNED NOT NULL COMMENT 'Estado de la cita',
    priority ENUM('baja', 'normal', 'alta', 'urgente') NOT NULL DEFAULT 'normal' COMMENT 'Prioridad de la cita',
    created_by BIGINT UNSIGNED NOT NULL COMMENT 'Usuario que creó la cita',
    modified_by BIGINT UNSIGNED NULL COMMENT 'Usuario que modificó la cita',
    confirmation_sent BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si se envió confirmación',
    reminder_sent BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si se envió recordatorio',
    arrived_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Hora de llegada del paciente',
    started_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Hora de inicio de la consulta',
    finished_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Hora de finalización',
    cancellation_reason TEXT COMMENT 'Motivo de cancelación si aplica',
    cancelled_by BIGINT UNSIGNED NULL COMMENT 'Usuario que canceló',
    cancelled_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Fecha de cancelación',
    version SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Versión para control de concurrencia',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (dentist_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (status_id) REFERENCES appointment_statuses(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (modified_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (cancelled_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_appointments_date (appointment_date),
    INDEX idx_appointments_patient (patient_id),
    INDEX idx_appointments_dentist (dentist_id),
    INDEX idx_appointments_datetime (appointment_date, appointment_time),
    INDEX idx_appointments_code (appointment_code),
    INDEX idx_appointments_status (status_id),
    INDEX idx_appointments_priority (priority),
    INDEX idx_appointments_end_time (appointment_date, end_time),
    INDEX idx_appointments_dentist_date_range (dentist_id, appointment_date, appointment_time, end_time),
    UNIQUE KEY uk_appointments_dentist_datetime (dentist_id, appointment_date, appointment_time),
    CONSTRAINT chk_appointments_duration CHECK (duration_minutes BETWEEN 15 AND 480),
    CONSTRAINT chk_appointments_date_future CHECK (appointment_date >= CURDATE()),
    CONSTRAINT chk_appointments_times CHECK (
        (arrived_at IS NULL OR arrived_at <= COALESCE(started_at, NOW())) AND
        (started_at IS NULL OR started_at <= COALESCE(finished_at, NOW()))
    ),
    CONSTRAINT chk_appointments_code_format CHECK (appointment_code REGEXP '^CITA-[0-9]{6}-[0-9]{4}$')
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Citas médicas';

-- =====================================================
-- TABLA: working_hours
-- Descripción: Horarios de trabajo de los odontólogos
-- =====================================================
CREATE TABLE working_hours (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    dentist_id BIGINT UNSIGNED NOT NULL,
    day_of_week TINYINT NOT NULL COMMENT 'Día de la semana (1=Lunes, 7=Domingo)',
    start_time TIME NOT NULL COMMENT 'Hora de inicio',
    end_time TIME NOT NULL COMMENT 'Hora de fin',
    break_start_time TIME COMMENT 'Inicio del descanso',
    break_end_time TIME COMMENT 'Fin del descanso',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    valid_from DATE NOT NULL DEFAULT (CURDATE()) COMMENT 'Válido desde fecha',
    valid_until DATE COMMENT 'Válido hasta fecha',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (dentist_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_working_hours_dentist (dentist_id),
    INDEX idx_working_hours_day (day_of_week),
    INDEX idx_working_hours_active (is_active),
    INDEX idx_working_hours_validity (valid_from, valid_until),
    INDEX idx_working_hours_dentist_day_validity (dentist_id, day_of_week, valid_from, valid_until),
    CONSTRAINT chk_working_hours_day CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT chk_working_hours_time CHECK (start_time < end_time),
    CONSTRAINT chk_working_hours_validity CHECK (valid_until IS NULL OR valid_until >= valid_from),
    CONSTRAINT chk_working_hours_break CHECK (
        (break_start_time IS NULL AND break_end_time IS NULL) OR
        (break_start_time IS NOT NULL AND break_end_time IS NOT NULL AND 
         break_start_time >= start_time AND break_end_time <= end_time AND
         break_start_time < break_end_time)
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Horarios de trabajo';

-- =====================================================
-- TABLA: holidays
-- Descripción: Días feriados y no laborables
-- =====================================================
CREATE TABLE holidays (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL COMMENT 'Nombre del feriado',
    date DATE NOT NULL COMMENT 'Fecha del feriado',
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si se repite anualmente',
    description TEXT COMMENT 'Descripción del feriado',
    is_national BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si es feriado nacional',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Si está activo',
    year SMALLINT GENERATED ALWAYS AS (YEAR(date)) STORED COMMENT 'Año del feriado',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_holidays_date (date),
    INDEX idx_holidays_active (is_active),
    INDEX idx_holidays_recurring (is_recurring),
    INDEX idx_holidays_year (year),
    INDEX idx_holidays_national (is_national),
    UNIQUE KEY uk_holidays_recurring (name, is_recurring, year) -- Evita duplicados de feriados recurrentes por año
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Días feriados';

-- =====================================================
-- TABLA: appointment_unavailabilities
-- Descripción: Períodos de no disponibilidad específicos
-- =====================================================
CREATE TABLE appointment_unavailabilities (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    dentist_id BIGINT UNSIGNED NOT NULL,
    start_date DATE NOT NULL COMMENT 'Fecha de inicio de la no disponibilidad',
    end_date DATE NOT NULL COMMENT 'Fecha de fin de la no disponibilidad',
    start_time TIME COMMENT 'Hora de inicio (null = todo el día)',
    end_time TIME COMMENT 'Hora de fin (null = todo el día)',
    reason VARCHAR(255) NOT NULL COMMENT 'Motivo de la no disponibilidad',
    type ENUM('personal', 'medical', 'vacation', 'training', 'emergency') NOT NULL DEFAULT 'personal' COMMENT 'Tipo de no disponibilidad',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by BIGINT UNSIGNED NOT NULL,
    approved_by BIGINT UNSIGNED NULL COMMENT 'Usuario que aprobó la no disponibilidad',
    approved_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (dentist_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_unavailabilities_dentist (dentist_id),
    INDEX idx_unavailabilities_dates (start_date, end_date),
    INDEX idx_unavailabilities_active (is_active),
    INDEX idx_unavailabilities_type (type),
    INDEX idx_unavailabilities_dentist_period (dentist_id, start_date, end_date),
    CONSTRAINT chk_unavailabilities_dates CHECK (start_date <= end_date),
    CONSTRAINT chk_unavailabilities_times CHECK (
        (start_time IS NULL AND end_time IS NULL) OR
        (start_time IS NOT NULL AND end_time IS NOT NULL AND start_time < end_time)
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Períodos de no disponibilidad';

-- =====================================================
-- TABLA: appointment_reminders
-- Descripción: Recordatorios de citas programados
-- =====================================================
CREATE TABLE appointment_reminders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id BIGINT UNSIGNED NOT NULL,
    reminder_type ENUM('email', 'sms', 'whatsapp', 'call') NOT NULL,
    send_at TIMESTAMP NOT NULL COMMENT 'Fecha y hora para enviar el recordatorio',
    hours_before SMALLINT UNSIGNED NOT NULL COMMENT 'Horas antes de la cita para enviar',
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NULL DEFAULT NULL,
    delivery_status ENUM('pending', 'sent', 'delivered', 'failed', 'bounced') NOT NULL DEFAULT 'pending',
    error_message TEXT COMMENT 'Mensaje de error si falla el envío',
    retry_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_appointment_reminders_appointment (appointment_id),
    INDEX idx_appointment_reminders_send_at (send_at),
    INDEX idx_appointment_reminders_pending (is_sent, send_at),
    INDEX idx_appointment_reminders_status (delivery_status),
    INDEX idx_appointment_reminders_retry (retry_count, is_sent),
    CONSTRAINT chk_appointment_reminders_retry CHECK (retry_count <= 5),
    CONSTRAINT chk_appointment_reminders_hours CHECK (hours_before BETWEEN 1 AND 168) -- Máximo una semana antes
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Recordatorios de citas';

-- =====================================================
-- TRIGGERS PARA PREVENIR SOLAPAMIENTO DE CITAS
-- =====================================================

DELIMITER $$

-- Trigger para validar solapamiento antes de insertar
CREATE TRIGGER trg_appointments_overlap_check_insert
    BEFORE INSERT ON appointments
    FOR EACH ROW
BEGIN
    DECLARE overlap_count INT DEFAULT 0;
    DECLARE holiday_count INT DEFAULT 0;
    DECLARE working_day INT DEFAULT 0;
    DECLARE day_of_week_val INT;
    
    -- Calcular día de la semana (1=Lunes, 7=Domingo)
    SET day_of_week_val = DAYOFWEEK(NEW.appointment_date);
    SET day_of_week_val = CASE 
        WHEN day_of_week_val = 1 THEN 7 -- Domingo
        ELSE day_of_week_val - 1 -- Lunes=1, ..., Sábado=6
    END;
    
    -- Verificar si es día feriado
    SELECT COUNT(*) INTO holiday_count 
    FROM holidays 
    WHERE date = NEW.appointment_date 
    AND is_active = TRUE;
    
    IF holiday_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se pueden programar citas en días feriados';
    END IF;
    
    -- Verificar si el dentista trabaja ese día
    SELECT COUNT(*) INTO working_day
    FROM working_hours wh
    WHERE wh.dentist_id = NEW.dentist_id
    AND wh.day_of_week = day_of_week_val
    AND wh.is_active = TRUE
    AND NEW.appointment_date >= wh.valid_from
    AND (wh.valid_until IS NULL OR NEW.appointment_date <= wh.valid_until)
    AND NEW.appointment_time >= wh.start_time
    AND ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) <= wh.end_time;
    
    IF working_day = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cita está fuera del horario de trabajo del dentista';
    END IF;
    
    -- Verificar solapamiento con otras citas
    SELECT COUNT(*) INTO overlap_count
    FROM appointments a
    WHERE a.dentist_id = NEW.dentist_id
    AND a.appointment_date = NEW.appointment_date
    AND a.id != COALESCE(NEW.id, 0)
    AND (
        -- La nueva cita comienza durante una cita existente
        (NEW.appointment_time >= a.appointment_time AND 
         NEW.appointment_time < ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60))) OR
        -- La nueva cita termina durante una cita existente
        (ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) > a.appointment_time AND
         ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) <= ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60))) OR
        -- La nueva cita contiene completamente una cita existente
        (NEW.appointment_time <= a.appointment_time AND
         ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) >= ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60)))
    );
    
    IF overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe una cita programada en ese horario para el dentista';
    END IF;
    
    -- Generar código de cita si no existe
    IF NEW.appointment_code IS NULL OR NEW.appointment_code = '' THEN
        SET NEW.appointment_code = CONCAT('CITA-', DATE_FORMAT(NEW.appointment_date, '%Y%m'), '-', LPAD(
            (SELECT COALESCE(MAX(CAST(SUBSTRING(appointment_code, -4) AS UNSIGNED)), 0) + 1
             FROM appointments 
             WHERE appointment_code LIKE CONCAT('CITA-', DATE_FORMAT(NEW.appointment_date, '%Y%m'), '-%')), 4, '0')
        );
    END IF;
    
    -- Calcular end_time automáticamente se hace por el campo generado
END$$

-- Trigger para validar solapamiento antes de actualizar
CREATE TRIGGER trg_appointments_overlap_check_update
    BEFORE UPDATE ON appointments
    FOR EACH ROW
BEGIN
    DECLARE overlap_count INT DEFAULT 0;
    DECLARE holiday_count INT DEFAULT 0;
    DECLARE working_day INT DEFAULT 0;
    DECLARE day_of_week_val INT;
    
    -- Solo verificar si cambian fecha, hora, duración o dentista
    IF NEW.appointment_date != OLD.appointment_date OR 
       NEW.appointment_time != OLD.appointment_time OR 
       NEW.duration_minutes != OLD.duration_minutes OR 
       NEW.dentist_id != OLD.dentist_id THEN
        
        -- Calcular día de la semana
        SET day_of_week_val = DAYOFWEEK(NEW.appointment_date);
        SET day_of_week_val = CASE 
            WHEN day_of_week_val = 1 THEN 7 
            ELSE day_of_week_val - 1 
        END;
        
        -- Verificar feriados
        SELECT COUNT(*) INTO holiday_count 
        FROM holidays 
        WHERE date = NEW.appointment_date 
        AND is_active = TRUE;
        
        IF holiday_count > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se pueden programar citas en días feriados';
        END IF;
        
        -- Verificar horario de trabajo
        SELECT COUNT(*) INTO working_day
        FROM working_hours wh
        WHERE wh.dentist_id = NEW.dentist_id
        AND wh.day_of_week = day_of_week_val
        AND wh.is_active = TRUE
        AND NEW.appointment_date >= wh.valid_from
        AND (wh.valid_until IS NULL OR NEW.appointment_date <= wh.valid_until)
        AND NEW.appointment_time >= wh.start_time
        AND ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) <= wh.end_time;
        
        IF working_day = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cita está fuera del horario de trabajo del dentista';
        END IF;
        
        -- Verificar solapamiento
        SELECT COUNT(*) INTO overlap_count
        FROM appointments a
        WHERE a.dentist_id = NEW.dentist_id
        AND a.appointment_date = NEW.appointment_date
        AND a.id != NEW.id
        AND (
            (NEW.appointment_time >= a.appointment_time AND 
             NEW.appointment_time < ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60))) OR
            (ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) > a.appointment_time AND
             ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) <= ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60))) OR
            (NEW.appointment_time <= a.appointment_time AND
             ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) >= ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60)))
        );
        
        IF overlap_count > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe una cita programada en ese horario para el dentista';
        END IF;
    END IF;
    
    -- Incrementar versión para control de concurrencia
    SET NEW.version = OLD.version + 1;
END$$

DELIMITER ;

-- =====================================================
-- TABLA DE AUDITORÍA
-- =====================================================
CREATE TABLE audit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL COMMENT 'Nombre de la tabla afectada',
    record_id BIGINT UNSIGNED NOT NULL COMMENT 'ID del registro afectado',
    operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL COMMENT 'Tipo de operación',
    old_values JSON COMMENT 'Valores anteriores (UPDATE/DELETE)',
    new_values JSON COMMENT 'Valores nuevos (INSERT/UPDATE)',
    user_id BIGINT UNSIGNED COMMENT 'Usuario que realizó la operación',
    ip_address VARCHAR(45) COMMENT 'Dirección IP del usuario',
    user_agent TEXT COMMENT 'User agent del navegador',
    session_id VARCHAR(128) COMMENT 'ID de sesión',
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_logs_table (table_name),
    INDEX idx_audit_logs_record (record_id),
    INDEX idx_audit_logs_user (user_id),
    INDEX idx_audit_logs_timestamp (timestamp),
    INDEX idx_audit_logs_operation (operation),
    INDEX idx_audit_logs_composite (table_name, record_id, timestamp)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Registro de auditoría';

-- =====================================================
-- DATOS INICIALES CRÍTICOS
-- =====================================================

-- Estados de citas básicos
INSERT INTO appointment_statuses (name, display_name, description, color, can_modify, can_cancel, display_order) VALUES
('scheduled', 'Programada', 'Cita programada y confirmada', '#3B82F6', TRUE, TRUE, 1),
('confirmed', 'Confirmada', 'Cita confirmada por el paciente', '#10B981', TRUE, TRUE, 2),
('arrived', 'Paciente llegó', 'Paciente llegó a la clínica', '#F59E0B', FALSE, TRUE, 3),
('in_progress', 'En curso', 'Consulta en progreso', '#8B5CF6', FALSE, FALSE, 4),
('completed', 'Completada', 'Consulta finalizada exitosamente', '#059669', FALSE, FALSE, 5),
('cancelled', 'Cancelada', 'Cita cancelada', '#DC2626', FALSE, FALSE, 6),
('no_show', 'No asistió', 'Paciente no se presentó', '#6B7280', FALSE, FALSE, 7),
('rescheduled', 'Reprogramada', 'Cita reprogramada', '#F97316', TRUE, TRUE, 8);

-- Feriados nacionales del Perú (ejemplo 2024-2025)
INSERT INTO holidays (name, date, is_recurring, is_national, description) VALUES
('Año Nuevo', '2024-01-01', TRUE, TRUE, 'Año Nuevo'),
('Jueves Santo', '2024-03-28', FALSE, TRUE, 'Jueves Santo 2024'),
('Viernes Santo', '2024-03-29', FALSE, TRUE, 'Viernes Santo 2024'),
('Día del Trabajo', '2024-05-01', TRUE, TRUE, 'Día Internacional del Trabajo'),
('Día de la Independencia', '2024-07-28', TRUE, TRUE, 'Proclamación de la Independencia del Perú'),
('Día de la Independencia', '2024-07-29', TRUE, TRUE, 'Día de la Gran Parada Militar'),
('Santa Rosa de Lima', '2024-08-30', TRUE, TRUE, 'Santa Rosa de Lima'),
('Combate de Angamos', '2024-10-08', TRUE, TRUE, 'Combate de Angamos'),
('Todos los Santos', '2024-11-01', TRUE, TRUE, 'Día de Todos los Santos'),
('Inmaculada Concepción', '2024-12-08', TRUE, TRUE, 'Inmaculada Concepción'),
('Navidad', '2024-12-25', TRUE, TRUE, 'Navidad'),
-- 2025
('Año Nuevo', '2025-01-01', TRUE, TRUE, 'Año Nuevo'),
('Jueves Santo', '2025-04-17', FALSE, TRUE, 'Jueves Santo 2025'),
('Viernes Santo', '2025-04-18', FALSE, TRUE, 'Viernes Santo 2025'),
('Día del Trabajo', '2025-05-01', TRUE, TRUE, 'Día Internacional del Trabajo'),
('Día de la Independencia', '2025-07-28', TRUE, TRUE, 'Proclamación de la Independencia del Perú'),
('Día de la Independencia', '2025-07-29', TRUE, TRUE, 'Día de la Gran Parada Militar');

-- =====================================================
-- VISTAS ÚTILES PARA CONSULTAS FRECUENTES
-- =====================================================

-- Vista para citas con información completa
CREATE VIEW vw_appointments_complete AS
SELECT 
    a.id,
    a.appointment_code,
    a.appointment_date,
    a.appointment_time,
    a.end_time,
    a.duration_minutes,
    a.reason,
    a.priority,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    p.dni AS patient_dni,
    p.phone AS patient_phone,
    CONCAT(d.first_name, ' ', d.last_name) AS dentist_name,
    st.display_name AS status_name,
    st.color AS status_color,
    a.arrived_at,
    a.started_at,
    a.finished_at,
    a.created_at,
    a.updated_at
FROM appointments a
JOIN users p ON a.patient_id = p.id
JOIN users d ON a.dentist_id = d.id
JOIN appointment_statuses st ON a.status_id = st.id;

-- Vista para disponibilidad de dentistas
CREATE VIEW vw_dentist_availability AS
SELECT 
    u.id AS dentist_id,
    CONCAT(u.first_name, ' ', u.last_name) AS dentist_name,
    wh.day_of_week,
    CASE wh.day_of_week
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
        WHEN 7 THEN 'Domingo'
    END AS day_name,
    wh.start_time,
    wh.end_time,
    wh.break_start_time,
    wh.break_end_time,
    wh.valid_from,
    wh.valid_until
FROM users u
JOIN working_hours wh ON u.id = wh.dentist_id
WHERE wh.is_active = TRUE
ORDER BY u.first_name, u.last_name, wh.day_of_week;