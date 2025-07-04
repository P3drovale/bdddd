-- =====================================================
-- SISTEMA DE GESTIÓN DE USUARIOS Y ROLES MEJORADO
-- Clínica Dental Larana - Módulo de Autenticación
-- =====================================================

-- =====================================================
-- TABLA: roles
-- Descripción: Gestiona los roles del sistema
-- =====================================================
CREATE TABLE roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE COMMENT 'Nombre del rol (admin, receptionist, dentist, assistant, patient)',
    display_name VARCHAR(100) NOT NULL COMMENT 'Nombre para mostrar',
    description TEXT COMMENT 'Descripción detallada del rol',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Estado del rol',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_roles_active (is_active)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Roles del sistema';

-- =====================================================
-- TABLA: permissions
-- Descripción: Define permisos específicos del sistema
-- =====================================================
CREATE TABLE permissions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre del permiso en formato module.action',
    display_name VARCHAR(150) NOT NULL COMMENT 'Nombre para mostrar',
    description TEXT COMMENT 'Descripción del permiso',
    module VARCHAR(50) NOT NULL COMMENT 'Módulo al que pertenece',
    action VARCHAR(50) NOT NULL COMMENT 'Acción específica (create, read, update, delete)',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_permissions_module (module),
    INDEX idx_permissions_action (action),
    UNIQUE KEY uk_permissions_module_action (module, action)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Permisos del sistema';

-- =====================================================
-- TABLA: role_permissions
-- Descripción: Tabla pivot para relación roles-permisos
-- =====================================================
CREATE TABLE role_permissions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_id BIGINT UNSIGNED NOT NULL,
    permission_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE KEY uk_role_permissions (role_id, permission_id)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Relación roles-permisos';

