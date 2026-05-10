{% macro safe_divide(numerator, denominator) %}
    iff(
        {{ denominator }} is null or {{ denominator }} = 0,
        null,
        {{ numerator }}::float / {{ denominator }}
    )
{% endmacro %}
