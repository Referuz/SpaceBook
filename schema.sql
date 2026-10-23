DROP DATABASE IF EXISTS db_spacebook;
CREATE DATABASE db_spacebook;
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
    rol ENUM("ADMIN","CLIENTE") NOT NULL DEFAULT "CLIENTE",
    estado ENUM("ACTIVO", "INACTIVO", "BLOQUEADO", "NO_CONFIRMADO") NOT NULL DEFAULT "NO_CONFIRMADO",
    fecha_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0,
    codigo_confirmacion INT
);

CREATE TABLE sala ( 
    id_sala INT PRIMARY KEY AUTO_INCREMENT,
    tipo_sala VARCHAR(50) NOT NULL,
    estado ENUM("ACTIVA","INACTIVA","BLOQUEADA") NOT NULL DEFAULT "ACTIVA",
    nombre VARCHAR(50) NOT NULL,
    precio_hora DECIMAL NOT NULL,
    hora_apertura TIME NOT NULL,
    hora_cierre TIME NOT NULL,
    descripcion TEXT,
    equipamiento JSON NOT NULL,
    capacidad_minima INT UNSIGNED NOT NULL,
    capacidad_maxima INT UNSIGNED NOT NULL
);

CREATE TABLE reserva (
    id_reserva INT PRIMARY KEY AUTO_INCREMENT,
    inicio DATETIME,
    fin DATETIME,
    estado ENUM("PENDIENTE", "PAGADO", "CANCELADO", "EXPIRADO", "COMPLETADO"),
    total DECIMAL,
    fecha_creacion DATETIME,
    codigo INT UNSIGNED UNIQUE, -- Codigo de barras o qr
    fecha_expiracion DATETIME,
    fecha_cancelacion DATETIME,
    motivo_cancelacion TEXT,
    id_cliente INT NOT NULL,
    id_sala INT NOT NULL,
    CONSTRAINT id_cliente_reserva FOREIGN KEY (id_cliente) REFERENCES usuario(id_usuario),
    CONSTRAINT id_sala_reserva FOREIGN KEY (id_sala) REFERENCES sala(id_sala)
);

CREATE TABLE pago (
    id_pago INT PRIMARY KEY AUTO_INCREMENT,
    monto DECIMAL,
    metodo_pago ENUM("EFECTIVO","DIGITAL"),
    estado ENUM("PENDIENTE", "PAGADO", "CANCELADO","REEMBOLSADO"),
    referencia VARCHAR(17),
    fecha_pago DATETIME,
    monto_reembolsado DECIMAL DEFAULT 0.0,
    fecha_reembolso DATETIME DEFAULT NULL,
    id_reserva INT NOT NULL,
    CONSTRAINT id_reserva_pago FOREIGN KEY (id_reserva) REFERENCES reserva(id_reserva)
);

CREATE TABLE resenia (
    id_resenia INT PRIMARY KEY AUTO_INCREMENT,
    calificacion TINYINT NOT NULL,
    comentario TEXT,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_reserva INT NOT NULL,
    id_sala INT NOT NULL,
    CONSTRAINT id_reserva_resenia FOREIGN KEY (id_reserva) REFERENCES reserva(id_reserva),
    CONSTRAINT id_sala_resenia FOREIGN KEY (id_sala) REFERENCES sala(id_sala)
);

CREATE TABLE auditoria (
    id_adutoria INT PRIMARY KEY AUTO_INCREMENT,
    fecha_auditoria TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tabla VARCHAR(20) NOT NULL,
    actualizacion JSON,
    id_campo_actualizado INT NOT NULL,
    tipo_movimiento VARCHAR(30) NOT NULL,
    id_usuario INT NOT NULL,
    CONSTRAINT id_usuario_auditoria FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
);

CREATE TABLE bloqueo (
    id_bloqueo INT PRIMARY KEY AUTO_INCREMENT,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    motivo TEXT,
    id_admin INT NOT NULL,
    id_sala INT NOT NULL,
    CONSTRAINT id_admin_bloqueo FOREIGN KEY (id_admin) REFERENCES usuario(id_usuario),
    CONSTRAINT id_sala_bloqueo FOREIGN KEY (id_sala) REFERENCES sala(id_sala)
);









