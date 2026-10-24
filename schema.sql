-- =====================================================================
-- SpaceBook · db_spacebook · MySQL 8.0.16 o superior (CHECK activos)

DROP DATABASE IF EXISTS db_spacebook;
CREATE DATABASE db_spacebook CHARACTER SET utf8mb4;
USE db_spacebook;

SET GLOBAL event_scheduler = ON;











/*
  ________     ___      ____    __          ___      ____
 |__    __|   /   \    | __ )  |  |        /   \    / ___|
    |  |     /  _  \   |  _ \  |  |       /  _  \   \___  \
    |  |    /  ___  \  | |_) | |  |___   /  ___  \   ___)  |
    |__|   /__/   \__\ |____/  |______| /__/   \__\ |____ /
*/

CREATE TABLE usuario (
    id_usuario INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(20) NOT NULL,
    correo VARCHAR(50) NOT NULL UNIQUE,
    hash_pwd VARCHAR(255) NOT NULL,
    rol ENUM('ADMIN','CLIENTE') NOT NULL DEFAULT 'CLIENTE',
    estado ENUM('ACTIVO','INACTIVO','BLOQUEADO','NO_CONFIRMADO') NOT NULL DEFAULT 'NO_CONFIRMADO',
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado_hasta DATETIME NULL,                  -- bloqueo temporal por login fallido
    codigo_confirmacion INT UNSIGNED NULL,
    codigo_expira DATETIME NULL,
    intentos_confirmacion TINYINT UNSIGNED NOT NULL DEFAULT 0,
    INDEX idx_usuario_estado_registro (estado, fecha_registro)
);

CREATE TABLE sala (
    id_sala INT PRIMARY KEY AUTO_INCREMENT,
    tipo_sala VARCHAR(50) NOT NULL,
    estado ENUM('ACTIVA','INACTIVA') NOT NULL DEFAULT 'ACTIVA',
    nombre VARCHAR(50) NOT NULL,
    precio_hora DECIMAL(10,2) NOT NULL,
    hora_apertura TIME NOT NULL,
    hora_cierre TIME NOT NULL,
    descripcion TEXT,
    equipamiento JSON NOT NULL,
    capacidad_minima INT UNSIGNED NOT NULL,
    capacidad_maxima INT UNSIGNED NOT NULL,
    CONSTRAINT chk_sala_precio CHECK (precio_hora > 0),
    CONSTRAINT chk_sala_horario CHECK (hora_apertura < hora_cierre),
    CONSTRAINT chk_sala_capacidad CHECK (capacidad_minima > 0 AND capacidad_minima <= capacidad_maxima)
);

CREATE TABLE reserva (
    id_reserva INT PRIMARY KEY AUTO_INCREMENT,
    inicio DATETIME NOT NULL,
    fin DATETIME NOT NULL,
    estado ENUM('PENDIENTE','PAGADO','CANCELADO','EXPIRADO','COMPLETADO') NOT NULL DEFAULT 'PENDIENTE',
    total DECIMAL(10,2) NOT NULL,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    codigo INT UNSIGNED NOT NULL UNIQUE,            -- código para QR / código de barras
    fecha_expiracion DATETIME NOT NULL,
    fecha_cancelacion DATETIME NULL,
    motivo_cancelacion TEXT,
    id_cliente INT NOT NULL,
    id_sala INT NOT NULL,
    CONSTRAINT fk_reserva_cliente FOREIGN KEY (id_cliente) REFERENCES usuario(id_usuario),
    CONSTRAINT fk_reserva_sala FOREIGN KEY (id_sala) REFERENCES sala(id_sala),
    CONSTRAINT chk_reserva_fechas CHECK (fin > inicio),
    CONSTRAINT chk_reserva_total CHECK (total >= 0),
    INDEX idx_reserva_sala_rango (id_sala, estado, inicio, fin),
    INDEX idx_reserva_estado_exp (estado, fecha_expiracion),
    INDEX idx_reserva_cliente (id_cliente, estado, fin)
);

CREATE TABLE pago (
    id_pago INT PRIMARY KEY AUTO_INCREMENT,
    monto DECIMAL(10,2) NOT NULL,
    metodo_pago ENUM('EFECTIVO','DIGITAL') NOT NULL,
    estado ENUM('PENDIENTE','PAGADO','CANCELADO','REEMBOLSADO') NOT NULL DEFAULT 'PENDIENTE',
    referencia VARCHAR(17),
    fecha_pago DATETIME,
    monto_reembolsado DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    fecha_reembolso DATETIME NULL,
    id_reserva INT NOT NULL UNIQUE,
    CONSTRAINT fk_pago_reserva FOREIGN KEY (id_reserva) REFERENCES reserva(id_reserva),
    CONSTRAINT chk_pago_monto CHECK (monto >= 0),
    CONSTRAINT chk_pago_reembolso CHECK (monto_reembolsado >= 0 AND monto_reembolsado <= monto)
);

CREATE TABLE resenia (
    id_resenia INT PRIMARY KEY AUTO_INCREMENT,
    calificacion TINYINT NOT NULL,
    comentario TEXT,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_reserva INT NOT NULL UNIQUE,
    CONSTRAINT fk_resenia_reserva FOREIGN KEY (id_reserva) REFERENCES reserva(id_reserva),
    CONSTRAINT chk_resenia_calificacion CHECK (calificacion BETWEEN 1 AND 5)
);

