DROP DATABASE IF EXISTS db_spacebook;

CREATE TABLE usuario AS
    id_usuario INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(20) NOT NULL,
    correo VARCHAR(50) NOT NULL UNIQUE,
    hash_pwd VARCHAR(255) NOT NULL,
    rol ENUM("ADMIN","CLIENTE") NOT NULL DEFAULT "CLIENTE",
    estado ENUM("ACTIVO", "INACTIVO", "BLOQUEADO") NOT NULL DEFAULT "ACTIVO",
    fecha_registro TIMESTAMP NOT NULL DEFUALT CURRENT_TIMESTAMP,
    intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0
;

CREATE TABLE sala AS 
    id_sala INT PRIMARY KEY AUTO_INCREMENT,
    tipo_sala VARCHAR(50) NOT NULL,
    estado ENUM("ACTIVA","INACTIVA","BLOQUEADA") NOT NULL DEFAULT "ACTIVA",
    nombre VARCHAR(50) NOT NULL,
    precio_hora DECIMAL NOT NULL,
    hora_apertura DATETIME NOT NULL,
    hora_cierre DATETIME NOT NULL,
    descripcion TEXT,
    equipamiento JSON NOT NULL,
    capacidad_minima INT UNSIGNED NOT NULL,
    capacidad_maxima INT UNSIGNED NOT NULL
;

CREATE TABLE reserva AS
    id_reserva INT PRIMARY KEY AUTO_INCREMENT,
    inicio DATETIME,
    fin DATETIME,
    estado ENUM("PENDIENTE", "PAGADO", "CANCELADO", "EXPIRADO", "COMPLETADO"),
    total DECIMAL,
    fecha_creacion DATETIME,
    codigo TINYINT UNSIGNED, -- Codigo de barras
    fecha_expiracion DATETIME,
    fecha_cancelacion DATETIME,
    motivo_cancelacion TEXT
    id_cliente INT NOT NULL,
    id_sala INT NOT NULL,
    CONSTRAINT id_cliente_reserva FOREIGN KEY (id_cliente) REFERENCES usuario(id_usuario),
    CONSTRAINT id_sala_reserva FOREIGN KEY (id_sala) REFERENCES sala(id_sala)
;

CREATE TABLE pago AS
    id_pago INT PRIMARY KEY AUTO_INCREMENT,
    monto DECIMAL,
    metodo_pago ENUM("EFECTIVO","DIGITAL"),
    estado ENUM("PENDIENTE", "PAGADO", "CANCELADO","REEMBOLSADO"),
    referencia INT UNSIGNED,
    fecha_pago DATETIME,
    monto_reembolsado DECIMAL,
    fecha_reembolso DATETIME
    id_reserva INT NOT NULL,
    CONSTRAINT id_reserva_pago FOREIGN KEY (id_reserva) REFERENCES reserva(id_reserva)
;

CREATE TABLE resenia AS
    id_resenia INT PRIMARY KEY AUTO_INCREMENT,
    calificacion TINYINT NOT NULL,
    comentario TEXT,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    id_reserva INT NOT NULL,
    id_sala INT NOT NULL,
    CONSTRAINT id_reserva_resenia FOREIGN KEY (id_reserva) REFERENCES reserva(id_reserva),
    CONSTRAINT id_sala_resenia FOREIGN KEY (id_sala) REFERENCES sala(id_sala)
;

CREATE TABLE auditoria AS
    id_adutoria INT PRIMARY KEY AUTO_INCREMENT,
    fecha_auditoria TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tabla VARCHAR(20) NOT NULL,
    actualizacion JSON NOT NULL,
    id_campo_actualizado INT NOT NULL,
    tipo_movimiento VARCHAR(20)
    id_usuario INT NOT NULL,
    CONSTRAINT id_usuario_auditoria FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario)
;

CREATE TABLE bloqueo AS
    id_bloqueo INT PRIMARY KEY AUTO_INCREMENT,
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    motivo TEXT,
    id_admin INT NOT NULL,
    CONSTRAINT id_admin_bloqueo FOREIGN KEY (id_admin) REFERENCES usuario(id_usuario)
;