/*
 ___     ___   ________    ____     ________     ___       ____  
 \  \   /  /  |__    __|  / ___|   |__    __|   /   \     / ___| 
  \  \ /  /      |  |     \___  \     |  |     /  _  \    \___  \ 
   \  V  /     __|  |__    ___)  |    |  |    /  ___  \    ___)  |
    \___/     |________|  |_____/     |__|   /__/   \__\  |_____/ 
*/

CREATE VIEW v_clientes_activos AS
	SELECT id_usuario, nombre, correo, fecha_registro, intentos_fallidos
	FROM usuario WHERE estado = "ACTIVO" AND rol = "CLIENTE"
;

CREATE VIEW v_clientes AS
	SELECT id_usuario, nombre, correo, fecha_registro, intentos_fallidos
	FROM usuario WHERE estado = "ACTIVO" AND rol = "CLIENTE"
;

CREATE VIEW v_pagos AS
	SELECT id_pago, monto, metodo_pago, referencia, fecha_pago, id_reserva
    FROM pago WHERE estado = "PAGADO";
;

CREATE VIEW v_reembolsos AS
	SELECT id_pago, monto_reembolsado, fecha_reembolso, id_reserva
    FROM pago WHERE estodo = "REEMBOLSADO";
;

CREATE VIEW v_ganancias AS
	SELECT id_pago, metodo_pago, fecha_pago, fecha_reembolso, SUM(monto - IFNULL(monto_reembolsado, 0)) total
    FROM pago WHERE estado = "PAGADO" GROUP BY MONTH(fecha_pago)
;

CREATE VIEW v_total_de_horas_por_sala AS
	SELECT sala.id_sala, sala.nombre, SUM(TIMESTAMPDIFF(HOUR, reserva.inicio, reserva.fin)) horas FROM reserva reserva
	INNER JOIN sala sala ON sala.id_sala = reserva.id_sala WHERE reserva.estado = "PAGADO" GROUP BY id_sala;
;

SELECT sala.id_sala, sala.nombre, SUM(TIMESTAMPDIFF(HOUR, reserva.inicio, reserva.fin)) horas FROM reserva reserva
	INNER JOIN sala sala ON sala.id_sala = reserva.id_sala WHERE reserva.estado = "PAGADO" GROUP BY id_sala;

CREATE VIEW v_horas_concuridas AS
	SELECT COUNT(id_reserva) reservaciones, TIME(inicio) fecha_inicio, TIME(fin) fecha_fin 
	FROM reserva GROUP BY TIME(inicio), TIME(fin) ORDER BY TIME(inicio) DESC;
;

CREATE VIEW v_tasa_reembolsos AS
	SELECT 
		CONCAT(CAST(ROUND(COUNT(CASE WHEN monto_reembolsado <> 0 THEN 1 END) * 100.0 / COUNT(*), 0) AS CHAR),"%") porcentaje 
    FROM pago;
;

CREATE VIEW v_reservas AS
	SELECT id_reserva, inicio, fin, total, fecha_creacion, codigo, 
    fecha_expiracion, fecha_cancelacion, motivo_cancelacion, id_cliente, id_sala from reserva;
;

CREATE VIEW v_reservas_pagadas AS
	SELECT id_reserva, inicio, fin, total, fecha_creacion, codigo, 
    fecha_expiracion, id_cliente, id_sala 
    FROM reserva WHERE estado = "PAGADO";
;

CREATE VIEW v_mejores_clientes AS
	SELECT v_u.id_usuario id_cliente, v_u.nombre nombre, v_u.correo correo, SUM(v_r.total) total
	FROM v_usuarios_activos v_u INNER JOIN v_reservas_pagadas v_r ON
	v_u.id_usuario = v_r.id_cliente GROUP BY id_cliente;
;









/*
 ______  ___       ___  ______   __     __   ________    ____      ____  
|  ____| \  \     /  / |  ____| |   \  |  | |__    __|  /  _  \   / ___| 
|   _|    \  \   /  /  |   _|   |     \|  |    |  |    |  | |  |  \___  \ 
|  |___    \   V   /   |  |___  |  |\     |    |  |    |  |_|  |   ___)  |
|______|    \_____/    |______| |__| \____|    |__|     \_____/   |_____/ 
*/

