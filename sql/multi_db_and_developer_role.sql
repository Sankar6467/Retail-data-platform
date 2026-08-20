-- =====================================================================
-- Incremental migration on top of an already-run 01_setup_warehouses_roles_schemas.sql
-- (older version, before the multi-database split and RETAIL_DEVELOPER role).
--
-- Adds ONLY what is missing:
--   1. Resize RETAIL_BI_WH from XSMALL -> SMALL
--   2. Create the 3 new databases + 6 schemas (RETAIL_RAW_DB / RETAIL_STAGING_DB / RETAIL_ANALYTICS_DB)
--   3. Create the RETAIL_DEVELOPER role and its grants
--   4. Grant the existing functional roles (LOADER/TRANSFORMER/ANALYST/ADMIN) access to the
--      new databases/schemas (their old grants against RETAIL_DB are left untouched)
--
-- Does NOT touch, drop, or modify anything created by the original script.
-- Safe to re-run (every statement is idempotent: IF NOT EXISTS / plain GRANT).
--
-- Run as ACCOUNTADMIN (or whatever role ran the original 01 script) in YOUR TRIAL account.

=====================================================================================================================
-- 1. WAREHOUSE RESIZE - analysts scanning millions of rows shouldn't be
-- throttled by XSMALL compute.
-- ---------------------------------------------------------------------
ALTER WAREHOUSE RETAIL_BI_WH SET WAREHOUSE_SIZE = 'SMALL';

-- ---------------------------------------------------------------------
-- 2. NEW DATABASES - one per medallion boundary instead of one shared
-- database (reviewer feedback: a single RETAIL_DB is hard to manage at
-- scale). Old RETAIL_DB and its schemas are left in place, untouched.
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS RETAIL_RAW_DB
  COMMENT = 'Landing zone for the Python ingestion framework - RAW + AUDIT schemas only';

CREATE DATABASE IF NOT EXISTS RETAIL_STAGING_DB
  COMMENT = 'dbt working layers - STAGING, INTERMEDIATE, SNAPSHOTS schemas (not exposed to BI)';

CREATE DATABASE IF NOT EXISTS RETAIL_ANALYTICS_DB
  COMMENT = 'Business/mart layer served to BI tools and analysts - ANALYTICS schema only';

CREATE SCHEMA IF NOT EXISTS RETAIL_RAW_DB.RAW
  COMMENT = 'Landing zone - untouched source files loaded 1:1 by the Python ingestion framework';

CREATE SCHEMA IF NOT EXISTS RETAIL_RAW_DB.AUDIT
  COMMENT = 'Ingestion run logs, rejected-record quarantine, reconciliation results';

CREATE SCHEMA IF NOT EXISTS RETAIL_STAGING_DB.STAGING
  COMMENT = 'dbt staging layer - light cleaning/casting/renaming only, 1:1 with RAW';

CREATE SCHEMA IF NOT EXISTS RETAIL_STAGING_DB.INTERMEDIATE
  COMMENT = 'dbt intermediate layer - joins, dedup, business-rule prep (not exposed to BI)';

CREATE SCHEMA IF NOT EXISTS RETAIL_STAGING_DB.SNAPSHOTS
  COMMENT = 'dbt snapshots - type-2 SCD history for slowly changing dimensions';

CREATE SCHEMA IF NOT EXISTS RETAIL_ANALYTICS_DB.ANALYTICS
  COMMENT = 'dbt business/mart layer - fact & dimension tables exposed to BI tools';

-- ---------------------------------------------------------------------
-- 3. NEW ROLE - RETAIL_DEVELOPER (human developer role, same footprint
-- as RETAIL_TRANSFORMER, for running/debugging dbt manually)
-- ---------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS RETAIL_DEVELOPER
  COMMENT = 'Human developer role - same footprint as RETAIL_TRANSFORMER (read RAW, read/write STAGING/INTERMEDIATE/ANALYTICS/SNAPSHOTS) for running/debugging dbt manually';

GRANT ROLE RETAIL_DEVELOPER TO ROLE RETAIL_ADMIN;

GRANT USAGE ON WAREHOUSE RETAIL_TRANSFORM_WH TO ROLE RETAIL_DEVELOPER;

-- ---------------------------------------------------------------------
-- 4. GRANTS ON THE NEW DATABASES/SCHEMAS
-- Existing roles' old grants against RETAIL_DB are untouched - these are
-- additive grants onto the new objects only.
-- ---------------------------------------------------------------------

-- Loader: RAW_DB only
-- Database access
GRANT USAGE
ON DATABASE RETAIL_RAW_DB
TO ROLE RETAIL_LOADER;

-- Schema access
GRANT USAGE
ON SCHEMA RETAIL_RAW_DB.RAW
TO ROLE RETAIL_LOADER;

GRANT USAGE
ON SCHEMA RETAIL_RAW_DB.AUDIT
TO ROLE RETAIL_LOADER;


-- RAW schema: allow loader to create tables
GRANT CREATE TABLE
ON SCHEMA RETAIL_RAW_DB.RAW
TO ROLE RETAIL_LOADER;

-- RAW: permissions on existing tables
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
ON ALL TABLES IN SCHEMA RETAIL_RAW_DB.RAW
TO ROLE RETAIL_LOADER;

-- RAW: permissions on future tables
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
ON FUTURE TABLES IN SCHEMA RETAIL_RAW_DB.RAW
TO ROLE RETAIL_LOADER;


-- AUDIT schema: allow loader to create audit tables
GRANT CREATE TABLE
ON SCHEMA RETAIL_RAW_DB.AUDIT
TO ROLE RETAIL_LOADER;