CREATE TABLE auditoria (
    id_auditoria INT PRIMARY KEY AUTO_INCREMENT,
    fecha_auditoria DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tabla VARCHAR(20) NOT NULL,
    actualizacion JSON,                              -- {"viejo": {...}, "nuevo": {...}}
    id_campo_actualizado INT NOT NULL,               -- id del registro afectado
    tipo_movimiento ENUM('INSERCION','ACTUALIZACION','ELIMINACION') NOT NULL,
    id_usuario INT NOT NULL,
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario),
    INDEX idx_auditoria_registro (tabla, id_campo_actualizado),
    INDEX idx_auditoria_fecha (fecha_auditoria)
);

CREATE TABLE bloqueo (
    id_bloqueo INT PRIMARY KEY AUTO_INCREMENT,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    motivo TEXT,
    id_admin INT NOT NULL,
    id_sala INT NOT NULL,
    CONSTRAINT fk_bloqueo_admin FOREIGN KEY (id_admin) REFERENCES usuario(id_usuario),
    CONSTRAINT fk_bloqueo_sala FOREIGN KEY (id_sala) REFERENCES sala(id_sala),
    CONSTRAINT chk_bloqueo_fechas CHECK (fecha_fin > fecha_inicio),
    INDEX idx_bloqueo_rango (id_sala, fecha_inicio, fecha_fin)
);

-- =====================================================================
-- FUNCIÓN AUXILIAR: ¿es un admin activo?
-- =====================================================================
DELIMITER $$
CREATE FUNCTION fn_es_admin(x_id_usuario INT) RETURNS TINYINT(1)
READS SQL DATA
BEGIN
    RETURN EXISTS (SELECT 1 FROM usuario
                   WHERE id_usuario = x_id_usuario AND rol = 'ADMIN' AND estado = 'ACTIVO');
END $$
DELIMITER ;










/*
  ___     ___   ________    ____     ________     ___       ____
  \  \   /  /  |__    __|  / ___|   |__    __|   /   \     / ___|
   \  \ /  /      |  |     \___  \     |  |     /  _  \    \___  \
    \  V  /     __|  |__    ___)  |    |  |    /  ___  \    ___)  |
     \___/     |________|  |_____/     |__|   /__/   \__\  |_____/
*/

CREATE VIEW v_clientes AS
    SELECT id_usuario, nombre, correo, estado, fecha_registro
    FROM usuario WHERE rol = 'CLIENTE';

CREATE VIEW v_clientes_activos AS
    SELECT id_usuario, nombre, correo, fecha_registro, intentos_fallidos
    FROM usuario WHERE estado = 'ACTIVO' AND rol = 'CLIENTE';

CREATE VIEW v_salas_activas AS
    SELECT id_sala, tipo_sala, nombre, precio_hora, hora_apertura, hora_cierre,
           descripcion, equipamiento, capacidad_minima, capacidad_maxima
    FROM sala WHERE estado = 'ACTIVA';

CREATE VIEW v_pagos AS
    SELECT id_pago, monto, metodo_pago, referencia, fecha_pago, id_reserva
    FROM pago WHERE estado = 'PAGADO';

CREATE VIEW v_reembolsos AS
    SELECT id_pago, monto_reembolsado, fecha_reembolso, id_reserva
    FROM pago WHERE estado = 'REEMBOLSADO';

-- Ganancias netas por mes (cobros menos reembolsos)
CREATE VIEW v_ganancias AS
    SELECT YEAR(fecha_pago) anio, MONTH(fecha_pago) mes,
           SUM(monto - monto_reembolsado) total
    FROM pago
    WHERE estado IN ('PAGADO','REEMBOLSADO')
    GROUP BY YEAR(fecha_pago), MONTH(fecha_pago);

CREATE VIEW v_total_de_horas_por_sala AS
    SELECT s.id_sala, s.nombre,
           ROUND(SUM(TIMESTAMPDIFF(MINUTE, r.inicio, r.fin)) / 60, 2) horas
    FROM sala s
    INNER JOIN reserva r ON r.id_sala = s.id_sala
    WHERE r.estado IN ('PAGADO','COMPLETADO')
    GROUP BY s.id_sala, s.nombre;

CREATE VIEW v_horas_concurridas AS
    SELECT HOUR(inicio) hora, COUNT(*) reservaciones
    FROM reserva
    WHERE estado IN ('PAGADO','COMPLETADO')
    GROUP BY HOUR(inicio)
    ORDER BY reservaciones DESC;

CREATE VIEW v_tasa_reembolsos AS
    SELECT ROUND(100 * SUM(monto_reembolsado > 0) / COUNT(*), 1) porcentaje
    FROM pago WHERE estado IN ('PAGADO','REEMBOLSADO');

-- Para que el cliente consulte sus reservas (la API filtra por id_cliente)
CREATE VIEW v_reservas AS
    SELECT id_reserva, inicio, fin, estado, total, fecha_creacion, codigo,
           fecha_expiracion, fecha_cancelacion, motivo_cancelacion, id_cliente, id_sala
    FROM reserva;

