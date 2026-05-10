{#
  classify_tier(column_name, tiers)

  Assigns a text label to a numeric column based on a list of thresholds.
  Generates a CASE WHEN block at compile time — no logic runs at query time
  beyond a simple comparison. Use this anywhere you need to bucket a metric
  into named performance tiers (sellers, products, customers, etc.) without
  copy-pasting the same CASE WHEN across multiple models.

  Arguments:
    column_name – the numeric column to evaluate (e.g. 'total_gmv')
    tiers       – an ordered list of {min_value, label} dicts, highest threshold
                  first. The first matching condition wins, so order matters.

  Thresholds should live in dbt_project.yml vars so they can be changed without
  touching SQL. Pass them in with var('seller_tier_thresholds').

  Example:
    {{ classify_tier('total_gmv', var('seller_tier_thresholds')) }}
    → case
          when total_gmv >= 50000 then 'platinum'
          when total_gmv >= 10000 then 'gold'
          when total_gmv >= 1000  then 'silver'
          when total_gmv >= 0     then 'bronze'
          else 'unclassified'
      end
#}
{% macro classify_tier(column_name, tiers) %}
    case
        {% for tier in tiers %}
        when {{ column_name }} >= {{ tier.min_value }} then '{{ tier.label }}'
        {% endfor %}
        else 'unclassified'
    end
{% endmacro %}
