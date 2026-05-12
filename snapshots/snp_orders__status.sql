{% snapshot snp_orders__status %}
-- PRD: docs/prds/snp_orders__status.md (Issue #91)

{#
  Tracks changes to order_status over time using the check strategy.

  Each time dbt snapshot runs and order_status has changed since the last
  run, a new row is inserted with dbt_valid_from set to now. The previous
  row gets dbt_valid_to stamped so you know exactly when each status ended.

  dbt adds four columns automatically:
    dbt_scd_id      – unique ID for each snapshot row
    dbt_updated_at  – when this row was last written
    dbt_valid_from  – when this version of the record became active
    dbt_valid_to    – when it was superseded (null = current version)

  Limitation: the Olist Kaggle dataset is static, so repeated snapshot
  runs will not accumulate history. The pattern is in place for a live feed.
#}

{{
    config(
        target_schema = 'snapshots',
        unique_key    = 'order_id',
        strategy      = 'check',
        check_cols    = ['order_status']
    )
}}

select
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp    as ordered_at,
    order_approved_at           as approved_at,
    order_delivered_carrier_date    as shipped_at,
    order_delivered_customer_date   as delivered_at,
    order_estimated_delivery_date   as estimated_delivery_at

from {{ source('raw_olist', 'orders') }}

{% endsnapshot %}
