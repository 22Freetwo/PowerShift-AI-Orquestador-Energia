-- =====================================================================
-- Consultas de PowerShift AI. La telemetría y las tarifas NO tienen llave
-- foránea entre sí: se cruzan aquí, por hora del día y por nodo (pasando
-- por vivienda, donde vive clv_nodo).
-- =====================================================================

-- Q1. Join temporal: costo diario sin orquestador de las cargas controlables
--     (bomba de calor + EV).  costo = kW x 0.25 h x PML / 1000   (lecturas de 15 min)
SELECT t.id_vivienda,
       (t.ts AT TIME ZONE v.zona_horaria)::date                         AS fecha_local,
       ROUND(SUM((t.heat_pump_kw + t.ev_kw) * 0.25 * p.pml / 1000.0), 4) AS costo_sin_orquestador_mxn
FROM telemetria_consumo t
JOIN vivienda      v ON v.id_vivienda = t.id_vivienda
JOIN v_perfil_pml  p ON p.clv_nodo = v.clv_nodo
                    AND p.mercado  = 'MDA'
                    AND p.hora     = EXTRACT(HOUR FROM (t.ts AT TIME ZONE v.zona_horaria))::int + 1
GROUP BY t.id_vivienda, fecha_local
ORDER BY fecha_local
LIMIT 10;

-- Q2. Ahorro diario simulado: costo sin orquestador contra costo con el horario
--     que dejó el optimizador en "programacion" (la bomba de calor no se mueve).
WITH tele AS (
    SELECT t.id_vivienda,
           (t.ts AT TIME ZONE v.zona_horaria)::date AS fecha_local,
           SUM(t.heat_pump_kw * 0.25 * p.pml / 1000.0) AS costo_hp,
           SUM(t.ev_kw        * 0.25 * p.pml / 1000.0) AS costo_ev_sin
    FROM telemetria_consumo t
    JOIN vivienda     v ON v.id_vivienda = t.id_vivienda
    JOIN v_perfil_pml p ON p.clv_nodo = v.clv_nodo AND p.mercado = 'MDA'
                       AND p.hora = EXTRACT(HOUR FROM (t.ts AT TIME ZONE v.zona_horaria))::int + 1
    GROUP BY t.id_vivienda, fecha_local
), prog AS (
    SELECT d.id_vivienda,
           (pr.inicio_programado AT TIME ZONE v.zona_horaria)::date AS fecha_local,
           SUM(pr.costo_estimado) AS costo_ev_con
    FROM programacion pr
    JOIN dispositivo d ON d.id_dispositivo = pr.id_dispositivo
    JOIN vivienda    v ON v.id_vivienda    = d.id_vivienda
    WHERE d.tipo_carga = 'EV'
    GROUP BY d.id_vivienda, fecha_local
)
SELECT tele.fecha_local,
       ROUND(tele.costo_hp + tele.costo_ev_sin, 4) AS costo_sin,
       ROUND(tele.costo_hp + prog.costo_ev_con, 4) AS costo_con,
       ROUND(tele.costo_ev_sin - prog.costo_ev_con, 4) AS ahorro
FROM tele
JOIN prog USING (id_vivienda, fecha_local)
ORDER BY tele.fecha_local;

-- Q3. Relación N:M: a qué horas programó el optimizador cada tipo de equipo
--     y a qué PML. (programacion funciona como tabla intermedia.)
SELECT d.tipo_carga,
       EXTRACT(HOUR FROM (pr.inicio_programado AT TIME ZONE v.zona_horaria))::int AS hora_local,
       COUNT(*)                         AS n_programaciones,
       ROUND(SUM(pr.energia_kwh), 2)    AS kwh,
       ROUND(AVG(p.pml), 2)             AS pml_mxn_mwh
FROM programacion pr
JOIN dispositivo  d ON d.id_dispositivo = pr.id_dispositivo
JOIN vivienda     v ON v.id_vivienda    = d.id_vivienda
JOIN v_perfil_pml p ON p.clv_nodo = v.clv_nodo AND p.mercado = 'MDA'
                   AND p.hora = EXTRACT(HOUR FROM (pr.inicio_programado AT TIME ZONE v.zona_horaria))::int + 1
GROUP BY d.tipo_carga, hora_local
ORDER BY d.tipo_carga, hora_local;
