-- =====================================================================
-- PowerShift AI · Esquema relacional en PostgreSQL + TimescaleDB
-- 6 tablas: nodo, vivienda, tarifa_pml, dispositivo, telemetria_consumo
-- (hypertable) y programacion.
-- Datos reales: OPSD Household Data (vivienda DE_KN_residential4) y
-- CENACE SIM (PML MDA, promedios horarios por sistema).
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Reinicio del esquema (permite volver a ejecutar el script)
DROP VIEW  IF EXISTS v_perfil_pml;
DROP TABLE IF EXISTS programacion        CASCADE;
DROP TABLE IF EXISTS telemetria_consumo  CASCADE;
DROP TABLE IF EXISTS dispositivo         CASCADE;
DROP TABLE IF EXISTS tarifa_pml          CASCADE;
DROP TABLE IF EXISTS vivienda            CASCADE;
DROP TABLE IF EXISTS nodo                CASCADE;

-- ---------------------------------------------------------------------
-- 1) nodo: punto de precio de la red. El archivo de CENACE usado trae el
--    PML promedio por SISTEMA (no por nodo), por eso en el prototipo cada
--    nodo representa el promedio de un sistema (SIN-PROM, BCA-PROM, ...).
--    "sistema" vive aquí y no en tarifa_pml para no repetirlo en cada precio.
-- ---------------------------------------------------------------------
CREATE TABLE nodo (
    clv_nodo     VARCHAR(20)  PRIMARY KEY,
    sistema      VARCHAR(3)   NOT NULL CHECK (sistema IN ('SIN', 'BCA', 'BCS')),
    descripcion  VARCHAR(120)
);

-- ---------------------------------------------------------------------
-- 2) vivienda: liga cada casa con su nodo de precio y su zona horaria.
--    id_vivienda toma el prefijo de las columnas de OPSD (DE_KN_residential4).
-- ---------------------------------------------------------------------
CREATE TABLE vivienda (
    id_vivienda   VARCHAR(30)  PRIMARY KEY,
    clv_nodo      VARCHAR(20)  NOT NULL REFERENCES nodo (clv_nodo),
    zona_horaria  VARCHAR(40)  NOT NULL DEFAULT 'Europe/Berlin',
    fuente        VARCHAR(60)
);

-- ---------------------------------------------------------------------
-- 3) tarifa_pml: PML por nodo, mercado, fecha y hora (1 a 24, como lo
--    entrega CENACE). Los componentes (energía, pérdidas, congestión) son
--    opcionales: el archivo usado solo trae el PML total.
-- ---------------------------------------------------------------------
CREATE TABLE tarifa_pml (
    clv_nodo  VARCHAR(20)   NOT NULL REFERENCES nodo (clv_nodo),
    mercado   VARCHAR(3)    NOT NULL CHECK (mercado IN ('MDA', 'MTR')),
    fecha     DATE          NOT NULL,
    hora      SMALLINT      NOT NULL CHECK (hora BETWEEN 1 AND 24),
    pml       NUMERIC(10,2) NOT NULL,          -- MXN/MWh
    pml_ene   NUMERIC(10,2),                   -- no disponible en el archivo usado
    pml_per   NUMERIC(10,2),
    pml_cng   NUMERIC(10,2),
    PRIMARY KEY (clv_nodo, mercado, fecha, hora)
);

-- ---------------------------------------------------------------------
-- 4) dispositivo: equipos controlables de la vivienda.
-- ---------------------------------------------------------------------
CREATE TABLE dispositivo (
    id_dispositivo  SERIAL       PRIMARY KEY,
    id_vivienda     VARCHAR(30)  NOT NULL REFERENCES vivienda (id_vivienda),
    tipo_carga      VARCHAR(20)  NOT NULL
                    CHECK (tipo_carga IN ('HVAC', 'HEAT_PUMP', 'EV', 'BOMBA', 'SERVIDOR')),
    columna_origen  VARCHAR(60),               -- columna de OPSD de la que sale su consumo
    desplazable     BOOLEAN      NOT NULL,     -- TRUE si el optimizador puede moverlo
    encendido       BOOLEAN      NOT NULL DEFAULT FALSE,
    UNIQUE (id_vivienda, tipo_carga)
);

-- ---------------------------------------------------------------------
-- 5) telemetria_consumo: serie de tiempo a 15 min (kW), ya limpia.
--    La llave primaria incluye la columna de tiempo (requisito de
--    TimescaleDB para la columna de partición).
-- ---------------------------------------------------------------------
CREATE TABLE telemetria_consumo (
    id_vivienda     VARCHAR(30)  NOT NULL REFERENCES vivienda (id_vivienda),
    ts              TIMESTAMPTZ  NOT NULL,     -- utc_timestamp de OPSD
    grid_import_kw  NUMERIC(8,4),
    grid_export_kw  NUMERIC(8,4),
    pv_kw           NUMERIC(8,4),
    heat_pump_kw    NUMERIC(8,4),
    ev_kw           NUMERIC(8,4),
    PRIMARY KEY (id_vivienda, ts)
);

-- Hypertable particionada por tiempo (chunks de 30 días)
SELECT create_hypertable('telemetria_consumo', 'ts',
                         chunk_time_interval => INTERVAL '30 days',
                         if_not_exists => TRUE);

-- Compresión por columnas: segmentada por vivienda y ordenada por tiempo
ALTER TABLE telemetria_consumo SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'id_vivienda',
    timescaledb.compress_orderby   = 'ts DESC'
);
SELECT add_compression_policy('telemetria_consumo', INTERVAL '90 days');

-- Retención. OJO: los datos de OPSD son de 2015-2017; una retención corta
-- borraría todo el histórico del prototipo. Por eso se usa 20 años. En una
-- instalación real (datos nuevos) se usaría un plazo corto, por ejemplo
-- 2 años de 15 min, conservando agregados por hora.
SELECT add_retention_policy('telemetria_consumo', INTERVAL '20 years');

-- ---------------------------------------------------------------------
-- 6) programacion: resultado del optimizador. Es la tabla intermedia de
--    la relación N:M entre dispositivos y horas de menor costo.
-- ---------------------------------------------------------------------
CREATE TABLE programacion (
    id_programacion    SERIAL        PRIMARY KEY,
    id_dispositivo     INTEGER       NOT NULL REFERENCES dispositivo (id_dispositivo),
    inicio_programado  TIMESTAMPTZ   NOT NULL,  -- inicio de la hora en que se carga
    energia_kwh        NUMERIC(8,4)  NOT NULL,
    costo_estimado     NUMERIC(10,4) NOT NULL,  -- MXN = kWh x PML / 1000
    prob_ocupacion     NUMERIC(4,3)  CHECK (prob_ocupacion BETWEEN 0 AND 1)  -- pendiente: modelo de ocupación
);
CREATE INDEX idx_programacion_disp_inicio ON programacion (id_dispositivo, inicio_programado);

-- ---------------------------------------------------------------------
-- Vista: perfil horario de PML (promedio por nodo, mercado y hora 1-24).
-- Con un solo día cargado equivale a ese día; con muchos días es el
-- perfil típico. Permite cruzar telemetría de años distintos al del PML.
-- ---------------------------------------------------------------------
CREATE VIEW v_perfil_pml AS
SELECT clv_nodo, mercado, hora, AVG(pml)::NUMERIC(10,2) AS pml
FROM tarifa_pml
GROUP BY clv_nodo, mercado, hora;
