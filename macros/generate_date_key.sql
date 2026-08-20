{% macro generate_date_key(date_column) -%}
    to_number(to_char({{ date_column }}, 'YYYYMMDD'))
{%- endmacro %}
