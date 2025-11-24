# Atlas: Snowflake-Native MLOps Platform

Atlas is an opinionated, Snowflake-native MLOps platform that demonstrates how to run **feature stores, model registries, prediction logging, drift monitoring, and automated retraining _entirely inside Snowflake_.**

This repo backs the Medium article:

> **“Atlas: How I Built a Full-Stack Snowflake MLOps Platform (Feature Store, Model Registry, Drift & Retraining in Snowflake)”**
> https://medium.com/@mattsreinsch/atlas-how-i-built-a-full-stack-snowflake-mlops-platform-9e5509ad8c79
> 
> by Matt Reinsch

---

## 🔭 What Atlas Shows

Atlas is designed to look and feel like the core of an enterprise ML platform:

- 🧱 **Feature Store** – curated, time-stamped feature tables in `ATLAS_FEATURE_STORE`
- 📚 **Model Registry** – versioned models with metrics and lineage in `ATLAS_MODEL_REGISTRY`
- 📓 **Prediction Log** – every production score captured in `ATLAS_MONITORING.PREDICTION_LOG`
- 📉 **Drift Engine** – SQL + views to monitor model behavior over time
- 🤖 **Cortex-Assisted Analysis** – optional use of Snowflake Cortex to explain drift
- 🔁 **Automated Retraining Hooks** – stored procedure + task that can trigger retraining pipelines

Everything runs using **standard Snowflake SQL + Snowpark** so teams can adapt the pattern to their own stack.

---

## 🧩 High-Level Architecture

```text
                   ┌──────────────────────────┐
                   │  RAW EVENTS / PIPELINES  │
                   └──────────────┬───────────┘
                                  ▼
                     ┌────────────────────────┐
                     │      FEATURE STORE     │
                     │  CUSTOMER_TX_FEATURES  │
                     └──────────────┬─────────┘
                                    ▼
                     ┌────────────────────────┐
                     │     MODEL REGISTRY     │
                     │     MODEL_REGISTRY     │
                     └──────────────┬─────────┘
                                    ▼
                     ┌────────────────────────┐
                     │    PREDICTION LOG      │
                     │    PREDICTION_LOG      │
                     └──────────────┬─────────┘
                                    ▼
                     ┌────────────────────────┐
                     │      DRIFT ENGINE      │
                     │      DRIFT_VIEW        │
                     └──────────────┬─────────┘
                                    ▼
                     ┌────────────────────────┐
                     │  RETRAINING TRIGGER    │
                     │  PROC + TASK LOGIC     │
                     └────────────────────────┘
```

---

## 📂 Repository Layout

```text
atlas-mlops-snowflake/
├── notebooks/
│   └── atlas_ml_platform.ipynb    # Main Snowflake Notebook demo
├── sql/
│   ├── 01_init_atlas_platform.sql # DB + schemas
│   ├── 02_feature_store.sql       # Feature store table + sample data
│   ├── 03_model_registry.sql      # Model registry table + sample entry
│   ├── 04_prediction_log.sql      # Prediction log table + sample rows
│   ├── 05_drift_engine.sql        # Drift view and example query
│   └── 06_retraining_orchestration.sql  # Stored proc + task skeleton
└── README.md
```

- The **notebook** is the easiest way to run the end‑to‑end demo.
- The **SQL files** let you stand up or modify individual components.

---

## 🚀 Getting Started (Snowflake)

> You can either run everything from the notebook or apply the SQL files one by one.

### 1️⃣ Create the Atlas Database and Schemas

Run `sql/01_init_atlas_platform.sql` in a Snowflake worksheet, or execute:

```sql
CREATE DATABASE IF NOT EXISTS ATLAS_PLATFORM_DB;

USE DATABASE ATLAS_PLATFORM_DB;

CREATE SCHEMA IF NOT EXISTS ATLAS_FEATURE_STORE;
CREATE SCHEMA IF NOT EXISTS ATLAS_MODEL_REGISTRY;
CREATE SCHEMA IF NOT EXISTS ATLAS_MONITORING;
```

