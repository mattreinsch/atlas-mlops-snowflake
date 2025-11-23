-- 04_prediction_log.sql
-- Prediction log for observability and drift analysis

USE DATABASE ATLAS_PLATFORM_DB;
USE SCHEMA ATLAS_MONITORING;

CREATE OR REPLACE TABLE PREDICTION_LOG (
    EVENT_TIME    TIMESTAMP_NTZ,
    MODEL_NAME    STRING,
    MODEL_VERSION STRING,
    ENTITY_ID     STRING,
    SCORE         FLOAT,
    LABEL         FLOAT,
    BATCH_ID      STRING
);

INSERT INTO PREDICTION_LOG (EVENT_TIME, MODEL_NAME, MODEL_VERSION, ENTITY_ID, SCORE, LABEL, BATCH_ID)
VALUES
  (DATEADD('day', -1,  CURRENT_TIMESTAMP()), 'fraud_detection_model', 'v1', 'CUST_001', 0.91, 1.0, 'batch_1'),
  (DATEADD('day', -1,  CURRENT_TIMESTAMP()), 'fraud_detection_model', 'v1', 'CUST_002', 0.20, 0.0, 'batch_1'),
  (DATEADD('day', -10, CURRENT_TIMESTAMP()), 'fraud_detection_model', 'v1', 'CUST_003', 0.45, 0.0, 'batch_2'),
  (DATEADD('day', -15, CURRENT_TIMESTAMP()), 'fraud_detection_model', 'v1', 'CUST_004', 0.35, 0.0, 'batch_2');

-- Preview
SELECT * FROM PREDICTION_LOG;
