-- CONSULTAS RELACIONADAS A LA ATENCIÓN MÉDICA
-- Sistema de Gestión de Clínica Dental Larana

-- =====================================================
-- TABLA: appointments
-- =====================================================
CREATE TABLE appointments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_code VARCHAR(15) NOT NULL UNIQUE COMMENT 'CITA-YYYYMM-XXXX',
    patient_id BIGINT UNSIGNED NOT NULL,
    dentist_id BIGINT UNSIGNED NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    duration_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 30,
    reason TEXT,
    notes TEXT,
    status_id BIGINT UNSIGNED NOT NULL,
    created_by BIGINT UNSIGNED NOT NULL,
    modified_by BIGINT UNSIGNED NULL,
    confirmation_sent BOOLEAN NOT NULL DEFAULT FALSE,
    reminder_sent BOOLEAN NOT NULL DEFAULT FALSE,
    arrived_at TIMESTAMP NULL DEFAULT NULL,
    started_at TIMESTAMP NULL DEFAULT NULL,
    finished_at TIMESTAMP NULL DEFAULT NULL,
    cancellation_reason TEXT,
    cancelled_by BIGINT UNSIGNED NULL,
    cancelled_at TIMESTAMP NULL DEFAULT NULL,
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
    INDEX idx_appointments_patient_date (patient_id, appointment_date),
    INDEX idx_appointments_dentist_date (dentist_id, appointment_date),
    UNIQUE KEY uk_appointments_dentist_datetime (dentist_id, appointment_date, appointment_time),
    CONSTRAINT chk_appointments_duration CHECK (duration_minutes BETWEEN 15 AND 480),
    CONSTRAINT chk_appointments_future_date CHECK (
        appointment_date >= CURDATE() OR 
        (appointment_date = CURDATE() AND appointment_time >= CURTIME())
    ),
    CONSTRAINT chk_appointments_times CHECK (
        (arrived_at IS NULL OR arrived_at <= COALESCE(started_at, NOW())) AND
        (started_at IS NULL OR started_at <= COALESCE(finished_at, NOW()))
    ),
    CONSTRAINT chk_appointments_working_hours CHECK (
        appointment_time BETWEEN '07:00:00' AND '20:00:00'
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TABLA: medical_records
-- =====================================================
CREATE TABLE medical_records (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    record_number VARCHAR(15) NOT NULL UNIQUE COMMENT 'HC-YYYYMM-XXXX',
    patient_id BIGINT UNSIGNED NOT NULL,
    dentist_id BIGINT UNSIGNED NOT NULL,
    appointment_id BIGINT UNSIGNED NULL,
    visit_date DATE NOT NULL,
    chief_complaint TEXT,
    clinical_examination TEXT,
    diagnosis TEXT,
    treatment_plan TEXT,
    treatment_performed TEXT,
    observations TEXT,
    next_visit_date DATE,
    is_validated BOOLEAN NOT NULL DEFAULT FALSE,
    validated_at TIMESTAMP NULL DEFAULT NULL,
    version TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Control de versiones',
    previous_version_id BIGINT UNSIGNED NULL COMMENT 'Referencia a versión anterior',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (dentist_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (previous_version_id) REFERENCES medical_records(id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_medical_records_patient (patient_id),
    INDEX idx_medical_records_dentist (dentist_id),
    INDEX idx_medical_records_date (visit_date),
    INDEX idx_medical_records_number (record_number),
    INDEX idx_medical_records_validated (is_validated),
    INDEX idx_medical_records_patient_date (patient_id, visit_date),
    CONSTRAINT chk_medical_records_visit_date CHECK (visit_date <= CURDATE()),
    CONSTRAINT chk_medical_records_next_visit CHECK (next_visit_date IS NULL OR next_visit_date > visit_date)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TABLA: treatment_types
-- =====================================================
CREATE TABLE treatment_types (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    estimated_duration SMALLINT UNSIGNED NOT NULL DEFAULT 30,
    base_price DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Precio base en soles',
    requires_lab BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_treatment_types_active (is_active),
    INDEX idx_treatment_types_category (category),
    INDEX idx_treatment_types_code (code),
    CONSTRAINT chk_treatment_types_duration CHECK (estimated_duration BETWEEN 5 AND 480),
    CONSTRAINT chk_treatment_types_price CHECK (base_price >= 0)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TABLA: treatment_records
-- =====================================================
CREATE TABLE treatment_records (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medical_record_id BIGINT UNSIGNED NOT NULL,
    treatment_type_id BIGINT UNSIGNED NOT NULL,
    tooth_number VARCHAR(5) COMMENT 'Formato: 11, 12, etc.',
    treatment_details TEXT,
    materials_used TEXT,
    final_price DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Precio final aplicado',
    status ENUM('planned', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'planned',
    performed_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (medical_record_id) REFERENCES medical_records(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (treatment_type_id) REFERENCES treatment_types(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_treatment_records_medical (medical_record_id),
    INDEX idx_treatment_records_type (treatment_type_id),
    INDEX idx_treatment_records_status (status),
    INDEX idx_treatment_records_tooth (tooth_number),
    CONSTRAINT chk_treatment_records_price CHECK (final_price >= 0),
    CONSTRAINT chk_treatment_records_tooth_number CHECK (
        tooth_number IS NULL OR 
        tooth_number REGEXP '^[1-8][1-8]$'
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TABLA: medical_record_files
-- =====================================================
CREATE TABLE medical_record_files (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medical_record_id BIGINT UNSIGNED NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    file_size INT UNSIGNED NOT NULL,
    file_category ENUM('xray', 'photo', 'document', 'scan', 'other') NOT NULL DEFAULT 'other',
    description TEXT,
    uploaded_by BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (medical_record_id) REFERENCES medical_records(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_medical_files_record (medical_record_id),
    INDEX idx_medical_files_category (file_category),
    CONSTRAINT chk_medical_files_size CHECK (file_size > 0),
    CONSTRAINT chk_medical_files_type CHECK (
        file_type IN ('image/jpeg', 'image/png', 'application/pdf', 'image/dicom', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    )
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TABLA: prescriptions
-- =====================================================
CREATE TABLE prescriptions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    prescription_number VARCHAR(15) NOT NULL UNIQUE COMMENT 'RX-YYYYMM-XXXX',
    patient_id BIGINT UNSIGNED NOT NULL,
    dentist_id BIGINT UNSIGNED NOT NULL,
    medical_record_id BIGINT UNSIGNED NULL,
    prescription_date DATE NOT NULL,
    medications JSON NOT NULL,
    instructions TEXT,
    pharmacy_name VARCHAR(100),
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NULL DEFAULT NULL,
    dispensed_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (dentist_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (medical_record_id) REFERENCES medical_records(id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_prescriptions_patient (patient_id),
    INDEX idx_prescriptions_dentist (dentist_id),
    INDEX idx_prescriptions_date (prescription_date),
    INDEX idx_prescriptions_number (prescription_number),
    CONSTRAINT chk_prescriptions_date CHECK (prescription_date <= CURDATE()),
    CONSTRAINT chk_prescriptions_medications CHECK (JSON_VALID(medications))
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TABLA: laboratory_orders
-- =====================================================
CREATE TABLE laboratory_orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_number VARCHAR(15) NOT NULL UNIQUE COMMENT 'LAB-YYYYMM-XXXX',
    patient_id BIGINT UNSIGNED NOT NULL,
    dentist_id BIGINT UNSIGNED NOT NULL,
    medical_record_id BIGINT UNSIGNED NULL,
    order_date DATE NOT NULL,
    tests_requested JSON NOT NULL,
    instructions TEXT,
    laboratory_name VARCHAR(100),
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NULL DEFAULT NULL,
    results_received BOOLEAN NOT NULL DEFAULT FALSE,
    results_received_at TIMESTAMP NULL DEFAULT NULL,
    results_file_path VARCHAR(500),
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (dentist_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (medical_record_id) REFERENCES medical_records(id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_lab_orders_patient (patient_id),
    INDEX idx_lab_orders_dentist (dentist_id),
    INDEX idx_lab_orders_date (order_date),
    INDEX idx_lab_orders_number (order_number),
    INDEX idx_lab_orders_status (results_received),
    CONSTRAINT chk_lab_orders_date CHECK (order_date <= CURDATE()),
    CONSTRAINT chk_lab_orders_tests CHECK (JSON_VALID(tests_requested))
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TABLA: services
-- =====================================================
CREATE TABLE services (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00 COMMENT 'Precio en soles',
    duration_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 30,
    requires_lab BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_services_active (is_active),
    INDEX idx_services_code (code),
    INDEX idx_services_category (category),
    CONSTRAINT chk_services_price CHECK (price >= 0),
    CONSTRAINT chk_services_duration CHECK (duration_minutes BETWEEN 5 AND 480)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TABLAS DE APOYO PARA ATENCIÓN MÉDICA
-- =====================================================

-- Estados de citas
CREATE TABLE appointment_statuses (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    color CHAR(7) NOT NULL DEFAULT '#6B7280',
    can_modify BOOLEAN NOT NULL DEFAULT TRUE,
    can_cancel BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_appointment_statuses_active (is_active),
    INDEX idx_appointment_statuses_order (display_order),
    CONSTRAINT chk_appointment_statuses_color CHECK (color REGEXP '^#[0-9A-Fa-f]{6}$')
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Recordatorios de citas
CREATE TABLE appointment_reminders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id BIGINT UNSIGNED NOT NULL,
    reminder_type ENUM('email', 'sms', 'whatsapp') NOT NULL,
    send_at TIMESTAMP NOT NULL,
    is_sent BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMP NULL DEFAULT NULL,
    error_message TEXT,
    retry_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_appointment_reminders_appointment (appointment_id),
    INDEX idx_appointment_reminders_send_at (send_at),
    INDEX idx_appointment_reminders_pending (is_sent, send_at),
    CONSTRAINT chk_appointment_reminders_retry CHECK (retry_count <= 5)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- =====================================================
-- TRIGGERS PARA VALIDACIONES CRÍTICAS
-- =====================================================

-- Trigger para prevenir solapamiento de citas
DELIMITER $$
CREATE TRIGGER trg_appointments_overlap_check
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
    DECLARE overlap_count INT DEFAULT 0;
    
    SELECT COUNT(*) INTO overlap_count
    FROM appointments a
    INNER JOIN appointment_statuses s ON a.status_id = s.id
    WHERE a.dentist_id = NEW.dentist_id
    AND a.appointment_date = NEW.appointment_date
    AND s.name NOT IN ('cancelled', 'no_show')
    AND (
        -- Nueva cita inicia durante una existente
        (NEW.appointment_time >= a.appointment_time 
         AND NEW.appointment_time < ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60)))
        OR
        -- Nueva cita termina durante una existente
        (ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) > a.appointment_time 
         AND ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) <= ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60)))
        OR
        -- Nueva cita engloba una existente
        (NEW.appointment_time <= a.appointment_time 
         AND ADDTIME(NEW.appointment_time, SEC_TO_TIME(NEW.duration_minutes * 60)) >= ADDTIME(a.appointment_time, SEC_TO_TIME(a.duration_minutes * 60)))
    );
    
    IF overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dentista ya tiene una cita programada en ese horario';
    END IF;
END$$

-- Trigger para actualizar códigos automáticamente
CREATE TRIGGER trg_appointments_code_generation
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
    DECLARE next_num INT;
    DECLARE year_month VARCHAR(6);
    
    SET year_month = DATE_FORMAT(CURDATE(), '%Y%m');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(appointment_code, 12, 4) AS UNSIGNED)), 0) + 1
    INTO next_num
    FROM appointments
    WHERE appointment_code LIKE CONCAT('CITA-', year_month, '-%');
    
    SET NEW.appointment_code = CONCAT('CITA-', year_month, '-', LPAD(next_num, 4, '0'));
END$$

-- Trigger para medical records
CREATE TRIGGER trg_medical_records_code_generation
BEFORE INSERT ON medical_records
FOR EACH ROW
BEGIN
    DECLARE next_num INT;
    DECLARE year_month VARCHAR(6);
    
    SET year_month = DATE_FORMAT(CURDATE(), '%Y%m');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(record_number, 10, 4) AS UNSIGNED)), 0) + 1
    INTO next_num
    FROM medical_records
    WHERE record_number LIKE CONCAT('HC-', year_month, '-%');
    
    SET NEW.record_number = CONCAT('HC-', year_month, '-', LPAD(next_num, 4, '0'));
END$$

-- Trigger para prescriptions
CREATE TRIGGER trg_prescriptions_code_generation
BEFORE INSERT ON prescriptions
FOR EACH ROW
BEGIN
    DECLARE next_num INT;
    DECLARE year_month VARCHAR(6);
    
    SET year_month = DATE_FORMAT(CURDATE(), '%Y%m');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(prescription_number, 10, 4) AS UNSIGNED)), 0) + 1
    INTO next_num
    FROM prescriptions
    WHERE prescription_number LIKE CONCAT('RX-', year_month, '-%');
    
    SET NEW.prescription_number = CONCAT('RX-', year_month, '-', LPAD(next_num, 4, '0'));
END$$

-- Trigger para laboratory orders
CREATE TRIGGER trg_lab_orders_code_generation
BEFORE INSERT ON laboratory_orders
FOR EACH ROW
BEGIN
    DECLARE next_num INT;
    DECLARE year_month VARCHAR(6);
    
    SET year_month = DATE_FORMAT(CURDATE(), '%Y%m');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(order_number, 11, 4) AS UNSIGNED)), 0) + 1
    INTO next_num
    FROM laboratory_orders
    WHERE order_number LIKE CONCAT('LAB-', year_month, '-%');
    
    SET NEW.order_number = CONCAT('LAB-', year_month, '-', LPAD(next_num, 4, '0'));
END$$

DELIMITER ;

-- =====================================================
-- DATOS INICIALES PARA ESTADOS DE CITAS
-- =====================================================
INSERT INTO appointment_statuses (name, display_name, description, color, can_modify, can_cancel, display_order) VALUES
('scheduled', 'Programada', 'Cita programada y confirmada', '#3B82F6', TRUE, TRUE, 1),
('confirmed', 'Confirmada', 'Cita confirmada por el paciente', '#10B981', TRUE, TRUE, 2),
('arrived', 'Paciente llegó', 'Paciente registrado en recepción', '#F59E0B', FALSE, TRUE, 3),
('in_progress', 'En consulta', 'Consulta en progreso', '#8B5CF6', FALSE, FALSE, 4),
('completed', 'Completada', 'Consulta finalizada exitosamente', '#059669', FALSE, FALSE, 5),
('cancelled', 'Cancelada', 'Cita cancelada', '#EF4444', FALSE, FALSE, 6),
('no_show', 'No asistió', 'Paciente no se presentó', '#6B7280', FALSE, FALSE, 7),
('rescheduled', 'Reprogramada', 'Cita reprogramada', '#F97316', TRUE, TRUE, 8);

-- =====================================================
-- DATOS INICIALES PARA TIPOS DE TRATAMIENTO
-- =====================================================
INSERT INTO treatment_types (code, name, category, estimated_duration, base_price, requires_lab) VALUES
('CONS-001', 'Consulta General', 'Consulta', 30, 50.00, FALSE),
('LIMI-001', 'Limpieza Dental', 'Prevención', 45, 80.00, FALSE),
('OBTU-001', 'Obturación Simple', 'Restauración', 60, 120.00, FALSE),
('OBTU-002', 'Obturación Compuesta', 'Restauración', 90, 180.00, FALSE),
('EXTR-001', 'Extracción Simple', 'Cirugía', 30, 100.00, FALSE),
('EXTR-002', 'Extracción Compleja', 'Cirugía', 60, 200.00, FALSE),
('ENDO-001', 'Endodoncia', 'Endodoncia', 120, 350.00, FALSE),
('CORO-001', 'Corona Dental', 'Prótesis', 90, 500.00, TRUE),
('PONT-001', 'Puente Dental', 'Prótesis', 120, 800.00, TRUE),
('IMPL-001', 'Implante Dental', 'Implantología', 180, 1200.00, TRUE),
('BLAN-001', 'Blanqueamiento', 'Estética', 60, 300.00, FALSE),
('ORTO-001', 'Brackets Metálicos', 'Ortodoncia', 60, 1500.00, FALSE),
('ORTO-002', 'Brackets Estéticos', 'Ortodoncia', 60, 2000.00, FALSE),
('PERI-001', 'Tratamiento Periodontal', 'Periodoncia', 90, 250.00, FALSE),
('RADI-001', 'Radiografía Periapical', 'Diagnóstico', 15, 25.00, FALSE),
('RADI-002', 'Radiografía Panorámica', 'Diagnóstico', 20, 60.00, FALSE);