You should now see `ATLAS_PLATFORM_DB` with three schemas.

---

### 2️⃣ Create the Feature Store Table

Run `sql/02_feature_store.sql`, or use:

```sql
USE DATABASE ATLAS_PLATFORM_DB;
USE SCHEMA ATLAS_FEATURE_STORE;

CREATE OR REPLACE TABLE CUSTOMER_TX_FEATURES (
    CUSTOMER_ID         STRING,
    AS_OF_DATE          DATE,
    TX_30D_COUNT        NUMBER,
    TX_30D_AMOUNT       NUMBER(18,2),
    TX_30D_AVG_TICKET   NUMBER(18,2)
);

INSERT INTO CUSTOMER_TX_FEATURES
  (CUSTOMER_ID, AS_OF_DATE, TX_30D_COUNT, TX_30D_AMOUNT, TX_30D_AVG_TICKET)
VALUES
  ('CUST_001', CURRENT_DATE(), 12, 1200.00, 100.00),
  ('CUST_002', CURRENT_DATE(),  5,  250.00,  50.00),
  ('CUST_003', CURRENT_DATE(), 30, 6000.00, 200.00);

SELECT * FROM CUSTOMER_TX_FEATURES;
```

This becomes the **Customer Transaction Feature Table** for downstream models.

---

### 3️⃣ Create the Model Registry

Run `sql/03_model_registry.sql`, or:

```sql
USE DATABASE ATLAS_PLATFORM_DB;
USE SCHEMA ATLAS_MODEL_REGISTRY;

CREATE OR REPLACE TABLE MODEL_REGISTRY (
    MODEL_NAME         STRING,
    MODEL_VERSION      STRING,
    STAGE              STRING,
    FRAMEWORK          STRING,
    TRAINING_DATA_REF  STRING,
    METRICS            VARIANT,
    CREATED_AT         TIMESTAMP_NTZ,
    CREATED_BY         STRING
);

INSERT INTO MODEL_REGISTRY (
  MODEL_NAME, MODEL_VERSION, STAGE, FRAMEWORK,
  TRAINING_DATA_REF, METRICS, CREATED_AT, CREATED_BY
)
SELECT
  'fraud_detection_model',
  'v1',
  'PROD',
  'xgboost',
  'ATLAS_FEATURE_STORE.CUSTOMER_TX_FEATURES:2025-11-01',
  OBJECT_CONSTRUCT('auc', 0.94, 'f1', 0.88),
  CURRENT_TIMESTAMP(),
  'matt.reinsch';
```

Now you have a simple **Snowflake-native model registry**.

---

### 4️⃣ Create the Prediction Log

Run `sql/04_prediction_log.sql`, or:

```sql
USE DATABASE ATLAS_PLATFORM_DB;
USE SCHEMA ATLAS_MONITORING;

CREATE OR REPLACE TABLE PREDICTION_LOG (
    EVENT_TIME   TIMESTAMP_NTZ,
    MODEL_NAME   STRING,
    MODEL_VERSION STRING,
    ENTITY_ID    STRING,
    SCORE        FLOAT,
    LABEL        FLOAT,
    BATCH_ID     STRING
);

INSERT INTO PREDICTION_LOG (EVENT_TIME, MODEL_NAME, MODEL_VERSION, ENTITY_ID, SCORE, LABEL, BATCH_ID)
VALUES
  (DATEADD('day', -1, CURRENT_TIMESTAMP()), 'fraud_detection_model', 'v1', 'CUST_001', 0.91, 1.0, 'batch_1'),
  (DATEADD('day', -1, CURRENT_TIMESTAMP()), 'fraud_detection_model', 'v1', 'CUST_002', 0.20, 0.0, 'batch_1'),
  (DATEADD('day', -10, CURRENT_TIMESTAMP()), 'fraud_detection_model', 'v1', 'CUST_003', 0.45, 0.0, 'batch_2'),
  (DATEADD('day', -15, CURRENT_TIMESTAMP()), 'fraud_detection_model', 'v1', 'CUST_004', 0.35, 0.0, 'batch_2');

SELECT * FROM PREDICTION_LOG;
```

