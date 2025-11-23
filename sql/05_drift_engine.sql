-- 05_drift_engine.sql
-- Drift view and sample query

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
    recent.recent_avg_score     AS RECENT_AVG_SCORE,
    baseline.baseline_avg_score AS BASELINE_AVG_SCORE,
    (recent.recent_avg_score - baseline.baseline_avg_score) AS SCORE_DELTA
FROM recent, baseline;

-- Preview
SELECT * FROM DRIFT_VIEW;
