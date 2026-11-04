# PowerShift AI: Orquestador Invisible de Energía y Costos

![Python](https://img.shields.io/badge/Python-3.10%2B-blue) ![Uso](https://img.shields.io/badge/Uso-Acad%C3%A9mico-green) ![Instituci%C3%B3n](https://img.shields.io/badge/UdeG-CUGDL-red)

Proyecto Integrador del tercer semestre de la Licenciatura en Inteligencia Artificial y Ciencia de Datos, Centro Universitario de Guadalajara (CUGDL), Universidad de Guadalajara.

**PowerShift AI** es un orquestador de energía pensado para un dispositivo Edge (Raspberry Pi) que mueve cargas pesadas del hogar a las horas de menor Precio Marginal Local (PML). Este repositorio contiene el **prototipo de datos y la simulación**: no hay hardware instalado, así que el broker MQTT, los medidores y los interruptores IoT son solo diseño, y los ahorros son resultados de simulación.

Materias que cubre: Machine Learning e Inferencia Bayesiana, Matemáticas Aplicadas a la Ciencia de Datos, Probabilidad y Estadística II y Bases de Datos.

## Integrantes

- Gabriel Orozco Alvárez
- Yohann Emmanuel Bustos Peñaloza
- Angel Zoe García Granados
- Juan Pablo Arroyo León

## Datos

| Fuente | Qué se usa | Dónde |
|---|---|---|
| [Open Power System Data, Household Data (v2020-04-15)](https://data.open-power-system-data.org/household_data/2020-04-15/) | Vivienda `DE_KN_residential4` (Konstanz, Alemania): `grid_import`, `grid_export`, `pv`, `heat_pump`, `ev`. Lecturas acumuladas de medidor (kWh) cada 15 min | **No se incluye** (58 MB). Descargar `household_data_15min_singleindex.csv` y ponerlo en `codigo/` |
| [CENACE, SIM](https://www.cenace.gob.mx/) | PML del Mercado del Día en Adelanto, promedios horarios por sistema (SIN, BCA, BCS), **un solo día** (22 oct 2026) | `codigo/PMLHorarioMDA.csv` |

Pecan Street Dataport se consideró al inicio y se descartó por falta de acceso.

Tras la limpieza quedan **506 días completos** (14 oct 2015 a 5 mar 2017), 12,144 horas y 48,576 lecturas de 15 min. Se descartaron 5 días: 3 por cambio de horario y 2 parciales en los extremos de la ventana.

## Estructura

```
.
├── README.md
├── requirements.txt
├── .gitignore
├── codigo/
│   ├── 00_ingesta_limpieza.ipynb
│   ├── 01_bases_de_datos.ipynb
│   ├── 02_ml_clasificacion_ev.ipynb
│   ├── 04_optimizador_lp.ipynb
│   ├── 06_inferencia_estadistica.ipynb
│   ├── esquema_powershift.sql
│   ├── consultas_powershift.sql
│   ├── PMLHorarioMDA.csv            (entrada)
│   └── ... CSV, JSON y figuras generados por los notebooks
└── reportes/
    ├── machine_learning_matematicas/
    ├── estadistica/
    └── bases_de_datos/
```

La numeración de los notebooks sigue el plan original del proyecto; los números 03 y 05 no se utilizaron.

## Cómo reproducirlo

Requiere Python 3.10 o superior: `pip install -r requirements.txt`. Los notebooks leen y escriben archivos en su misma carpeta (`codigo/`). Se pueden correr en Jupyter o en Google Colab (*Reiniciar y ejecutar todo*).

| Orden | Notebook | Lee | Genera |
|---|---|---|---|
| 1 | `00_ingesta_limpieza` | `household_data_15min_singleindex.csv`, `PMLHorarioMDA.csv` | `datos_horarios.csv`, `pml_perfil.csv`, `telemetria_15min.csv` |
| 2 | `04_optimizador_lp` | `datos_horarios.csv`, `pml_perfil.csv` | `costos_diarios.csv`, `programacion.csv`, `costos_ventana_aprendida.csv`, `resultados_optimizador.json` |
| 3 | `02_ml_clasificacion_ev` | `datos_horarios.csv` | `resultados_ml.json` y figuras |
| 4 | `06_inferencia_estadistica` | `datos_horarios.csv`, `costos_diarios.csv` | pruebas de hipótesis y figuras |
| 5 | `01_bases_de_datos` | `esquema_powershift.sql`, `telemetria_15min.csv`, `programacion.csv`, `costos_diarios.csv`, `PMLHorarioMDA.csv` | esquema y consultas en PostgreSQL con TimescaleDB |

El notebook 01 necesita una base PostgreSQL con TimescaleDB. La forma más simple es Docker:

```
docker run -d --name powershift-db -p 5432:5432 -e POSTGRES_PASSWORD=powershift timescale/timescaledb:latest-pg16
```

Las contraseñas del notebook son solo para esa instancia local de prueba.

## Resultados principales

Todas las cifras salen de los notebooks de este repositorio.

- **Machine Learning (notebook 02).** Clasificación de "el EV está cargando en esta hora" con información del día anterior, partición cronológica (prueba: 14 oct 2016 a 5 mar 2017). Modelo final: regresión logística, AUC 0.852, AP 0.377 (3.2 veces la tasa base), Brier 0.0872. Se compararon seis clasificadores; en la prueba quedan muy cerca. El 83 % de la energía del EV se carga entre las 10:00 y las 17:00 h.
- **Optimizador (notebook 04).** Programación lineal que reparte la carga del EV en las horas permitidas. Con la ventana fija de 18:00 a 08:00 h, el ahorro simulado es de 2.23 MXN por día (20.2 % del costo de EV y bomba de calor; 54.3 % del costo del EV) en 268 días. Con ventanas aprendidas del hábito, evaluadas en 83 días de prueba, el ahorro es prácticamente el mismo (53.8 % contra 53.5 % del costo del EV), con una cobertura de 94 a 98 % de la energía real dentro de la ventana, contra 4.4 % de la ventana nocturna.
- **Estadística (notebook 06).** Prueba t pareada del ahorro (t = 7.99, p = 4.1e-9), ANOVA de la bomba de calor por franja (p = 0.445) y bondad de ajuste χ² de la carga nocturna (se rechaza normalidad, p = 0.0058). Las funciones de densidad se programaron a mano, sin `scipy.stats`.
- **Bases de datos (notebook 01).** Modelo de seis tablas (`nodo`, `vivienda`, `telemetria_consumo`, `tarifa_pml`, `dispositivo`, `programacion`) con `telemetria_consumo` como hypertable de TimescaleDB, y un join temporal por hora y nodo entre telemetría y tarifas. Ver el reporte de Bases de Datos.

## Limitaciones

- Una sola vivienda alemana con precios de México: las cifras en pesos ilustran el método y no predicen una factura.
- El PML disponible es de **un solo día** por sistema (no hay precios por nodo ni serie histórica) y se aplica a todos los días.
- Los ahorros son **simulados**. El programa lineal supone que el auto está conectado y puede cargar en toda la ventana; OPSD no registra cuándo se conecta.
- Un cambio de nivel entre entrenamiento y prueba (el EV carga más en el invierno de prueba) y la calibración de las probabilidades no se evaluó con curva de confiabilidad.
- Sin hardware real: MQTT, Raspberry Pi e interruptores IoT son diseño.

## Uso de IA

El equipo usó Gemini y Claude como apoyo para estructurar textos, validar valores, resolver errores de código y decidir qué convenía hacer. El equipo revisó, ejecutó y comprobó los resultados.

## Referencias

Open Power System Data (2020), *Data package household data*; CENACE (2026), *Sistema de Información del Mercado (SIM)*; Pedregosa et al. (2011), *Scikit-learn*; McKinney (2010), *pandas*; documentación de PostgreSQL y TimescaleDB. La lista completa está en los reportes.
