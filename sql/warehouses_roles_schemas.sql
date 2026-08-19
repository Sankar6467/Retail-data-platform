
-- --------------------------------------------------------------------
-- 1. WAREHOUSES
-- ---------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS RETAIL_LOAD_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Used by Python ingestion framework to load raw files into staging';

CREATE WAREHOUSE IF NOT EXISTS RETAIL_TRANSFORM_WH
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Used by dbt for staging -> intermediate -> mart transformations';

CREATE WAREHOUSE IF NOT EXISTS RETAIL_BI_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Used by BI tools / analysts querying the business (mart) layer';

-- ---------------------------------------------------------------------
-- 2. DATABASE
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS RETAIL_DB
  COMMENT = 'Retail sales analytics platform - assessment use case';

-- ---------------------------------------------------------------------
-- 3. SCHEMAS - one per medallion layer, matching dbt custom schema config
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS RETAIL_DB.RAW
  COMMENT = 'Landing zone - untouched source files loaded 1:1 by the Python ingestion framework';

CREATE SCHEMA IF NOT EXISTS RETAIL_DB.STAGING
  COMMENT = 'dbt staging layer - light cleaning/casting/renaming only, 1:1 with RAW';

CREATE SCHEMA IF NOT EXISTS RETAIL_DB.INTERMEDIATE
  COMMENT = 'dbt intermediate layer - joins, dedup, business-rule prep (not exposed to BI)';

CREATE SCHEMA IF NOT EXISTS RETAIL_DB.ANALYTICS
  COMMENT = 'dbt business/mart layer - fact & dimension tables exposed to BI tools';

CREATE SCHEMA IF NOT EXISTS RETAIL_DB.SNAPSHOTS
  COMMENT = 'dbt snapshots - type-2 SCD history for slowly changing dimensions';

CREATE SCHEMA IF NOT EXISTS RETAIL_DB.AUDIT
  COMMENT = 'Ingestion run logs, rejected-record quarantine, reconciliation results';
-- ---------------------------------------------------------------------
-- 4. ROLES (RBAC) - functional roles, least-privilege, no personal grants
-- ---------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS RETAIL_LOADER      COMMENT = 'Python ingestion service role - write to RAW/AUDIT only';
CREATE ROLE IF NOT EXISTS RETAIL_TRANSFORMER COMMENT = 'dbt service role - read RAW/STAGING, write STAGING/INTERMEDIATE/ANALYTICS/SNAPSHOTS';
CREATE ROLE IF NOT EXISTS RETAIL_ANALYST     COMMENT = 'BI/reporting role - read-only on ANALYTICS';
CREATE ROLE IF NOT EXISTS RETAIL_ADMIN       COMMENT = 'Platform admin - full control within RETAIL_DB, grants roles to users';

-- Role hierarchy: admin sits above the functional roles for auditability
GRANT ROLE RETAIL_LOADER      TO ROLE RETAIL_ADMIN;
GRANT ROLE RETAIL_TRANSFORMER TO ROLE RETAIL_ADMIN;
GRANT ROLE RETAIL_ANALYST     TO ROLE RETAIL_ADMIN;
GRANT ROLE RETAIL_ADMIN       TO ROLE SYSADMIN;

-- ---------------------------------------------------------------------
-- 5. WAREHOUSE GRANTS
-- ---------------------------------------------------------------------
GRANT USAGE ON WAREHOUSE RETAIL_LOAD_WH      TO ROLE RETAIL_LOADER;
GRANT USAGE ON WAREHOUSE RETAIL_TRANSFORM_WH TO ROLE RETAIL_TRANSFORMER;
GRANT USAGE ON WAREHOUSE RETAIL_BI_WH        TO ROLE RETAIL_ANALYST;
GRANT USAGE ON WAREHOUSE RETAIL_LOAD_WH      TO ROLE RETAIL_ADMIN;
GRANT USAGE ON WAREHOUSE RETAIL_TRANSFORM_WH TO ROLE RETAIL_ADMIN;
GRANT USAGE ON WAREHOUSE RETAIL_BI_WH        TO ROLE RETAIL_ADMIN;

-- ---------------------------------------------------------------------
-- 6. DATABASE / SCHEMA GRANTS
-- ---------------------------------------------------------------------
GRANT USAGE ON DATABASE RETAIL_DB TO ROLE RETAIL_LOADER;
GRANT USAGE ON DATABASE RETAIL_DB TO ROLE RETAIL_TRANSFORMER;
GRANT USAGE ON DATABASE RETAIL_DB TO ROLE RETAIL_ANALYST;