-- =====================================================
-- TABLA: payment_methods
-- Descripción: Métodos de pago disponibles
-- =====================================================
CREATE TABLE payment_methods (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE COMMENT 'Nombre del método de pago',
    display_name VARCHAR(100) NOT NULL COMMENT 'Nombre para mostrar',
    description TEXT COMMENT 'Descripción del método',
    is_electronic BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si es método electrónico',
    requires_reference BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Si requiere número de referencia',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Estado del método',
    display_order TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Orden de visualización',
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_payment_methods_active (is_active),
    INDEX idx_payment_methods_order (display_order)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Métodos de pago';

-- =====================================================
-- TABLA: users
-- Descripción: Usuarios del sistema con seguridad mejorada
-- =====================================================
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    -- Identificación flexible para peruanos y extranjeros
    document_type ENUM('DNI', 'CE', 'PASSPORT') NOT NULL DEFAULT 'DNI' COMMENT 'Tipo de documento',
    document_number VARCHAR(20) NOT NULL COMMENT 'Número de documento (DNI: 8 dígitos, CE: 9, Pasaporte: variable)',
    email VARCHAR(191) NOT NULL UNIQUE COMMENT 'Correo electrónico único',
    email_verified_at TIMESTAMP NULL DEFAULT NULL,
    password VARCHAR(255) NOT NULL COMMENT 'Contraseña hasheada (bcrypt)',
    -- Campos de seguridad mejorados
    password_changed_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Última vez que cambió la contraseña',
    jwt_version SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Versión JWT para invalidar tokens',
    session_id VARCHAR(100) NULL COMMENT 'ID de sesión activa actual',
    -- Información personal
    first_name VARCHAR(100) NOT NULL COMMENT 'Nombres',
    last_name VARCHAR(100) NOT NULL COMMENT 'Apellidos',
    phone VARCHAR(20) COMMENT 'Número de teléfono/celular',
    address TEXT COMMENT 'Dirección completa',
    birth_date DATE COMMENT 'Fecha de nacimiento',
    gender ENUM('M', 'F', 'O') COMMENT 'Género: M=Masculino, F=Femenino, O=Otro',
    -- Control de acceso
    role_id BIGINT UNSIGNED NOT NULL COMMENT 'Rol asignado al usuario',
    is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Estado del usuario',
    last_login TIMESTAMP NULL DEFAULT NULL COMMENT 'Último inicio de sesión',
    -- Seguridad anti fuerza bruta mejorada
    failed_login_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Intentos fallidos de login',
    last_failed_login TIMESTAMP NULL DEFAULT NULL COMMENT 'Último intento fallido',
    locked_until TIMESTAMP NULL DEFAULT NULL COMMENT 'Bloqueado hasta esta fecha',
    lockout_count TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Cantidad de bloqueos',
    -- Reset de contraseña
    password_reset_token VARCHAR(100) NULL COMMENT 'Token para reset de contraseña',
    password_reset_expires TIMESTAMP NULL DEFAULT NULL COMMENT 'Expiración del token',
    remember_token VARCHAR(100) NULL DEFAULT NULL,
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    -- Índices optimizados
    INDEX idx_users_document (document_type, document_number),
    INDEX idx_users_email (email),
    INDEX idx_users_role (role_id),
    INDEX idx_users_active (is_active),
    INDEX idx_users_names (first_name, last_name),
    INDEX idx_users_session (session_id),
    INDEX idx_users_jwt_version (jwt_version),
    -- Constraints mejorados
    UNIQUE KEY uk_users_document (document_type, document_number),
    CONSTRAINT chk_users_document_dni CHECK (
        (document_type = 'DNI' AND document_number REGEXP '^[0-9]{8}$') OR
        (document_type = 'CE' AND document_number REGEXP '^[0-9]{9}$') OR
        (document_type = 'PASSPORT' AND LENGTH(document_number) BETWEEN 6 AND 20)
    ),
    CONSTRAINT chk_users_failed_attempts CHECK (failed_login_attempts <= 10),
    CONSTRAINT chk_users_lockout_count CHECK (lockout_count <= 50),
    CONSTRAINT chk_users_birth_date CHECK (birth_date <= CURDATE()),
    CONSTRAINT chk_users_jwt_version CHECK (jwt_version > 0)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Usuarios del sistema';

-- =====================================================
-- TABLA: user_profiles
-- Descripción: Perfiles específicos según rol de usuario
-- =====================================================
CREATE TABLE user_profiles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    -- Campos específicos para pacientes
    emergency_contact_name VARCHAR(100) COMMENT 'Nombre contacto de emergencia',
    emergency_contact_phone VARCHAR(20) COMMENT 'Teléfono contacto de emergencia',
    allergies TEXT COMMENT 'Alergias conocidas',
    medical_conditions TEXT COMMENT 'Condiciones médicas relevantes',
    insurance_provider VARCHAR(100) COMMENT 'Proveedor de seguro',
    insurance_number VARCHAR(50) COMMENT 'Número de póliza',
    -- Campos específicos para odontólogos
    license_number VARCHAR(50) COMMENT 'Número de colegiatura',
    specializations TEXT COMMENT 'Especializaciones (JSON array)',
    education TEXT COMMENT 'Educación y certificaciones',
    years_experience TINYINT UNSIGNED COMMENT 'Años de experiencia',
    -- Campos específicos para personal
    employee_code VARCHAR(20) COMMENT 'Código de empleado',
    hire_date DATE COMMENT 'Fecha de contratación',
    department VARCHAR(50) COMMENT 'Departamento',
    salary DECIMAL(8,2) UNSIGNED COMMENT 'Salario (confidencial)',
    -- Metadatos
    created_at TIMESTAMP NULL DEFAULT NULL,
    updated_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_user_profiles_user (user_id),
    INDEX idx_user_profiles_license (license_number),
    INDEX idx_user_profiles_employee (employee_code),
    UNIQUE KEY uk_user_profiles_user (user_id),
    CONSTRAINT chk_user_profiles_experience CHECK (years_experience <= 70),
    CONSTRAINT chk_user_profiles_salary CHECK (salary IS NULL OR salary >= 0)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Perfiles extendidos de usuarios';

-- =====================================================
-- TABLA: audit_logs
-- Descripción: Registro de auditoría mejorado
-- =====================================================
CREATE TABLE audit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NULL COMMENT 'Usuario que realizó la acción',
    table_name VARCHAR(64) NOT NULL COMMENT 'Tabla afectada',
    record_id BIGINT UNSIGNED NULL COMMENT 'ID del registro afectado',
    action ENUM('CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'ACCESS_DENIED') NOT NULL,
    old_values JSON COMMENT 'Valores anteriores (UPDATE/DELETE)',
    new_values JSON COMMENT 'Valores nuevos (CREATE/UPDATE)',
    ip_address VARCHAR(45) COMMENT 'Dirección IP del usuario',
    user_agent TEXT COMMENT 'User agent del navegador',
    additional_data JSON COMMENT 'Datos adicionales específicos',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Momento de la acción',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_audit_logs_user (user_id),
    INDEX idx_audit_logs_table (table_name),
    INDEX idx_audit_logs_record (table_name, record_id),
    INDEX idx_audit_logs_action (action),
    INDEX idx_audit_logs_created (created_at),
    INDEX idx_audit_logs_ip (ip_address)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT='Registro de auditoría del sistema';

-- =====================================================
-- TRIGGERS DE SEGURIDAD
-- =====================================================

-- Trigger para auditar cambios en usuarios
DELIMITER $$
CREATE TRIGGER tr_users_audit_insert 
AFTER INSERT ON users FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, table_name, record_id, action, new_values, created_at)
    VALUES (NEW.id, 'users', NEW.id, 'CREATE', 
            JSON_OBJECT(
                'document_type', NEW.document_type,
                'document_number', NEW.document_number,
                'email', NEW.email,
                'first_name', NEW.first_name,
                'last_name', NEW.last_name,
                'role_id', NEW.role_id
            ), 
            NOW());
END$$

CREATE TRIGGER tr_users_audit_update 
AFTER UPDATE ON users FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, table_name, record_id, action, old_values, new_values, created_at)
    VALUES (NEW.id, 'users', NEW.id, 'UPDATE',
            JSON_OBJECT(
                'document_type', OLD.document_type,
                'document_number', OLD.document_number,
                'email', OLD.email,
                'first_name', OLD.first_name,
                'last_name', OLD.last_name,
                'role_id', OLD.role_id,
                'is_active', OLD.is_active
            ),
            JSON_OBJECT(
                'document_type', NEW.document_type,
                'document_number', NEW.document_number,
                'email', NEW.email,
                'first_name', NEW.first_name,
                'last_name', NEW.last_name,
                'role_id', NEW.role_id,
                'is_active', NEW.is_active
            ),
            NOW());
