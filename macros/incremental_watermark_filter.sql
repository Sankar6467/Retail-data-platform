{#
  Reusable incremental filter for fact models whose grain is keyed by
  date_key rather than a raw timestamp: looks up the max calendar_date
  already loaded (via a join back to dim_date) and only pulls source rows
  newer than that. Falls back to vars.ingestion_start_date on the very
  first incremental run against an as-yet-empty target table. Used by
  both fct_sales and fct_inventory_daily so the look-back logic lives in
  one place instead of being duplicated per fact model.
#}
{% macro incremental_watermark_filter(source_date_column, date_dim_ref, date_dim_key_column='date_key', date_dim_date_column='calendar_date') -%}
    {% if is_incremental() %}
    where {{ source_date_column }} > (
        select coalesce(max(dd.{{ date_dim_date_column }})::timestamp_ntz, '{{ var("ingestion_start_date") }}')
        from {{ this }} f
        inner join {{ date_dim_ref }} dd on f.{{ date_dim_key_column }} = dd.{{ date_dim_key_column }}
    )
    {% endif %}
{%- endmacro %}