-- EVENTO PARA RESETEAR LOS INTENTOS FALIDOS CADA 5 MIN
-- Reinicia el contador de intentos fallidos a 0 al llegar a 5 luego de 5min
DELIMITER $$
CREATE EVENT ev_reiniciar_de_logeo
ON SCHEDULE EVERY 5 MINUTE
DO
BEGIN
	UPDATE usuario SET intentos_fallidos = 0 WHERE intentos_fallidos >= 5;
END $$
DELIMITER ;

-- Borra la cuenta si no se confirmo el correo
CREATE EVENT ev_eliminacion_registros_no_confirmados
ON SCHEDULE EVERY 24 HOUR
DO
BEGIN
	DELETE FROM usuario WHERE estado = "NOT_CONFIRMED"
END $$
DELIMITER ;

-- Desactivar salas
DELIMITER $$
CREATE EVENT ev_desboquear_salas
ON SCHEDULE EVERY 15 MINUTE
DO
BEGIN
    DECLARE x_id_sala INT;
    SET x_id_sala = (SELECT id_sala FROM sala WHERE estado = "BLOQUEADA");
    
    IF (SELECT fecha_fin FROM bloqueo WHERE id_sala = x_id_sala) <= NOW() OR 
	(SELECT fecha_fin FROM bloqueo WHERE id_sala = x_id_sala) + INTERVAL 15 MINUTE <= NOW() THEN
		UPDATE sala SET estado = "ACTIVA" WHERE id_sala = x_id_sala;
	END IF;
END $$
DELIMITER ;

-- Expiracion de reservaciones
DELIMITER $$
CREATE EVENT sv_expirar_reservas
ON SCHEDULE EVERY 5 MINUTE
DO
BEGIN
	UPDATE reserva SET estado = "EXPIRADO" WHERE (fecha_expiracion < NOW() OR 
    fecha_expiracion < (NOW() + INTERVAL 5 MINUTE)) AND estado = "PENDIENTE";
END $$
DELIMITER ;







/*
 ____     _____
/ ___|   |   _  \ 
\___  \  |  |_)  |
 ___)  | |   ___/ 
|_____/  |__|    
*/

-- CLIENTE
-- REGISTRO: nombre, correo, hash_pwd, 
-- NOTA: requiere confirmacion de correo para activar la cuenta
DELIMITER $$
CREATE PROCEDURE sp_registro(
	IN x_nombre VARCHAR(20),		-- 1
    IN x_correo VARCHAR(50), 		-- 2
    IN x_hash_pwd VARCHAR(255), 	-- 3
    OUT x_estado VARCHAR(15) 		-- 4
)
BEGIN
	DECLARE x_codigo_confirmacion INT;
    -- nota: rand da numero entre 0 y 1 sin 1 con 6 decimales ejemplo 0.123456
    SET x_codigo_confirmacion = LPAD((FLOOR(RAND() * 1000000)), 6, "0");
    
    IF x_nombre IS NULL OR x_nombre = "" THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "NOMBRE_NECESARIO";
    END IF;
    
    IF x_correo IS NULL OR x_correo = "" THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "CORREO_NECESARIO";
    END IF;
    
    IF x_hash_pwd IS NULL OR x_hash_pwd = "" THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "CONTRASENIA_NECESARIO";
    END IF;

	INSERT INTO usuario(nombre, correo, hash_pwd, codigo_confirmacion) values(x_nombre, x_correo, x_hash_pwd, x_codigo_confirmacion);
    IF LAST_INSERT_ID() <> 0 THEN SET x_estado = "REGISTRADO"; END IF;
END $$
DELIMITER ;

