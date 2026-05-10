-- fct_order_items.sql
-- ============================================================
-- PRD: docs/prds/fct_order_items.md (Issue #89)
-- Grain: One row per order_id + order_item_id
-- Materialization: table
-- ============================================================

with order_items as (
    select * from {{ ref('stg_olist__order_items') }}
),

orders as (
    select * from {{ ref('stg_olist__orders') }}
),

final as (
    select
        oi.order_id || '-' || oi.order_item_id       as order_item_sk,

        oi.order_id,
        oi.order_item_id,
        oi.seller_id,
        oi.product_id,
        o.customer_id,

        o.order_status,
        o.ordered_at,
        o.approved_at,
        o.shipped_at,
        o.delivered_at,
        o.estimated_delivery_at,

        oi.item_price,
        oi.freight_value,

        o.order_status = 'delivered'                 as is_delivered,

        case
            when o.order_status = 'delivered'
            then o.delivered_at <= o.estimated_delivery_at
        end                                          as is_on_time,

        case
            when o.order_status = 'delivered'
            then datediff('day', o.ordered_at, o.delivered_at)
        end                                          as days_to_deliver

    from order_items oi
    inner join orders o on oi.order_id = o.order_id
)

select * from final