END$$

-- Trigger para resetear intentos fallidos después de login exitoso
CREATE TRIGGER tr_users_reset_failed_attempts
BEFORE UPDATE ON users FOR EACH ROW
BEGIN
    IF NEW.last_login != OLD.last_login AND NEW.last_login IS NOT NULL THEN
        SET NEW.failed_login_attempts = 0;
        SET NEW.last_failed_login = NULL;
        SET NEW.locked_until = NULL;
    END IF;
END$$

-- Trigger para incrementar versión JWT cuando se cambia contraseña
CREATE TRIGGER tr_users_increment_jwt_version
BEFORE UPDATE ON users FOR EACH ROW
BEGIN
    IF NEW.password != OLD.password THEN
        SET NEW.jwt_version = OLD.jwt_version + 1;
        SET NEW.password_changed_at = NOW();
        SET NEW.session_id = NULL; -- Invalidar sesión actual
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- DATOS INICIALES - MÉTODOS DE PAGO
-- =====================================================
INSERT INTO payment_methods (name, display_name, description, is_electronic, requires_reference, display_order) VALUES
('efectivo', 'Efectivo', 'Pago en efectivo', FALSE, FALSE, 1),
('tarjeta_debito', 'Tarjeta de Débito', 'Pago con tarjeta de débito', TRUE, TRUE, 2),
('tarjeta_credito', 'Tarjeta de Crédito', 'Pago con tarjeta de crédito', TRUE, TRUE, 3),
('transferencia', 'Transferencia Bancaria', 'Transferencia electrónica', TRUE, TRUE, 4),
('yape', 'Yape', 'Pago mediante Yape', TRUE, TRUE, 5),
('plin', 'Plin', 'Pago mediante Plin', TRUE, TRUE, 6),
('deposito', 'Depósito Bancario', 'Depósito en cuenta bancaria', FALSE, TRUE, 7),
('cheque', 'Cheque', 'Pago con cheque', FALSE, TRUE, 8);