-- CLIENTE
-- Confirmacion de registro
DELIMITER $$
CREATE PROCEDURE sp_confirmar_registro(
	IN x_correo VARCHAR(50),		-- 1
	IN x_codigo_confirmacion INT,	-- 2
    OUT estado VARCHAR(15)			-- 3
)
BEGIN
	IF (SELECT codigo FROM usuario WHERE correo = x_correo) = x_codigo_confirmacion THEN
		IF (SELECT estado FROM usuario WHERE correo = x_correo) = "NO_CONFIRMADO" THEN
			UPDATE usuario SET estado = "ACTIVO" WHERE correo = x_correo;
		ELSE 
			SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "YA_SE_CONFIRMO";
		END IF;
	ELSE 
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "CODIGO_INCORRECTO";
	END IF;
END $$
DELIMITER ;

-- USUARIO
-- INICIAR SESIÓN: correo, contraseña. Me devuele el id para identificarlo
-- NOTA: se acomulan 5 intentos fallidos al 6to pide que esperes 5min
DELIMITER $$
CREATE PROCEDURE sp_iniciar_sesion(
	IN x_correo VARCHAR(50),		-- 1
    IN x_hash_pwd VARCHAR(255), 	-- 2
    OUT x_id_usuario INT			-- 3
)
BEGIN
    IF (SELECT intentos_fallidos FROM usuario WHERE correo = x_correo) >= 5 THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "INTENTALO_MAS_TARDE";    
    ELSEIF (SELECT COUNT(*) FROM usuario WHERE correo = x_correo) = 1 THEN
		IF (SELECT hash_pwd FROM usuario WHERE correo = x_correo) = x_hash_pwd THEN
			SET x_id_usuario = (SELECT id_usuario FROM usuario WHERE correo = x_correo and hash_pwd = x_hash_pwd);
		ELSE 
			UPDATE usuario SET intentos_fallidos = intentos_fallidos+1 WHERE correo = x_correo;
			SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "CONTRASENIA_INCORRECTA";
		END IF;
    ELSE 
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "CORREO_NO_ENCONTRADO";
	END IF;
END $$
DELIMITER ;

-- ADMIN
-- CREAR SALA: datos de sala 
-- nota: se registra la insercion en auditoria
DELIMITER $$
CREATE PROCEDURE sp_crear_sala(
	IN x_tipo_sala VARCHAR(50),				-- 1
    IN x_nombre VARCHAR(50), 				-- 2
    IN x_precio_hora DECIMAL(10), 			-- 3
    IN x_hora_apertura TIME, 				-- 4
    IN x_hora_cierre TIME, 					-- 5
    IN x_descripcion TEXT, 					-- 6
    IN x_equipamiento JSON, 				-- 7 
    IN x_capacidad_minima INT UNSIGNED,		-- 8
    IN x_capacidad_maxima INT UNSIGNED,		-- 9
    IN x_id_admin INT						-- 10
)
BEGIN
    DECLARE x_id_insertion INT;
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
		ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    IF x_tipo_sala IS NULL OR x_tipo_sala = "" OR x_nombre IS NULL OR x_nombre = "" OR x_precio_hora IS NULL OR x_precio_hora = ""
    OR x_hora_apertura IS NULL OR x_hora_apertura = "" OR x_hora_cierre IS NULL OR x_hora_cierre = "" 
    OR x_descripcion IS NULL OR x_descripcion = "" OR x_equipamiento IS NULL OR x_equipamiento  = ""
    OR x_capacidad_minima IS NULL OR x_capacidad_minima = ""  OR x_capacidad_maxima IS NULL OR x_capacidad_maxima  = ""
    OR x_id_admin IS NULL OR x_id_admin = "" THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "FALTAN_CAMPOS";
    END IF;
    
    INSERT INTO sala(tipo_sala, nombre, precio_hora, hora_apertura, hora_cierre, descripcion, 
					equipamiento, capacidad_minima, capacidad_maxima) 
			VALUES(x_tipo_sala, x_nombre, x_precio_hora, x_hora_apertura, x_hora_cierre, x_descripcion, 
					x_equipamiento, x_capacidad_minima, x_capacidad_maxima);
                    
	SET x_id_insertion = LAST_INSERT_ID();
    
    INSERT INTO auditoria(tabla, id_campo_actualizado, tipo_movimiento, id_usuario)
			VALUES("sala", x_id_insertion, "insercion", x_id_admin);
	COMMIT;
