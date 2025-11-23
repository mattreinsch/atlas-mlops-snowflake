-- 06_retraining_orchestration.sql
-- Stored procedure + task skeleton for automated retraining

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
        -- TODO: integrate with your real training pipeline
        -- e.g. external function / Snowpark Container / orchestration tool
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

-- To enable the task:
-- ALTER TASK ATLAS_DRIFT_TASK RESUME;