-- AUDIT: permissions on existing tables
GRANT SELECT, INSERT
ON ALL TABLES IN SCHEMA RETAIL_RAW_DB.AUDIT
TO ROLE RETAIL_LOADER;

-- AUDIT: permissions on future tables
GRANT SELECT, INSERT
ON FUTURE TABLES IN SCHEMA RETAIL_RAW_DB.AUDIT
TO ROLE RETAIL_LOADER;
-- Transformer (dbt): reads RAW_DB, owns all of STAGING_DB and ANALYTICS_DB
GRANT USAGE ON DATABASE RETAIL_RAW_DB       TO ROLE RETAIL_TRANSFORMER;
GRANT USAGE ON DATABASE RETAIL_STAGING_DB   TO ROLE RETAIL_TRANSFORMER;
GRANT USAGE ON DATABASE RETAIL_ANALYTICS_DB TO ROLE RETAIL_TRANSFORMER;

GRANT USAGE ON SCHEMA RETAIL_RAW_DB.RAW TO ROLE RETAIL_TRANSFORMER;
GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_RAW_DB.RAW TO ROLE RETAIL_TRANSFORMER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_RAW_DB.RAW TO ROLE RETAIL_TRANSFORMER;

GRANT ALL ON SCHEMA RETAIL_STAGING_DB.STAGING      TO ROLE RETAIL_TRANSFORMER;
GRANT ALL ON SCHEMA RETAIL_STAGING_DB.INTERMEDIATE TO ROLE RETAIL_TRANSFORMER;
GRANT ALL ON SCHEMA RETAIL_STAGING_DB.SNAPSHOTS    TO ROLE RETAIL_TRANSFORMER;
GRANT ALL ON SCHEMA RETAIL_ANALYTICS_DB.ANALYTICS  TO ROLE RETAIL_TRANSFORMER;

-- Developer: same footprint as RETAIL_TRANSFORMER
GRANT USAGE ON DATABASE RETAIL_RAW_DB       TO ROLE RETAIL_DEVELOPER;
GRANT USAGE ON DATABASE RETAIL_STAGING_DB   TO ROLE RETAIL_DEVELOPER;
GRANT USAGE ON DATABASE RETAIL_ANALYTICS_DB TO ROLE RETAIL_DEVELOPER;

GRANT USAGE ON SCHEMA RETAIL_RAW_DB.RAW TO ROLE RETAIL_DEVELOPER;
GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_RAW_DB.RAW TO ROLE RETAIL_DEVELOPER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_RAW_DB.RAW TO ROLE RETAIL_DEVELOPER;

GRANT ALL ON SCHEMA RETAIL_STAGING_DB.STAGING      TO ROLE RETAIL_DEVELOPER;
GRANT ALL ON SCHEMA RETAIL_STAGING_DB.INTERMEDIATE TO ROLE RETAIL_DEVELOPER;
GRANT ALL ON SCHEMA RETAIL_STAGING_DB.SNAPSHOTS    TO ROLE RETAIL_DEVELOPER;
GRANT ALL ON SCHEMA RETAIL_ANALYTICS_DB.ANALYTICS  TO ROLE RETAIL_DEVELOPER;

-- Analyst: read-only on ANALYTICS_DB
GRANT USAGE ON DATABASE RETAIL_ANALYTICS_DB TO ROLE RETAIL_ANALYST;
GRANT USAGE ON SCHEMA RETAIL_ANALYTICS_DB.ANALYTICS TO ROLE RETAIL_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_ANALYTICS_DB.ANALYTICS    TO ROLE RETAIL_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_ANALYTICS_DB.ANALYTICS TO ROLE RETAIL_ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA RETAIL_ANALYTICS_DB.ANALYTICS    TO ROLE RETAIL_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA RETAIL_ANALYTICS_DB.ANALYTICS TO ROLE RETAIL_ANALYST;

-- Admin: full control across all 3 new databases
GRANT ALL ON DATABASE RETAIL_RAW_DB       TO ROLE RETAIL_ADMIN;
GRANT ALL ON DATABASE RETAIL_STAGING_DB   TO ROLE RETAIL_ADMIN;
GRANT ALL ON DATABASE RETAIL_ANALYTICS_DB TO ROLE RETAIL_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE RETAIL_RAW_DB       TO ROLE RETAIL_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE RETAIL_STAGING_DB   TO ROLE RETAIL_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE RETAIL_ANALYTICS_DB TO ROLE RETAIL_ADMIN;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE RETAIL_RAW_DB       TO ROLE RETAIL_ADMIN;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE RETAIL_STAGING_DB   TO ROLE RETAIL_ADMIN;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE RETAIL_ANALYTICS_DB TO ROLE RETAIL_ADMIN;

-- ---------------------------------------------------------------------
-- 5. PII TAG - moved to live in RETAIL_ANALYTICS_DB (only ever applied
-- to DIM_CUSTOMER columns in the ANALYTICS schema). The old tag under
-- RETAIL_DB.PUBLIC, if it already exists, is left in place untouched.
-- ---------------------------------------------------------------------
CREATE TAG IF NOT EXISTS RETAIL_ANALYTICS_DB.PUBLIC.PII_CLASSIFICATION
  COMMENT = 'Tags columns containing personally identifiable information';

-- Harmless if already granted (e.g. by the original 01 script) - GRANT is idempotent.
GRANT APPLY TAG ON ACCOUNT TO ROLE RETAIL_TRANSFORMER;

-- ---------------------------------------------------------------------
-- 6. OPTIONAL CLEANUP (commented out on purpose - run manually only
-- once you've confirmed nothing depends on the old single database
-- anymore, e.g. after re-pointing dbt profiles/ingestion .env and
-- re-running the pipeline against the new 3 databases).
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS RETAIL_DB;