-- Loader: RAW + AUDIT only (principle of least privilege - never touches ANALYTICS)
GRANT USAGE ON SCHEMA RETAIL_DB.RAW   TO ROLE RETAIL_LOADER;
GRANT USAGE ON SCHEMA RETAIL_DB.AUDIT TO ROLE RETAIL_LOADER;
GRANT CREATE TABLE ON SCHEMA RETAIL_DB.RAW TO ROLE RETAIL_LOADER;
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA RETAIL_DB.RAW TO ROLE RETAIL_LOADER;
GRANT INSERT, SELECT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA RETAIL_DB.RAW TO ROLE RETAIL_LOADER;

GRANT CREATE TABLE ON SCHEMA RETAIL_DB.AUDIT TO ROLE RETAIL_LOADER;
GRANT INSERT, SELECT ON ALL TABLES IN SCHEMA RETAIL_DB.AUDIT TO ROLE RETAIL_LOADER;
GRANT INSERT, SELECT ON FUTURE TABLES IN SCHEMA RETAIL_DB.AUDIT TO ROLE RETAIL_LOADER;

-- Transformer (dbt): reads RAW, owns STAGING/INTERMEDIATE/ANALYTICS/SNAPSHOTS
GRANT USAGE ON SCHEMA RETAIL_DB.RAW TO ROLE RETAIL_TRANSFORMER;
GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_DB.RAW TO ROLE RETAIL_TRANSFORMER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_DB.RAW TO ROLE RETAIL_TRANSFORMER;

GRANT ALL ON SCHEMA RETAIL_DB.STAGING TO ROLE RETAIL_TRANSFORMER;
GRANT ALL ON SCHEMA RETAIL_DB.INTERMEDIATE TO ROLE RETAIL_TRANSFORMER;
GRANT ALL ON SCHEMA RETAIL_DB.ANALYTICS TO ROLE RETAIL_TRANSFORMER;
GRANT ALL ON SCHEMA RETAIL_DB.SNAPSHOTS    TO ROLE RETAIL_TRANSFORMER;

-- Analyst: read-only on ANALYTICS (the only layer BI tools should ever see)
GRANT USAGE ON SCHEMA RETAIL_DB.ANALYTICS TO ROLE RETAIL_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_DB.ANALYTICS    TO ROLE RETAIL_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_DB.ANALYTICS TO ROLE RETAIL_ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA RETAIL_DB.ANALYTICS    TO ROLE RETAIL_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA RETAIL_DB.ANALYTICS TO ROLE RETAIL_ANALYST;

-- Admin: full control for setup/maintenance
GRANT ALL ON DATABASE RETAIL_DB TO ROLE RETAIL_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE RETAIL_DB TO ROLE RETAIL_ADMIN;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE RETAIL_DB TO ROLE RETAIL_ADMIN;

-- ---------------------------------------------------------------------
-- 7. USER -> ROLE ASSIGNMENT
-- ---------------------------------------------------------------------
GRANT ROLE RETAIL_ADMIN TO USER SANKAR6467;
ALTER USER SANKAR6467 SET DEFAULT_ROLE = RETAIL_ADMIN;
ALTER USER SANKAR6467 SET DEFAULT_WAREHOUSE = RETAIL_TRANSFORM_WH;

-- ---------------------------------------------------------------------
-- 8. RESOURCE MONITOR - governance guardrail against runaway trial credit burn
-- ---------------------------------------------------------------------
CREATE RESOURCE MONITOR IF NOT EXISTS RETAIL_TRIAL_MONITOR
  WITH CREDIT_QUOTA = 50
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75 PERCENT DO NOTIFY
    ON 90 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE RETAIL_LOAD_WH      SET RESOURCE_MONITOR = RETAIL_TRIAL_MONITOR;
ALTER WAREHOUSE RETAIL_TRANSFORM_WH SET RESOURCE_MONITOR = RETAIL_TRIAL_MONITOR;
ALTER WAREHOUSE RETAIL_BI_WH        SET RESOURCE_MONITOR = RETAIL_TRIAL_MONITOR;

-- ---------------------------------------------------------------------
-- 9. OBJECT TAGGING - governance/classification standard for PII columns
-- ---------------------------------------------------------------------
CREATE TAG IF NOT EXISTS RETAIL_DB.PUBLIC.PII_CLASSIFICATION
  COMMENT = 'Tags columns containing personally identifiable information';

-- RETAIL_TRANSFORMER (dbt) applies this tag to DIM_CUSTOMER PII columns when

GRANT APPLY TAG ON ACCOUNT TO ROLE RETAIL_TRANSFORMER;

-- ALTER TABLE RETAIL_DB.ANALYTICS.DIM_CUSTOMER MODIFY COLUMN EMAIL SET TAG PII_CLASSIFICATION = 'EMAIL';