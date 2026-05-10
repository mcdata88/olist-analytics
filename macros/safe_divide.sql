{#
  safe_divide(numerator, denominator)

  Divides two columns without erroring when the denominator is zero or null.
  Returns null instead of crashing, which is the correct behavior for rate
  columns like on-time delivery rate or freight-to-revenue ratio.

  Arguments:
    numerator   – the column or expression on top of the division
    denominator – the column or expression on the bottom

  Example:
    {{ safe_divide('on_time_orders', 'total_delivered_orders') }}
    → iff(total_delivered_orders is null or total_delivered_orders = 0,
          null,
          on_time_orders::float / total_delivered_orders)
#}
{% macro safe_divide(numerator, denominator) %}
    iff(
        {{ denominator }} is null or {{ denominator }} = 0,
        null,
        {{ numerator }}::float / {{ denominator }}
    )
{% endmacro %}