END $$
DELIMITER ;

-- ADMIN
-- EDITAR SALA: datos de edicion de la sala
-- nota: se registra la edicion en auditoria
DELIMITER $$
CREATE PROCEDURE sp_editar_sala(
	IN x_id_sala INT,						-- 1
	IN x_tipo_sala VARCHAR(50),				-- 2
    IN x_nombre VARCHAR(50), 				-- 3
    IN x_precio_hora DECIMAL(10), 			-- 4
    IN x_hora_apertura TIME, 				-- 5
    IN x_hora_cierre TIME, 					-- 6
    IN x_descripcion TEXT, 					-- 7
    IN x_equipamiento JSON, 				-- 8 
    IN x_capacidad_minima INT UNSIGNED,		-- 9
    IN x_capacidad_maxima INT UNSIGNED,		-- 10
    IN x_id_admin INT						-- 11
)
BEGIN
    DECLARE x_json_auditoria JSON DEFAULT JSON_OBJECT();
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		ROLLBACK;
        RESIGNAL;
	END;
    
    START TRANSACTION;
	UPDATE sala SET 
		tipo_sala = COALESCE(x_tipo_sala, tipo_sala), 
        nombre = COALESCE(x_nombre, nombre), 
        precio_hora = COALESCE(x_precio_hora, precio_hora), 
        hora_apertura = COALESCE(x_hora_apertura, hora_apertua), 
        hora_cierre = COALESCE(x_hora_cierre, hora_cierre), 
        descripcion = COALESCE(x_descripcion, descripcion), 
        equipamiento = COALESCE(x_equipamiento, equipamiento), 
        capacidad_minima = COALESCE(x_capacida_minima, capacidad_minima), 
        capacidad_maxima = COALESCE(x_capacidad_maxima, capacidad_maxima)
	WHERE id_sala = x_id_sala;
    
    IF x_tipo_sala IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.tipo_sala", x_tipo_sala);
    END IF;
    IF x_nombre IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.nombre", x_nombre);
    END IF;
    IF x_precio_hora IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.precio_hora", x_precio_hora);
    END IF;
    IF x_hora_apertura IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.hora_apertura", x_hora_apertura);
    END IF;
    IF x_hora_cierre IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.hora_cierre", x_hora_cierre);
    END IF;
    IF x_descripcion IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.descripcion", x_descripcion);
    END IF;
    IF x_equipamiento IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.equipamiento", x_equipamiento);
    END IF;
    IF x_capacidad_minima IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.capacidad_minia", x_capacidad_minima);
    END IF;
    IF x_capacidad_maxima IS NOT NULL THEN
		SET x_json_auditoria = JSON_SET(x_json_auditoria, "$.capacidad_maxima", x_capacidad_maxima);
    END IF;
    
    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
				VALUES("sala", x_json_auditoria, x_id_sala, "actualizacion", x_id_admin);
    COMMIT;
END $$
DELIMITER ;

-- ADMIN
-- DESACTIVAR SALA: 
-- nota: se registra en auditoria
DELIMITER $$
CREATE PROCEDURE sp_desactivar_sala(
	IN x_id_sala INT,	-- 1
    IN x_id_admin INT	-- 2
)
BEGIN
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
		ROLLBACK;
        RESIGNAL;
	END;
	
    START TRANSACTION;
    IF (SELECT COUNT(id_sala) FROM reserva WHERE id_sala = x_id_sala) <> 0 THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "SALA_RESERVADA";
    END IF;
    
	UPDATE sala SET estado = "INACTIVA" WHERE id_sala = x_id_sala;
    
    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario) 
				VALUES("sala", '{"estado":"INACTIVA"}', x_id_sala, "actualizacion", x_id_admin);
	COMMIT;
END $$
DELIMITER ;

-- ADMIN
-- ACTIVAR SALA
-- nota: se registra en auditoria
DELIMITER $$
CREATE PROCEDURE sp_activar_sala(
	IN x_id_sala INT,	-- 1
    IN x_id_admin INT	-- 2
)
BEGIN
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
		ROLLBACK;
        RESIGNAL;
	END;
	
    START TRANSACTION;
	UPDATE sala SET estado = "ACTIVA" WHERE id_sala = x_id_sala;
    
    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario) 
				VALUES("sala", '{"estado":"ACTIVA"}', x_id_sala, "actualizacion", x_id_admin);
	COMMIT;
