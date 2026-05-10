{% macro classify_tier(column_name, tiers) %}
    case
        {% for tier in tiers %}
        when {{ column_name }} >= {{ tier.min_value }} then '{{ tier.label }}'
        {% endfor %}
        else 'unclassified'
    end
{% endmacro %}
