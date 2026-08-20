# Retail Data Platform - Deliverable

End-to-end retail sales data platform: Python ingests source files into
Snowflake, dbt Cloud transforms RAW into a governed star schema, and the
build is validated + deployed via a GitHub Actions CI/CD pipeline.

---

## Tech stack

| Layer          | Tool                              | Purpose                                            |
|----------------|------------------------------------|-----------------------------------------------------|
| Source systems | CSV files (customers, orders, ...) | Stand-in for POS / e-commerce / WMS extracts        |
| Ingestion      | Python (pandas, snowflake-connector) | Extract, validate, load raw files, audit-log runs |
| Warehouse      | Snowflake                          | 3 databases by pipeline stage: RETAIL_RAW_DB (RAW/AUDIT), RETAIL_STAGING_DB (STAGING/INTERMEDIATE/SNAPSHOTS), RETAIL_ANALYTICS_DB (ANALYTICS) |
| Transformation | dbt (dbt Cloud)                    | staging → intermediate → marts, snapshots, tests    |
| Governance     | Snowflake RBAC + tagging           | Least-privilege roles, PII tagging, resource monitor |
| CI/CD          | GitHub Actions                     | Python unit tests + dbt build/test on every push     |

See `Retail_Data_Platform_End_to_End_Documentation.docx` for architecture
diagrams and the full write-up, and `Deployment_Guide_Snowflake_Python_dbt.docx`
for step-by-step setup.

---

## Repository layout

```
retail_data_platform/
├── README.md
├── .gitignore
├── sql/
│   ├── 01_setup_warehouses_roles_schemas.sql          # warehouses, roles, schemas, governance
│   ├── 01b_migrate_multi_db_and_developer_role.sql    # migration: splits into RETAIL_RAW_DB/RETAIL_STAGING_DB/RETAIL_ANALYTICS_DB + RETAIL_DEVELOPER role
│   ├── 02_ddl_raw_and_audit.sql                       # RAW landing tables + AUDIT tables (in RETAIL_RAW_DB)
│   └── 03_ddl_business_layer_star_schema.sql          # reference DDL for the ANALYTICS star schema (in RETAIL_ANALYTICS_DB)
├── data/
│   ├── generate_sample_data.py                 # seeded generator for the CSVs below
│   ├── customers.csv                           # 500 rows
│   ├── products.csv                            # 200 rows
│   ├── stores.csv                               # 13 rows
│   ├── orders.csv                               # 5,000 rows
│   ├── order_items.csv                          # 10,960 rows
│   └── inventory_snapshots.csv                  # 21,600 rows
├── diagrams/
│   ├── generate_diagrams.py                    # regenerates the ER diagrams below
│   ├── generate_architecture_and_dfd.py        # regenerates the architecture/DFD diagram below
│   ├── source_erd.png                          # RAW layer entity relationships
│   ├── star_schema_erd.png                     # ANALYTICS star schema
│   └── architecture_diagram.png                # end-to-end architecture diagram
├── ingestion/                                   # Python extract/validate/load framework
│   ├── config.py                               # Snowflake config + per-file ingestion contracts
│   ├── extract.py
│   ├── validation.py
│   ├── snowflake_client.py                     # connection retry/backoff + bulk load
│   ├── pipeline.py                             # entry point: extract -> validate -> load -> audit
│   ├── requirements.txt
│   ├── .env.example                            # copy to .env and fill in your Snowflake creds
│   └── tests/test_validation.py                # 5 unit tests, no Snowflake connection required
├── dbt/retail_data_platform/                    # dbt project
│   ├── dbt_project.yml
│   ├── packages.yml                            # dbt_utils, dbt_expectations
│   ├── profiles.yml.example                    # copy to ~/.dbt/profiles.yml
│   ├── models/staging/                         # 1:1 with RAW, light typing only
│   ├── models/intermediate/                    # joins + derived business columns
│   ├── models/marts/dims/                      # dim_date, dim_customer (SCD2), dim_product, dim_store
│   ├── models/marts/facts/                     # fct_sales, fct_inventory_daily (incremental/merge)
│   ├── macros/                                 # generate_date_key, safe_divide, incremental_watermark_filter, get_custom_schema
│   ├── snapshots/customers_snapshot.sql        # Type-2 SCD source for dim_customer
│   └── tests/                                  # reconciliation + orphan-record singular tests
├── .github/workflows/ci.yml                     # Python tests + dbt build/test on PR/push
└── docs/
    ├── observability.md                         # logging/audit/alerting approach
    ├── benchmarking_and_roadmap.md              # benchmarking process + roadmap
    └── build_*.py                               # generates the .docx deliverables from this repo
