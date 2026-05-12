{#
  customer_order_dates.sql

  Explores daily order activity per customer using dbt_utils.date_spine.

  date_spine generates one row for every date in a range. Joining it to
  order data lets you see not just when customers ordered, but also the
  gaps — days with no activity — which is useful for retention and
  cohort analysis.

  This is an analysis file: dbt compiles it to plain SQL (dbt compile)
  but does not build a table. Use it for exploration and QA.
#}

with date_spine as (

    {{
        dbt_utils.date_spine(
            datepart = "day",
            start_date = "cast('2016-09-01' as date)",
            end_date   = "cast('2018-11-01' as date)"
        )
    }}

),

orders as (

    select
        customer_id,
        ordered_at::date            as order_date,
        count(distinct order_id)    as orders_placed,
        sum(item_price)             as gmv

    from {{ ref('fct_order_items') }}
    group by 1, 2

),

customers as (

    select distinct customer_id
    from {{ ref('fct_order_items') }}

),

-- Cross join every customer with every date, then attach actual orders.
-- Rows with orders_placed = 0 are days the customer did not order.
customer_dates as (

    select
        c.customer_id,
        d.date_day,
        coalesce(o.orders_placed, 0)    as orders_placed,
        coalesce(o.gmv, 0)              as gmv,
        o.orders_placed is not null     as had_order

    from customers c
    cross join date_spine d
    left join orders o
        on  c.customer_id = o.customer_id
        and d.date_day    = o.order_date

)

select * from customer_dates
order by customer_id, date_day
