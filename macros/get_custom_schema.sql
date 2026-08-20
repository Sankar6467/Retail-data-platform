{#
  Without this override, dbt's default generate_schema_name prefixes every
  custom +schema config with the connection's default schema (STAGING),
  producing STAGING_staging / STAGING_intermediate / STAGING_analytics /
  STAGING_snapshots instead of the STAGING/INTERMEDIATE/ANALYTICS/SNAPSHOTS
  schemas actually created and granted in sql/01_setup_warehouses_roles_schemas.sql.
  This makes the custom schema name the schema, full stop.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
