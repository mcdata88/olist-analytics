-- mart_order_revenue.sql
-- ============================================================
-- PRD: docs/prds/mart_order_revenue.md (Issue #42)
-- Grain: One row per order_id
-- Materialization: table
-- ============================================================

with orders as (
    select * from {{ ref('stg_olist__orders') }}
),

items as (
    select * from {{ ref('int_order_items_agg') }}
),

payments as (
    select * from {{ ref('int_order_payments_agg') }}
),

final as (
    select
        orders.order_id,
        orders.customer_id,

        orders.order_status,
        orders.ordered_at          as order_purchase_at,
        orders.delivered_at        as order_delivered_at,

        coalesce(items.total_items, 0)          as total_items,
        coalesce(items.total_item_revenue, 0)   as total_item_revenue,
        coalesce(items.total_freight, 0)        as total_freight,

        coalesce(payments.total_payment, 0)     as total_payment,
        payments.payment_types,
        payments.payment_installments_max,

        coalesce(payments.total_payment, 0)
            - (coalesce(items.total_item_revenue, 0)
               + coalesce(items.total_freight, 0))
            as revenue_freight_delta

    from orders
    left join items    on orders.order_id = items.order_id
    left join payments on orders.order_id = payments.order_id
)

select * from final