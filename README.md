# PowerShift-AI-Orquestador-Energia
Orquestador inteligente de energía y costos - Proyecto Integrador CUGDL.
# PowerShift AI: Orquestador Invisible de Energía y Costos ⚡🤖

![Python](https://img.shields.io/badge/Python-3.10%2B-blue)
![License](https://img.shields.io/badge/Licencia-Acad%C3%A9mica-green)
![Institución](https://img.shields.io/badge/UdeG-CUGDL-red)

## 📌 Descripción del Proyecto
**PowerShift AI** es un sistema de orquestación inteligente de energía diseñado para operar en dispositivos Edge (como Raspberry Pi). Su objetivo principal es predecir la demanda energética residencial y la probabilidad de ocupación del hogar para reprogramar de forma transparente el funcionamiento de cargas pesadas (HVAC, cargadores de vehículos eléctricos, bombas de agua) hacia las franjas horarias con menores Precios Marginales Locales (PML) y menores emisiones de $\text{CO}_2$, sin comprometer el confort del usuario.

Este proyecto forma parte del **Proyecto Integrador** de las materias de **Machine Learning e Inferencia Bayesiana** y **Matemáticas Aplicadas a la Ciencia de Datos**.

---

## 👥 Integrantes del Equipo
* **Gabriel Orozco Alvárez**
* **Yohann Emmanuel Bustos Peñaloza**
* **Angel Zoe García Granados**
* **Juan Pablo Arroyo León**

**Institución:** Centro Universitario de Guadalajara (CUGDL) — Universidad de Guadalajara  
**Programa Académico:** Licenciatura en Inteligencia Artificial y Ciencia de Datos  

---

## 📊 Fuentes de Datos
El sistema integra y cruza dos fuentes de datos independientes mediante un *join* temporal por hora y nodo de red:

1. **Pecan Street Dataport (Residential Energy & Smart Meter Telemetry):** Telemetría de alta resolución ($1\text{ Hz} / 1\text{ min}$) con desglose de consumo por circuitos individuales y variables de temperatura interior y exterior.
2. **API CENACE SIM / OPSD (Precios Marginales Locales):** Tarifas dinámicas de energía ($\text{MXN/MWh}$) y factores de emisión de carbono ($\text{kgCO}_2\text{e/kWh}$) en los nodos del mercado eléctrico mexicano.

---

## 🛠️ Estructura del Repositorio

```text
.
├── README.md                   # Presentación principal del proyecto
├── Reporte_Final_PowerShift_AI.pdf # Reporte técnico académico en PDF
├── requirements.txt            # Dependencias del entorno de Python
├── data/                       # Muestras de los datasets utilizados
│   ├── raw/                    # Datos crudos de telemetría y tarifas
│   └── processed/              # Datos limpios y procesados
└── notebooks/                  # Cuadernos de Jupyter
    ├── 01_limpieza_y_eda.ipynb # Limpieza, interpolación y EDA
    ├── 02_modelado_ml.ipynb     # Modelos de regresión de demanda (Random Forest, SVR, etc.)
    └── 03_inferencia_bayesiana.ipynb # Clasificador bayesiano de probabilidad de ocupación