-- =====================================================
-- DATOS INICIALES - ROLES
-- =====================================================
INSERT INTO roles (name, display_name, description) VALUES
('admin', 'Administrador', 'Acceso completo al sistema'),
('dentist', 'Odontólogo', 'Profesional odontólogo con acceso a gestión médica'),
('receptionist', 'Recepcionista', 'Gestión de citas y atención al cliente'),
('assistant', 'Asistente Dental', 'Apoyo en procedimientos y gestión básica'),
('patient', 'Paciente', 'Acceso limitado para consulta de información personal');

-- =====================================================
-- DATOS INICIALES - PERMISOS MODULARES
-- =====================================================
INSERT INTO permissions (name, display_name, description, module, action) VALUES
-- Módulo Usuarios
('users.create', 'Crear Usuarios', 'Crear nuevos usuarios en el sistema', 'users', 'create'),
('users.read', 'Ver Usuarios', 'Ver información de usuarios', 'users', 'read'),
('users.update', 'Editar Usuarios', 'Modificar información de usuarios', 'users', 'update'),
('users.delete', 'Eliminar Usuarios', 'Eliminar usuarios del sistema', 'users', 'delete'),
-- Módulo Citas
('appointments.create', 'Crear Citas', 'Programar nuevas citas', 'appointments', 'create'),
('appointments.read', 'Ver Citas', 'Consultar citas programadas', 'appointments', 'read'),
('appointments.update', 'Editar Citas', 'Modificar citas existentes', 'appointments', 'update'),
('appointments.delete', 'Cancelar Citas', 'Cancelar citas programadas', 'appointments', 'delete'),
-- Módulo Facturación
('billing.create', 'Crear Facturas', 'Generar facturas y boletas', 'billing', 'create'),
('billing.read', 'Ver Facturas', 'Consultar documentos de facturación', 'billing', 'read'),
('billing.update', 'Editar Facturas', 'Modificar documentos antes del envío', 'billing', 'update'),
('billing.delete', 'Anular Facturas', 'Anular documentos de facturación', 'billing', 'delete'),
-- Módulo Inventario
('inventory.create', 'Crear Inventario', 'Registrar nuevos artículos', 'inventory', 'create'),
('inventory.read', 'Ver Inventario', 'Consultar stock y artículos', 'inventory', 'read'),
('inventory.update', 'Editar Inventario', 'Modificar información de artículos', 'inventory', 'update'),
('inventory.delete', 'Eliminar Inventario', 'Eliminar artículos del inventario', 'inventory', 'delete'),
-- Módulo Reportes
('reports.read', 'Ver Reportes', 'Acceso a reportes del sistema', 'reports', 'read'),
('reports.export', 'Exportar Reportes', 'Exportar reportes en diferentes formatos', 'reports', 'export'),
-- Módulo Administración
('admin.settings', 'Configuración', 'Acceso a configuración del sistema', 'admin', 'settings'),
('admin.audit', 'Auditoría', 'Acceso a logs de auditoría', 'admin', 'audit');