-- Para reportes: sin el código de acceso
CREATE VIEW v_reservas_pagadas AS
    SELECT id_reserva, inicio, fin, total, fecha_creacion, id_cliente, id_sala
    FROM reserva WHERE estado IN ('PAGADO','COMPLETADO');

CREATE VIEW v_mejores_clientes AS
    SELECT u.id_usuario id_cliente, u.nombre, u.correo, SUM(r.total) total
    FROM v_clientes_activos u
    INNER JOIN v_reservas_pagadas r ON r.id_cliente = u.id_usuario
    GROUP BY u.id_usuario, u.nombre, u.correo
    ORDER BY total DESC;











/*
  ______  ___       ___  ______   __     __   ________    ____      ____
 |  ____| \  \     /  / |  ____| |   \  |  | |__    __|  /  _  \   / ___|
 |   _|    \  \   /  /  |   _|   |     \|  |    |  |    |  | |  |  \___  \
 |  |___    \   V   /   |  |___  |  |\     |    |  |    |  |_|  |   ___)  |
 |______|    \_____/    |______| |__| \____|    |__|     \_____/   |_____/
*/

-- Borra cuentas que no confirmaron el correo en 24 h
CREATE EVENT ev_eliminar_no_confirmados
ON SCHEDULE EVERY 1 HOUR
DO DELETE FROM usuario
   WHERE estado = 'NO_CONFIRMADO' AND fecha_registro < NOW() - INTERVAL 24 HOUR;

-- Expira reservas pendientes sin pago
CREATE EVENT ev_expirar_reservas
ON SCHEDULE EVERY 1 MINUTE
DO UPDATE reserva SET estado = 'EXPIRADO'
   WHERE estado = 'PENDIENTE' AND fecha_expiracion <= NOW();

-- Pasa a COMPLETADO las reservas pagadas que ya terminaron
CREATE EVENT ev_completar_reservas
ON SCHEDULE EVERY 15 MINUTE
DO UPDATE reserva SET estado = 'COMPLETADO'
   WHERE estado = 'PAGADO' AND fin < NOW();










/*
  ____     _____
 / ___|   |   _  \
 \___  \  |  |_)  |
  ___)  | |   ___/
 |_____/  |__|
*/
-- =====================================================================
-- PROCEDIMIENTOS · CUENTA
-- =====================================================================