END $$
DELIMITER ;

-- ADMIN
-- BLOQUEAR SALA: id sala y admin, fechas de inicio y fin, y motivo
-- nota: se registra en auditoria
-- nota: requiere evento de desbloqueo
DELIMITER $$
CREATE PROCEDURE sp_bloquear_sala(
	IN x_id_sala INT,				-- 1
    IN x_id_admin INT,				-- 2
    IN x_fecha_inicio DATETIME,		-- 3
    IN x_fecha_fin DATETIME, 		-- 4
    IN x_motivo TEXT,				-- 5
    OUT x_cant_reservas_dentro INT	-- 6
)
BEGIN
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
		ROLLBACK;
        RESIGNAL;
	END;
	
    START TRANSACTION;
    IF (SELECT COUNT(id_reserva) FROM reserva WHERE id_sala = x_id_sala AND (inicio >= x_fecha_inicio AND fin <= x_fecha_fin)) > 0 THEN 
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "SE_INTERPONEN_RESERVAS";
    END IF;
    
	UPDATE sala SET estado = "BLOQUEADA" WHERE id_sala = x_id_sala;
    
    INSERT INTO bloqueo(fecha_inicio, fecha_fin, motivo, id_admi, id_sala) 
				VALUES(x_fecha_inicio, x_fecha_fin, x_motivo, x_id_admin, x_id_sala);
    
    INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario) 
				VALUES("sala", '{"estado":"INACTIVA"}', x_id_sala, "actualizacion", x_id_admin);
                
	INSERT INTO auditoria(tabla, id_campo_actualizado, tipo_movimiento, id_usuario) 
				VALUES("bloqueo", x_id_sala, "insercion", x_id_admin);
	COMMIT;
END $$
DELIMITER ;

