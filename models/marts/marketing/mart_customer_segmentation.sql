-- mart_customer_segmentation.sql
-- ============================================================
-- PRD: docs/prds/mart_customer_segmentation.md (Issue #58)
-- Grain: One row per customer_unique_id
-- Materialization: table
-- ============================================================

with customers as (
    select * from {{ ref('stg_olist__customers') }}
),

orders as (
    select * from {{ ref('stg_olist__orders') }}
    where order_status = 'delivered'
),

items as (
    select * from {{ ref('int_order_items_agg') }}
),

reviews as (
    select * from {{ ref('stg_olist__order_reviews') }}
),

order_with_customer as (
    select
        customers.customer_unique_id,
        customers.customer_city,
        customers.customer_state,
        orders.order_id,
        orders.ordered_at,
        items.total_item_revenue,
        items.total_freight
    from orders
    inner join customers on orders.customer_id = customers.customer_id
    left join items      on orders.order_id    = items.order_id
),

review_scores as (
    select
        order_id,
        avg(review_score) as avg_review_score
    from reviews
    group by 1
),

customer_metrics as (
    select
        oc.customer_unique_id,

        max(oc.customer_city)   as customer_city,
        max(oc.customer_state)  as customer_state,

        min(oc.ordered_at)      as first_order_at,
        max(oc.ordered_at)      as last_order_at,

        count(distinct oc.order_id)                  as lifetime_orders,
        coalesce(sum(oc.total_item_revenue), 0)      as lifetime_gmv,
        coalesce(sum(oc.total_freight), 0)           as lifetime_freight,

        round(avg(rs.avg_review_score), 1)           as avg_review_score

    from order_with_customer oc
    left join review_scores rs on oc.order_id = rs.order_id
    group by 1
),

segmented as (
    select
        *,

        datediff('day', last_order_at, current_date()) as days_since_last_order,

        iff(lifetime_orders > 1, true, false) as is_repeat_buyer,

        case
            when lifetime_orders >= 3
                 and datediff('day', last_order_at, current_date()) <= 90
                then 'champion'
            when lifetime_orders >= 2
                 and datediff('day', last_order_at, current_date()) <= 180
                then 'loyal'
            when lifetime_orders >= 2
                 and datediff('day', last_order_at, current_date()) > 180
                then 'at_risk'
            when lifetime_orders = 1
                 and datediff('day', last_order_at, current_date()) <= 90
                then 'new'
            else 'one_and_done'
        end as customer_segment

    from customer_metrics
)

select * from segmented