This is your **observability layer** for drift and audit.

---

### 5️⃣ Drift View & Monitoring Query

Run `sql/05_drift_engine.sql`, or create the view directly:

```sql
USE DATABASE ATLAS_PLATFORM_DB;
USE SCHEMA ATLAS_MONITORING;

CREATE OR REPLACE VIEW DRIFT_VIEW AS
WITH recent AS (
    SELECT AVG(SCORE) AS recent_avg_score
    FROM PREDICTION_LOG
    WHERE EVENT_TIME >= DATEADD('day', -7, CURRENT_TIMESTAMP())
),
baseline AS (
    SELECT AVG(SCORE) AS baseline_avg_score
    FROM PREDICTION_LOG
    WHERE EVENT_TIME < DATEADD('day', -7, CURRENT_TIMESTAMP())
)
SELECT
    recent.recent_avg_score   AS RECENT_AVG_SCORE,
    baseline.baseline_avg_score AS BASELINE_AVG_SCORE,
    (recent.recent_avg_score - baseline.baseline_avg_score) AS SCORE_DELTA
FROM recent, baseline;

SELECT * FROM DRIFT_VIEW;
```

You now have a **drift delta** for the model in a single query.

---

### 6️⃣ Retraining Orchestration Skeleton

Run `sql/06_retraining_orchestration.sql`, or adapt the example:

```sql
USE DATABASE ATLAS_PLATFORM_DB;
USE SCHEMA ATLAS_MONITORING;

CREATE OR REPLACE PROCEDURE ATLAS_TRIGGER_RETRAIN()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    v_drift FLOAT;
BEGIN
    SELECT SCORE_DELTA INTO :v_drift
    FROM DRIFT_VIEW;

    IF (v_drift > 0.15) THEN
        -- TODO: integrate with external training pipeline
        -- e.g. call an external function, Snowpark Container, or orchestration tool
        RETURN 'Drift detected – retraining should be triggered.';
    ELSE
        RETURN 'No drift – model baseline stable.';
    END IF;
END;
$$;

CREATE OR REPLACE TASK ATLAS_DRIFT_TASK
WAREHOUSE = COMPUTE_WH
SCHEDULE = '1 HOUR'
AS
CALL ATLAS_TRIGGER_RETRAIN();
```

This creates a **control plane** for automated retraining. In a real stack you would wire `ATLAS_TRIGGER_RETRAIN` into your external training system.

---

## 📒 Notebook Demo

The notebook at:

```text
notebooks/atlas_ml_platform.ipynb
```

walks through the same flow end‑to‑end, including:

- Creating the schemas and tables
- Inserting sample records
- Running drift queries
- Showing output tables suitable for screenshots in blog posts or internal docs

Import the notebook into **Snowflake Notebooks**, attach a warehouse, and run top‑to‑bottom.

---

## 🧠 Extending Atlas

Some ideas for taking this pattern further:

- Add additional feature tables (behavioral, credit, device, etc.)
- Track **per‑segment drift** (by region, product, channel)
- Store **explanation metadata** (SHAP, feature importances) alongside predictions
- Integrate with **Cortex** for automated drift commentary
- Replace the retraining stub with a real pipeline call (Airflow, dbt, Dagster, container services)
- Add dashboards in Sigma/Streamlit/Streamlit-in-Snowflake for platform reporting

---

## 👤 Author

**Matt Reinsch**  
AI & MLOps Leader | Creator of *Data Drift*  

- 🌐 Website: https://mattreinsch.com  
- 🔗 LinkedIn: https://www.linkedin.com/in/mattreinsch  
- 📰 Newsletter: https://mattreinsch.github.io/DataDrift  
- ✍️ Medium: https://medium.com/@mattsreinsch  

If you use or extend this repo, feel free to tag me — I’d love to see what you build on top of it.