-- Cliente
-- Reserva: fechas inicio y fin, fecha creacion, id sala y cliente
-- nota: requiere un evento para expirar las reservas expiradas
DELIMITER $$
CREATE PROCEDURE sp_reservar(
    IN x_fecha_inicio DATETIME,
    IN x_fecha_fin    DATETIME,
    IN x_id_cliente   INT,
    IN x_id_sala      INT
)
BEGIN
    DECLARE x_ahora DATETIME DEFAULT NOW();
    DECLARE x_precio_hora DECIMAL(10,2);
    DECLARE x_total DECIMAL(10,2);
    DECLARE x_fecha_expiracion DATETIME;
    DECLARE x_fecha_expiracion_limite DATETIME DEFAULT NOW() + INTERVAL 1 DAY;
    DECLARE x_codigo INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF x_fecha_inicio IS NULL OR x_fecha_fin IS NULL
       OR x_id_cliente IS NULL OR x_id_sala IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FALTAN_CAMPOS';
    END IF;

    IF x_fecha_fin <= x_fecha_inicio THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RANGO_FECHAS_INVALIDO';
    END IF;

    IF x_fecha_inicio < x_ahora THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FECHA_EN_EL_PASADO';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM usuario WHERE id_usuario = x_id_cliente) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'USUARIO_INEXISTENTE';
    END IF;

    START TRANSACTION;

    -- Bloquea la sala: valida existencia, obtiene precio y serializa reservas concurrentes
    SELECT precio_hora INTO x_precio_hora
    FROM sala WHERE id_sala = x_id_sala FOR UPDATE;

    IF x_precio_hora IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SALA_INEXISTENTE';
    END IF;

    SET x_total = x_precio_hora * TIMESTAMPDIFF(MINUTE, x_fecha_inicio, x_fecha_fin) / 60;

    -- Traslape (ignora PENDIENTE ya expiradas)
    IF EXISTS (
        SELECT 1 FROM reserva
        WHERE id_sala = x_id_sala
          AND (estado = 'PAGADO'
               OR (estado = 'PENDIENTE' AND fecha_expiracion > x_ahora))
          AND x_fecha_inicio < fin
          AND x_fecha_fin > inicio
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RESERVA_SOBREPUESTA';
    END IF;

    -- Fecha de expiración
    IF x_fecha_inicio < x_ahora + INTERVAL 30 MINUTE THEN
        SET x_fecha_expiracion = x_ahora + INTERVAL 15 MINUTE;
    ELSE
        SET x_fecha_expiracion = LEAST(x_fecha_inicio - INTERVAL 15 MINUTE,
                                       x_fecha_expiracion_limite);
    END IF;

    SET x_codigo = FLOOR(10000 + RAND() * 90000);

    INSERT INTO reserva(inicio, fin, estado, total, fecha_creacion, codigo,
                        fecha_expiracion, id_cliente, id_sala)
    VALUES(x_fecha_inicio, x_fecha_fin, 'PENDIENTE', x_total, x_ahora, x_codigo,
           x_fecha_expiracion, x_id_cliente, x_id_sala);

    COMMIT;
END $$
DELIMITER ;

-- ADMIN
DELIMITER $$
CREATE PROCEDURE sp_activar_desactivar_cliente(
	IN x_id_cliente INT,
    IN x_id_admin INT
)
BEGIN
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN 
		ROLLBACK;
        RESIGNAL;
	END;
	
    START TRANSACTION;
	IF (SELECT COUNT(id_usuario) FROM usuario WHERE id_usuario = x_id_cliente) = 0 THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "CLIENTE_NO_ENCONTRADO";
	ELSEIF (SELECT COUNT(id_usuario) FROM usuario WHERE id_usuario = x_id_admin) = 0 THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "ADMIN_NO_ENCONTRADO";
	ELSE
		IF (SELECT estado FROM usuario WHERE id_usuario = x_id_cliente) = "ACTIVO" THEN
			UPDATE usuario SET estado = "BLOQUEADO" WHERE id_usuario = x_id_cliente;
			INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
			VALUES("usuario", JSON_OBJECT("estado", "BOQUEADO"), x_id_cliente, "Actualizacion", x_id_admin);
		ELSEIF (SELECT estado FROM usuario WHERE id_usuario = x_id_cliente) = "BLOQUEADO" THEN
			UPDATE usuario SET estado = "ACTIVO" WHERE id_usuario = x_id_cliente;
			INSERT INTO auditoria(tabla, actualizacion, id_campo_actualizado, tipo_movimiento, id_usuario)
			VALUES("usuario", JSON_OBJECT("estado", "ACTIVO"), x_id_cliente, "Actualizacion", x_id_admin);
		ELSE
			SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "USUARIO_INACTIVO";
        END IF;
    END IF;
    COMMIT;
END $$
DELIMITER ;

-- CLIENTE
-- PAGO
DELIMITER $$
CREATE PROCEDURE sp_pagar(
	IN x_monto DECIMAL(10,0), 		-- 1
    IN x_metodo_pago VARCHAR(15), 	-- 2
    IN x_referencia VARCHAR(17),	-- 3
    IN x_id_reserva INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		ROLLBACK;
        RESIGNAL;
	END;
    
    START TRANSACTION;
    IF (SELECT COUNT(id_reserva) FROM reserva WHERE id_reserva = x_id_reserva) = 0 THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "RESERVA_NO_ENCONTRADA";
	ELSEIF (SELECT estado FROM reserva WHERE id_reserva = x_id_reserva) = "EXPIRADO" THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "RESERVA_EXPIRADA";
	ELSEIF (SELECT total FROM reserva WHERE id_reserva = x_id_reserva) <> x_monto THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "MONTO_A_PAGAR_Y_TOTAL_NO_CONVERGEN";
    END IF;
    
    INSERT INTO pago(monto, metodo_pago, estado, referencia, fecha_pago, id_reserva)
				VALUES(x_monto, x_metodo_pago, "PAGADO", x_referencia, NOW(), x_id_reserva);
    
    UPDATE reserva SET estado = "PAGADO" WHERE id_reserva = x_id_reserva;
    COMMIT;
END $$
DELIMITER ;

