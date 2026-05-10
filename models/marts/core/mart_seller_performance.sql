-- mart_seller_performance.sql
-- ============================================================
-- PRD: docs/prds/mart_seller_performance.md (Issue #72)
-- Grain: One row per seller_id
-- Materialization: table
-- ============================================================

with sellers as (
    select * from {{ ref('stg_olist__sellers') }}
),

order_items as (
    select * from {{ ref('stg_olist__order_items') }}
),

orders as (
    select * from {{ ref('stg_olist__orders') }}
),

reviews as (
    select * from {{ ref('stg_olist__order_reviews') }}
),

-- Collapse items to one row per seller + order to avoid
-- duplicating review scores across multiple items in the same order
seller_order_items as (
    select
        seller_id,
        order_id,
        count(*)            as items_in_order,
        sum(item_price)     as order_revenue,
        sum(freight_value)  as order_freight

    from order_items
    group by 1, 2
),

seller_order_detail as (
    select
        soi.seller_id,
        soi.order_id,
        soi.items_in_order,
        soi.order_revenue,
        soi.order_freight,
        o.order_status,
        o.ordered_at,
        o.delivered_at,
        o.estimated_delivery_at,
        r.review_score

    from seller_order_items soi
    inner join orders  o on soi.order_id = o.order_id
    left join  reviews r on soi.order_id = r.order_id
),

aggregated as (
    select
        seller_id,

        count(order_id)                                                          as total_orders,
        count(case when order_status = 'delivered' then order_id end)            as total_delivered_orders,
        sum(items_in_order)                                                      as total_items_sold,
        sum(order_revenue)                                                       as total_gmv,
        sum(order_freight)                                                       as total_freight_charged,
        avg(review_score)                                                        as avg_review_score,

        count(case
            when order_status = 'delivered'
            and  delivered_at <= estimated_delivery_at
            then order_id
        end)                                                                     as on_time_orders,

        avg(case
            when order_status = 'delivered'
            then datediff('day', ordered_at, delivered_at)
        end)                                                                     as avg_days_to_deliver,

        min(ordered_at)                                                          as first_sale_at,
        max(ordered_at)                                                          as last_sale_at

    from seller_order_detail
    group by 1
),

final as (
    select
        s.seller_id,
        s.seller_city,
        s.seller_state,

        a.total_orders,
        a.total_delivered_orders,
        a.total_items_sold,
        a.total_gmv,
        a.total_freight_charged,
        round(a.avg_review_score, 2)                                             as avg_review_score,
        a.on_time_orders,
        round(
            {{ safe_divide('a.on_time_orders', 'a.total_delivered_orders') }},
            4
        )                                                                        as on_time_delivery_rate,
        round(a.avg_days_to_deliver, 1)                                          as avg_days_to_deliver,
        a.first_sale_at,
        a.last_sale_at,

        {{ classify_tier('a.total_gmv', var('seller_tier_thresholds')) }}        as seller_tier

    from sellers s
    inner join aggregated a on s.seller_id = a.seller_id
)

select * from final
