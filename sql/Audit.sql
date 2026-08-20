
-- ---------------------------------------------------------------------
-- AUDIT.INGESTION_RUN_LOG
-- One row per (file, batch) load attempt - powers observability
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AUDIT.INGESTION_RUN_LOG (
    run_log_id        NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    batch_id          VARCHAR(100),
    source_file       VARCHAR(255),
    target_table      VARCHAR(255),
    started_at        TIMESTAMP_NTZ,
    finished_at       TIMESTAMP_NTZ,
    status            VARCHAR(20),      -- SUCCESS, FAILED, PARTIAL
    rows_read         NUMBER,
    rows_loaded       NUMBER,
    rows_rejected     NUMBER,
    error_message     VARCHAR(4000),
    PRIMARY KEY (run_log_id)
);

-- ---------------------------------------------------------------------
-- AUDIT.REJECTED_RECORDS
-- Quarantine for rows that fail validation - never silently dropped.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AUDIT.REJECTED_RECORDS (
    rejected_id      NUMBER AUTOINCREMENT START 1 INCREMENT 1,
    batch_id         VARCHAR(100),
    source_file      VARCHAR(255),
    target_table     VARCHAR(255),
    raw_record       VARIANT,
    validation_error VARCHAR(4000),
    rejected_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (rejected_id)
);