-- REGISTRO: devuelve el código para que el backend lo mande por correo
DELIMITER $$
CREATE PROCEDURE sp_registro(
    IN  x_nombre   VARCHAR(20),
    IN  x_correo   VARCHAR(50),
    IN  x_hash_pwd VARCHAR(255),
    OUT y_codigo   INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR 1062
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CORREO_YA_REGISTRADO';

    IF x_nombre IS NULL OR TRIM(x_nombre) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NOMBRE_NECESARIO';
    END IF;
    IF x_correo IS NULL OR TRIM(x_correo) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CORREO_NECESARIO';
    END IF;
    IF x_hash_pwd IS NULL OR x_hash_pwd = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CONTRASENIA_NECESARIA';
    END IF;

    SET y_codigo = FLOOR(100000 + RAND() * 900000);   -- 6 dígitos

    INSERT INTO usuario(nombre, correo, hash_pwd, codigo_confirmacion, codigo_expira)
    VALUES (TRIM(x_nombre), LOWER(TRIM(x_correo)), x_hash_pwd, y_codigo, NOW() + INTERVAL 10 MINUTE);
END $$
DELIMITER ;

-- REENVIAR CÓDIGO (genera uno nuevo)
DELIMITER $$
CREATE PROCEDURE sp_reenviar_codigo(
    IN  x_correo VARCHAR(50),
    OUT y_codigo INT UNSIGNED
)
BEGIN
    SET y_codigo = FLOOR(100000 + RAND() * 900000);

    UPDATE usuario
    SET codigo_confirmacion = y_codigo,
        codigo_expira = NOW() + INTERVAL 10 MINUTE,
        intentos_confirmacion = 0
    WHERE correo = LOWER(TRIM(x_correo)) AND estado = 'NO_CONFIRMADO';

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NO_SE_PUEDE_REENVIAR';
    END IF;
END $$
DELIMITER ;

-- CONFIRMAR REGISTRO (máx. 5 intentos, el código expira a los 10 min)
DELIMITER $$
CREATE PROCEDURE sp_confirmar_registro(
    IN x_correo VARCHAR(50),
    IN x_codigo INT UNSIGNED
)
BEGIN
    DECLARE x_id INT;
    DECLARE x_estado VARCHAR(15);
    DECLARE x_cod INT UNSIGNED;
    DECLARE x_expira DATETIME;

    SELECT id_usuario, estado, codigo_confirmacion, codigo_expira
    INTO x_id, x_estado, x_cod, x_expira
    FROM usuario WHERE correo = LOWER(TRIM(x_correo));

    IF x_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CODIGO_INCORRECTO';
    ELSEIF x_estado <> 'NO_CONFIRMADO' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'YA_SE_CONFIRMO';
    ELSEIF x_cod IS NULL OR x_expira < NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CODIGO_EXPIRADO';
    ELSEIF x_codigo IS NULL OR x_cod <> x_codigo THEN
        UPDATE usuario SET intentos_confirmacion = intentos_confirmacion + 1
        WHERE id_usuario = x_id;
        UPDATE usuario SET codigo_confirmacion = NULL
        WHERE id_usuario = x_id AND intentos_confirmacion >= 5;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CODIGO_INCORRECTO';
    ELSE
        UPDATE usuario
        SET estado = 'ACTIVO', codigo_confirmacion = NULL,
            codigo_expira = NULL, intentos_confirmacion = 0
        WHERE id_usuario = x_id;
    END IF;
END $$
DELIMITER ;

-- LOGIN, paso 1: devuelve id, hash y rol. El backend compara con
-- BCrypt (matches) y luego llama a sp_registrar_login.
DELIMITER $$
CREATE PROCEDURE sp_credenciales(
    IN  x_correo VARCHAR(50),
    OUT y_id_usuario INT,
    OUT y_hash_pwd VARCHAR(255),
    OUT y_rol VARCHAR(10)
)
BEGIN
    DECLARE x_estado VARCHAR(15);
    DECLARE x_bloqueado_hasta DATETIME;

    SELECT id_usuario, hash_pwd, rol, estado, bloqueado_hasta
    INTO y_id_usuario, y_hash_pwd, y_rol, x_estado, x_bloqueado_hasta
    FROM usuario WHERE correo = LOWER(TRIM(x_correo));

    IF y_id_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CREDENCIALES_INVALIDAS';
    ELSEIF x_bloqueado_hasta IS NOT NULL AND x_bloqueado_hasta > NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'INTENTALO_MAS_TARDE';
    ELSEIF x_estado <> 'ACTIVO' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CUENTA_NO_DISPONIBLE';
    END IF;
END $$
DELIMITER ;

-- LOGIN, paso 2: registrar éxito o fallo (5 fallos = 5 min de bloqueo)
DELIMITER $$
CREATE PROCEDURE sp_registrar_login(
    IN x_id_usuario INT,
    IN x_exito TINYINT(1)
)
BEGIN
    IF x_exito = 1 THEN
        UPDATE usuario SET intentos_fallidos = 0, bloqueado_hasta = NULL
        WHERE id_usuario = x_id_usuario;
    ELSE
        UPDATE usuario SET intentos_fallidos = intentos_fallidos + 1
        WHERE id_usuario = x_id_usuario;
        UPDATE usuario SET bloqueado_hasta = NOW() + INTERVAL 5 MINUTE, intentos_fallidos = 0
        WHERE id_usuario = x_id_usuario AND intentos_fallidos >= 5;
    END IF;
END $$
DELIMITER ;

-- ADMIN: bloquear / desbloquear cliente (alterna ACTIVO <-> BLOQUEADO)
DELIMITER $$
CREATE PROCEDURE sp_activar_desactivar_cliente(
    IN x_id_cliente INT,
    IN x_id_admin INT
)
BEGIN
    DECLARE x_estado VARCHAR(15);
    DECLARE x_nuevo VARCHAR(15);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_es_admin(x_id_admin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NO_AUTORIZADO';
    END IF;

    START TRANSACTION;
    SELECT estado INTO x_estado FROM usuario
    WHERE id_usuario = x_id_cliente AND rol = 'CLIENTE' FOR UPDATE;

    IF x_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CLIENTE_NO_ENCONTRADO';
    ELSEIF x_estado = 'ACTIVO' THEN
        SET x_nuevo = 'BLOQUEADO';
    ELSEIF x_estado = 'BLOQUEADO' THEN
        SET x_nuevo = 'ACTIVO';
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ESTADO_NO_MODIFICABLE';
    END IF;

    UPDATE usuario SET estado = x_nuevo, intentos_fallidos = 0, bloqueado_hasta = NULL
    WHERE id_usuario = x_id_cliente;

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('usuario',
            JSON_OBJECT('viejo', JSON_OBJECT('estado', x_estado),
                        'nuevo', JSON_OBJECT('estado', x_nuevo)),
            x_id_cliente, 'ACTUALIZACION', x_id_admin);
    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- PROCEDIMIENTOS · SALAS (ADMIN)
-- =====================================================================
DELIMITER $$
CREATE PROCEDURE sp_crear_sala(
    IN x_tipo_sala VARCHAR(50),
    IN x_nombre VARCHAR(50),
    IN x_precio_hora DECIMAL(10,2),
    IN x_hora_apertura TIME,
    IN x_hora_cierre TIME,
    IN x_descripcion TEXT,
    IN x_equipamiento JSON,
    IN x_capacidad_minima INT UNSIGNED,
    IN x_capacidad_maxima INT UNSIGNED,
    IN x_id_admin INT,
    OUT y_id_sala INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_es_admin(x_id_admin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NO_AUTORIZADO';
    END IF;
    IF x_tipo_sala IS NULL OR TRIM(x_tipo_sala) = '' OR x_nombre IS NULL OR TRIM(x_nombre) = ''
       OR x_precio_hora IS NULL OR x_hora_apertura IS NULL OR x_hora_cierre IS NULL
       OR x_equipamiento IS NULL OR x_capacidad_minima IS NULL OR x_capacidad_maxima IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FALTAN_CAMPOS';
    END IF;
    IF x_precio_hora <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PRECIO_INVALIDO';
    END IF;
    IF x_hora_apertura >= x_hora_cierre THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'HORARIO_INVALIDO';
    END IF;
    IF x_capacidad_minima < 1 OR x_capacidad_minima > x_capacidad_maxima THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CAPACIDAD_INVALIDA';
    END IF;

    START TRANSACTION;
    INSERT INTO sala(tipo_sala, nombre, precio_hora, hora_apertura, hora_cierre, descripcion,
                     equipamiento, capacidad_minima, capacidad_maxima)
    VALUES (x_tipo_sala, x_nombre, x_precio_hora, x_hora_apertura, x_hora_cierre, x_descripcion,
            x_equipamiento, x_capacidad_minima, x_capacidad_maxima);
    SET y_id_sala = LAST_INSERT_ID();

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('sala',
            JSON_OBJECT('nuevo', JSON_OBJECT('nombre', x_nombre, 'tipo_sala', x_tipo_sala,
                                             'precio_hora', x_precio_hora)),
            y_id_sala, 'INSERCION', x_id_admin);
    COMMIT;
END $$
DELIMITER ;

-- Los parámetros en NULL no se modifican. Audita valores viejo y nuevo.
DELIMITER $$
CREATE PROCEDURE sp_editar_sala(
    IN x_id_sala INT,
    IN x_tipo_sala VARCHAR(50),
    IN x_nombre VARCHAR(50),
    IN x_precio_hora DECIMAL(10,2),
    IN x_hora_apertura TIME,
    IN x_hora_cierre TIME,
    IN x_descripcion TEXT,
    IN x_equipamiento JSON,
    IN x_capacidad_minima INT UNSIGNED,
    IN x_capacidad_maxima INT UNSIGNED,
    IN x_id_admin INT
)
BEGIN
    DECLARE x_viejo JSON;
    DECLARE x_nuevo JSON;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_es_admin(x_id_admin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NO_AUTORIZADO';
    END IF;

    START TRANSACTION;
    SELECT JSON_OBJECT('tipo_sala', tipo_sala, 'nombre', nombre, 'precio_hora', precio_hora,
                       'hora_apertura', hora_apertura, 'hora_cierre', hora_cierre,
                       'descripcion', descripcion, 'equipamiento', equipamiento,
                       'capacidad_minima', capacidad_minima, 'capacidad_maxima', capacidad_maxima)
    INTO x_viejo FROM sala WHERE id_sala = x_id_sala FOR UPDATE;

    IF x_viejo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_INEXISTENTE';
    END IF;

    -- Si algún valor viola un CHECK (precio, horario, capacidad), MySQL lanza
    -- error y el handler hace ROLLBACK.
    UPDATE sala SET
        tipo_sala = COALESCE(x_tipo_sala, tipo_sala),
        nombre = COALESCE(x_nombre, nombre),
        precio_hora = COALESCE(x_precio_hora, precio_hora),
        hora_apertura = COALESCE(x_hora_apertura, hora_apertura),
        hora_cierre = COALESCE(x_hora_cierre, hora_cierre),
        descripcion = COALESCE(x_descripcion, descripcion),
        equipamiento = COALESCE(x_equipamiento, equipamiento),
        capacidad_minima = COALESCE(x_capacidad_minima, capacidad_minima),
        capacidad_maxima = COALESCE(x_capacidad_maxima, capacidad_maxima)
    WHERE id_sala = x_id_sala;

    SELECT JSON_OBJECT('tipo_sala', tipo_sala, 'nombre', nombre, 'precio_hora', precio_hora,
                       'hora_apertura', hora_apertura, 'hora_cierre', hora_cierre,
                       'descripcion', descripcion, 'equipamiento', equipamiento,
                       'capacidad_minima', capacidad_minima, 'capacidad_maxima', capacidad_maxima)
    INTO x_nuevo FROM sala WHERE id_sala = x_id_sala;

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('sala', JSON_OBJECT('viejo', x_viejo, 'nuevo', x_nuevo),
            x_id_sala, 'ACTUALIZACION', x_id_admin);
    COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_desactivar_sala(
    IN x_id_sala INT,
    IN x_id_admin INT
)
BEGIN
    DECLARE x_estado VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_es_admin(x_id_admin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NO_AUTORIZADO';
    END IF;

    START TRANSACTION;
    SELECT estado INTO x_estado FROM sala WHERE id_sala = x_id_sala FOR UPDATE;
    IF x_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_INEXISTENTE';
    END IF;

    -- Solo importan reservas vigentes y futuras
    IF EXISTS (SELECT 1 FROM reserva
               WHERE id_sala = x_id_sala AND fin > NOW()
                 AND (estado = 'PAGADO' OR (estado = 'PENDIENTE' AND fecha_expiracion > NOW()))) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_RESERVADA';
    END IF;

    UPDATE sala SET estado = 'INACTIVA' WHERE id_sala = x_id_sala;

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('sala',
            JSON_OBJECT('viejo', JSON_OBJECT('estado', x_estado),
                        'nuevo', JSON_OBJECT('estado', 'INACTIVA')),
            x_id_sala, 'ACTUALIZACION', x_id_admin);
    COMMIT;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_activar_sala(
    IN x_id_sala INT,
    IN x_id_admin INT
)
BEGIN
    DECLARE x_estado VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_es_admin(x_id_admin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NO_AUTORIZADO';
    END IF;

    START TRANSACTION;
    SELECT estado INTO x_estado FROM sala WHERE id_sala = x_id_sala FOR UPDATE;
    IF x_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_INEXISTENTE';
    END IF;

    UPDATE sala SET estado = 'ACTIVA' WHERE id_sala = x_id_sala;

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('sala',
            JSON_OBJECT('viejo', JSON_OBJECT('estado', x_estado),
                        'nuevo', JSON_OBJECT('estado', 'ACTIVA')),
            x_id_sala, 'ACTUALIZACION', x_id_admin);
    COMMIT;
END $$
DELIMITER ;

-- Bloqueo programado por mantenimiento. No cambia sala.estado: sp_reservar
-- y sp_salas_disponibles consultan la tabla bloqueo.
DELIMITER $$
CREATE PROCEDURE sp_bloquear_sala(
    IN x_id_sala INT,
    IN x_id_admin INT,
    IN x_fecha_inicio DATETIME,
    IN x_fecha_fin DATETIME,
    IN x_motivo TEXT,
    OUT y_id_bloqueo INT
)
BEGIN
    DECLARE x_estado VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_es_admin(x_id_admin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'NO_AUTORIZADO';
    END IF;
    IF x_fecha_inicio IS NULL OR x_fecha_fin IS NULL OR x_fecha_fin <= x_fecha_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RANGO_FECHAS_INVALIDO';
    END IF;

    START TRANSACTION;
    SELECT estado INTO x_estado FROM sala WHERE id_sala = x_id_sala FOR UPDATE;
    IF x_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_INEXISTENTE';
    END IF;

    IF EXISTS (SELECT 1 FROM reserva
               WHERE id_sala = x_id_sala
                 AND (estado = 'PAGADO' OR (estado = 'PENDIENTE' AND fecha_expiracion > NOW()))
                 AND x_fecha_inicio < fin AND x_fecha_fin > inicio) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SE_INTERPONEN_RESERVAS';
    END IF;

    INSERT INTO bloqueo(fecha_inicio, fecha_fin, motivo, id_admin, id_sala)
    VALUES (x_fecha_inicio, x_fecha_fin, x_motivo, x_id_admin, x_id_sala);
    SET y_id_bloqueo = LAST_INSERT_ID();

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('bloqueo',
            JSON_OBJECT('nuevo', JSON_OBJECT('id_sala', x_id_sala, 'fecha_inicio', x_fecha_inicio,
                                             'fecha_fin', x_fecha_fin)),
            y_id_bloqueo, 'INSERCION', x_id_admin);
    COMMIT;
END $$
DELIMITER ;

-- =====================================================================
-- PROCEDIMIENTOS · RESERVAS (CLIENTE)
-- =====================================================================

-- Salas libres en un rango (x_capacidad puede ser NULL)
DELIMITER $$
CREATE PROCEDURE sp_salas_disponibles(
    IN x_inicio DATETIME,
    IN x_fin DATETIME,
    IN x_capacidad INT UNSIGNED
)
BEGIN
    IF x_inicio IS NULL OR x_fin IS NULL OR x_fin <= x_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RANGO_FECHAS_INVALIDO';
    END IF;

    SELECT s.id_sala, s.nombre, s.tipo_sala, s.precio_hora,
           s.capacidad_minima, s.capacidad_maxima, s.equipamiento
    FROM sala s
    WHERE s.estado = 'ACTIVA'
      AND TIME(x_inicio) >= s.hora_apertura AND TIME(x_fin) <= s.hora_cierre
      AND (x_capacidad IS NULL OR x_capacidad BETWEEN s.capacidad_minima AND s.capacidad_maxima)
      AND NOT EXISTS (SELECT 1 FROM bloqueo b
                      WHERE b.id_sala = s.id_sala
                        AND x_inicio < b.fecha_fin AND x_fin > b.fecha_inicio)
      AND NOT EXISTS (SELECT 1 FROM reserva r
                      WHERE r.id_sala = s.id_sala
                        AND (r.estado IN ('PAGADO','COMPLETADO')
                             OR (r.estado = 'PENDIENTE' AND r.fecha_expiracion > NOW()))
                        AND x_inicio < r.fin AND x_fin > r.inicio);
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_reservar(
    IN  x_fecha_inicio DATETIME,
    IN  x_fecha_fin DATETIME,
    IN  x_id_cliente INT,
    IN  x_id_sala INT,
    OUT y_id_reserva INT,
    OUT y_total DECIMAL(10,2)
)
BEGIN
    DECLARE x_ahora DATETIME;
    DECLARE x_estado_usuario VARCHAR(15);
    DECLARE x_estado_sala VARCHAR(10);
    DECLARE x_precio_hora DECIMAL(10,2);
    DECLARE x_apertura TIME;
    DECLARE x_cierre TIME;
    DECLARE x_total DECIMAL(10,2);
    DECLARE x_fecha_expiracion DATETIME;
    DECLARE x_codigo INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET x_ahora = NOW();

    IF x_fecha_inicio IS NULL OR x_fecha_fin IS NULL OR x_id_cliente IS NULL OR x_id_sala IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FALTAN_CAMPOS';
    END IF;
    IF x_fecha_fin <= x_fecha_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RANGO_FECHAS_INVALIDO';
    END IF;
    IF DATE(x_fecha_inicio) <> DATE(x_fecha_fin) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_DE_UN_SOLO_DIA';
    END IF;
    IF x_fecha_inicio < x_ahora THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FECHA_EN_EL_PASADO';
    END IF;
    IF x_fecha_inicio > x_ahora + INTERVAL 60 DAY THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'MUY_LEJOS_EN_EL_FUTURO';
    END IF;

    START TRANSACTION;

    -- Orden fijo de bloqueo (usuario y luego sala) para evitar deadlocks.
    -- Bloquear al usuario evita pasarse del límite con reservas en paralelo.
    SELECT estado INTO x_estado_usuario FROM usuario
    WHERE id_usuario = x_id_cliente FOR UPDATE;
    IF x_estado_usuario IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USUARIO_INEXISTENTE';
    ELSEIF x_estado_usuario <> 'ACTIVO' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USUARIO_INACTIVO';
    END IF;

    -- Bloquear la sala serializa las reservas concurrentes de la misma sala
    SELECT estado, precio_hora, hora_apertura, hora_cierre
    INTO x_estado_sala, x_precio_hora, x_apertura, x_cierre
    FROM sala WHERE id_sala = x_id_sala FOR UPDATE;
    IF x_estado_sala IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_INEXISTENTE';
    ELSEIF x_estado_sala <> 'ACTIVA' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_NO_ACTIVA';
    END IF;

    IF TIME(x_fecha_inicio) < x_apertura OR TIME(x_fecha_fin) > x_cierre THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'HORA_FUERA_DE_RANGO';
    END IF;

    IF (SELECT COUNT(*) FROM reserva
        WHERE id_cliente = x_id_cliente AND fin > x_ahora
          AND (estado = 'PAGADO' OR (estado = 'PENDIENTE' AND fecha_expiracion > x_ahora))) >= 3 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'LIMITE_3_RESERVAS';
    END IF;

    IF EXISTS (SELECT 1 FROM bloqueo
               WHERE id_sala = x_id_sala
                 AND x_fecha_inicio < fecha_fin AND x_fecha_fin > fecha_inicio) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_BLOQUEADA';
    END IF;

    -- Traslape (las pendientes ya vencidas no cuentan)
    IF EXISTS (SELECT 1 FROM reserva
               WHERE id_sala = x_id_sala
                 AND (estado IN ('PAGADO','COMPLETADO')
                      OR (estado = 'PENDIENTE' AND fecha_expiracion > x_ahora))
                 AND x_fecha_inicio < fin AND x_fecha_fin > inicio) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_SOBREPUESTA';
    END IF;

    SET x_total = ROUND(x_precio_hora * TIMESTAMPDIFF(MINUTE, x_fecha_inicio, x_fecha_fin) / 60, 2);
    IF WEEKDAY(x_fecha_inicio) >= 5 THEN               -- sábado o domingo: 30 % menos
        SET x_total = ROUND(x_total * 0.7, 2);
    END IF;

    -- Expiración: 15 min si es inmediata; si no, 15 min antes del inicio (máx. 12 h)
    IF x_fecha_inicio < x_ahora + INTERVAL 30 MINUTE THEN
        SET x_fecha_expiracion = LEAST(x_fecha_inicio, x_ahora + INTERVAL 15 MINUTE);
    ELSE
        SET x_fecha_expiracion = LEAST(x_fecha_inicio - INTERVAL 15 MINUTE,
                                       x_ahora + INTERVAL 12 HOUR);
    END IF;

    SET x_codigo = FLOOR(100000000 + RAND() * 900000000);   -- 9 dígitos

    INSERT INTO reserva(inicio, fin, estado, total, fecha_creacion, codigo,
                        fecha_expiracion, id_cliente, id_sala)
    VALUES (x_fecha_inicio, x_fecha_fin, 'PENDIENTE', x_total, x_ahora, x_codigo,
            x_fecha_expiracion, x_id_cliente, x_id_sala);

    SET y_id_reserva = LAST_INSERT_ID();
    SET y_total = x_total;

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('reserva',
            JSON_OBJECT('nuevo', JSON_OBJECT('id_sala', x_id_sala, 'inicio', x_fecha_inicio,
                                             'fin', x_fecha_fin, 'total', x_total)),
            y_id_reserva, 'INSERCION', x_id_cliente);
    COMMIT;
END $$
DELIMITER ;

-- PAGAR: el monto sale siempre de reserva.total, no de un parámetro
DELIMITER $$
CREATE PROCEDURE sp_pagar(
    IN x_id_reserva INT,
    IN x_id_cliente INT,
    IN x_metodo_pago VARCHAR(15),
    IN x_referencia VARCHAR(17)
)
BEGIN
    DECLARE x_estado VARCHAR(15);
    DECLARE x_total DECIMAL(10,2);
    DECLARE x_expira DATETIME;
    DECLARE x_dueno INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF x_metodo_pago IS NULL OR x_metodo_pago NOT IN ('EFECTIVO','DIGITAL') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'METODO_PAGO_INVALIDO';
    END IF;

    START TRANSACTION;
    SELECT estado, total, fecha_expiracion, id_cliente
    INTO x_estado, x_total, x_expira, x_dueno
    FROM reserva WHERE id_reserva = x_id_reserva FOR UPDATE;

    IF x_estado IS NULL OR x_dueno <> x_id_cliente THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_NO_ENCONTRADA';
    ELSEIF x_estado <> 'PENDIENTE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_NO_PENDIENTE';
    ELSEIF x_expira <= NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_EXPIRADA';
    END IF;

    INSERT INTO pago(monto, metodo_pago, estado, referencia, fecha_pago, id_reserva)
    VALUES (x_total, x_metodo_pago, 'PAGADO', x_referencia, NOW(), x_id_reserva);

    UPDATE reserva SET estado = 'PAGADO' WHERE id_reserva = x_id_reserva;

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('reserva',
            JSON_OBJECT('viejo', JSON_OBJECT('estado', 'PENDIENTE'),
                        'nuevo', JSON_OBJECT('estado', 'PAGADO')),
            x_id_reserva, 'ACTUALIZACION', x_id_cliente);
    COMMIT;
END $$
DELIMITER ;

-- CANCELAR: reembolso 100 % (>= 24 h), 50 % (>= 2 h) o 0 %
DELIMITER $$
CREATE PROCEDURE sp_cancelar(
    IN x_id_reserva INT,
    IN x_id_cliente INT,
    IN x_motivo_cancelacion TEXT
)
BEGIN
    DECLARE x_estado VARCHAR(15);
    DECLARE x_inicio DATETIME;
    DECLARE x_dueno INT;
    DECLARE x_monto_pagado DECIMAL(10,2);
    DECLARE x_reembolso DECIMAL(10,2) DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT estado, inicio, id_cliente INTO x_estado, x_inicio, x_dueno
    FROM reserva WHERE id_reserva = x_id_reserva FOR UPDATE;

    IF x_estado IS NULL OR x_dueno <> x_id_cliente THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_NO_ENCONTRADA';
    ELSEIF x_estado NOT IN ('PENDIENTE','PAGADO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_NO_CANCELABLE';
    ELSEIF x_inicio <= NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_YA_INICIADA';
    END IF;

    UPDATE reserva
    SET estado = 'CANCELADO', fecha_cancelacion = NOW(), motivo_cancelacion = x_motivo_cancelacion
    WHERE id_reserva = x_id_reserva;

    IF x_estado = 'PAGADO' THEN
        SELECT monto INTO x_monto_pagado FROM pago WHERE id_reserva = x_id_reserva FOR UPDATE;

        IF x_monto_pagado IS NOT NULL THEN
            IF x_inicio >= NOW() + INTERVAL 24 HOUR THEN
                SET x_reembolso = x_monto_pagado;
            ELSEIF x_inicio >= NOW() + INTERVAL 2 HOUR THEN
                SET x_reembolso = ROUND(x_monto_pagado * 0.5, 2);
            ELSE
                SET x_reembolso = 0;
            END IF;

            -- Con reembolso 0 el pago se queda como PAGADO (el dinero se conserva)
            IF x_reembolso > 0 THEN
                UPDATE pago
                SET monto_reembolsado = x_reembolso, fecha_reembolso = NOW(), estado = 'REEMBOLSADO'
                WHERE id_reserva = x_id_reserva;
            END IF;
        END IF;
    END IF;

    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
    VALUES ('reserva',
            JSON_OBJECT('viejo', JSON_OBJECT('estado', x_estado),
                        'nuevo', JSON_OBJECT('estado', 'CANCELADO', 'reembolso', x_reembolso)),
            x_id_reserva, 'ACTUALIZACION', x_id_cliente);
    COMMIT;
END $$
DELIMITER ;

-- RESEÑAR: solo el dueño, solo reservas ya terminadas, una por reserva
DELIMITER $$
CREATE PROCEDURE sp_reseniar(
    IN x_id_reserva INT,
    IN x_id_cliente INT,
    IN x_calificacion TINYINT,
    IN x_comentario TEXT
)
BEGIN
    DECLARE x_estado VARCHAR(15);
    DECLARE x_fin DATETIME;
    DECLARE x_dueno INT;
    DECLARE EXIT HANDLER FOR 1062
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'YA_RESENIADA';

    IF x_calificacion IS NULL OR x_calificacion NOT BETWEEN 1 AND 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CALIFICACION_INVALIDA';
    END IF;

    SELECT estado, fin, id_cliente INTO x_estado, x_fin, x_dueno
    FROM reserva WHERE id_reserva = x_id_reserva;

    IF x_estado IS NULL OR x_dueno <> x_id_cliente THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_NO_ENCONTRADA';
    ELSEIF x_estado NOT IN ('PAGADO','COMPLETADO') OR x_fin > NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_NO_FINALIZADA';
    END IF;

    INSERT INTO resenia(calificacion, comentario, id_reserva)
    VALUES (x_calificacion, x_comentario, x_id_reserva);
END $$
DELIMITER ;
