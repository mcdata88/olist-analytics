# PRD: Seller Performance Summary (mart_seller_performance)

**Author:** Admin
**Status:** Draft
**Created:** 2026-05-09
**Last Updated:** 2026-05-09
**Linked Issue:** #72

---

## 1. Business Context

The Marketplace Ops team needs a seller-level performance table to identify top sellers,
flag underperformers, and power commission-tier logic. Today this analysis is done in
ad-hoc SQL notebooks that each define "top seller" differently. This mart becomes the
**single source of truth** for seller health metrics.

This model also serves as the first in the project to require shared **dbt macros**:
- `classify_tier()` — generates a CASE WHEN tier label from a numeric column and
  configurable thresholds. Reusable by `mart_product_performance` (planned #81).
- `safe_divide()` — null-safe division for rate columns. Reusable across any mart
  that computes ratios.

Without these macros, the tiering CASE WHEN and division guard would be copy-pasted
into every performance mart.

## 2. Data Sources

| Source Table | Description | Grain | Refresh Cadence |
|---|---|---|---|
| `stg_olist__sellers` | Seller profile with city/state | 1 row per seller | Daily |
| `stg_olist__order_items` | Line items with price and freight | 1 row per order + item | Daily |
| `stg_olist__orders` | Order status and delivery timestamps | 1 row per order | Daily |
| `stg_olist__order_reviews` | Customer review scores | 1 row per review | Daily |

## 3. Output Specification

- **Model name:** `mart_seller_performance`
- **Grain:** One row per **seller_id**
- **Primary key:** `seller_id`
- **Materialization:** table (full refresh daily)
- **Schema:** `core`

### Key Columns

| Column | Type | Description | Business Logic |
|---|---|---|---|
| `seller_id` | VARCHAR | Unique seller identifier | From `sellers` |
| `seller_city` | VARCHAR | Seller city | From `sellers` |
| `seller_state` | VARCHAR | Seller state (2-char) | From `sellers` |
| `total_orders` | INTEGER | Orders containing this seller's items | `COUNT(DISTINCT order_id)` from `order_items` |
| `total_delivered_orders` | INTEGER | Delivered orders only | Filter `order_status = 'delivered'` |
| `total_items_sold` | INTEGER | Sum of items sold | `COUNT(order_item_id)` from `order_items` |
| `total_gmv` | NUMERIC | Gross revenue from this seller's items | `SUM(price)` from `order_items` |
| `total_freight_charged` | NUMERIC | Total freight on their items | `SUM(freight_value)` from `order_items` |
| `avg_review_score` | NUMERIC | Average customer review score | `AVG(review_score)` on orders with their items |
| `on_time_orders` | INTEGER | Delivered on or before estimated date | `delivered_at <= estimated_delivery_at` |
| `on_time_delivery_rate` | NUMERIC | Share of delivered orders that were on time | `{{ safe_divide('on_time_orders', 'total_delivered_orders') }}` |
| `avg_days_to_deliver` | NUMERIC | Average days from purchase to delivery | `AVG(DATEDIFF('day', ordered_at, delivered_at))` on delivered orders |
| `first_sale_at` | TIMESTAMP | Earliest order date | `MIN(ordered_at)` |
| `last_sale_at` | TIMESTAMP | Most recent order date | `MAX(ordered_at)` |
| `seller_tier` | VARCHAR | Performance tier based on GMV | `{{ classify_tier('total_gmv', var('seller_tier_thresholds')) }}` |

## 4. Macro Specifications

### `safe_divide(numerator, denominator)`
**File:** `macros/safe_divide.sql`

Returns `NULL` if denominator is 0 or null; otherwise returns `numerator::float / denominator`.
Prevents division-by-zero errors on rate columns across any mart.

```sql
-- example output
iff(total_delivered_orders = 0 or total_delivered_orders is null,
    null,
    on_time_orders::float / total_delivered_orders)
```

### `classify_tier(column_name, tiers)`
**File:** `macros/classify_tier.sql`

Accepts a column name and an ordered list of `{min_value, label}` dicts (highest threshold
first). Generates a CASE WHEN expression. Thresholds are set via `var('seller_tier_thresholds')`
in `dbt_project.yml` so they can be adjusted without touching SQL.

```sql
-- example output for seller_tier_thresholds: [{min: 50000, label: platinum}, ...]
case
    when total_gmv >= 50000 then 'platinum'
    when total_gmv >= 10000 then 'gold'
    when total_gmv >= 1000  then 'silver'
    else                         'bronze'
end
```

**Default thresholds (set in `dbt_project.yml` vars):**

| Tier | Min GMV (BRL) |
|---|---|
| `platinum` | 50,000 |
| `gold` | 10,000 |
| `silver` | 1,000 |
| `bronze` | 0 (catch-all) |

## 5. Metric Definitions

| Metric | Formula | Notes |
|---|---|---|
| Seller GMV | `SUM(total_gmv)` across sellers | Excludes cancelled/unavailable orders |
| On-Time Delivery Rate | `{{ safe_divide('on_time_orders', 'total_delivered_orders') }}` | Only meaningful for delivered orders |
| Avg Days to Deliver | `AVG(avg_days_to_deliver)` | Nulls where delivery date is missing |
| Seller Tier Distribution | `COUNT(*) GROUP BY seller_tier` | Expected: platinum < 5%, bronze > 40% |

## 6. Acceptance Criteria

- [ ] `seller_id` is unique and not null
- [ ] `total_gmv >= 0` for all rows
- [ ] `on_time_delivery_rate` is between 0 and 1 (or null) for all rows
- [ ] `seller_tier` value is one of: `platinum`, `gold`, `silver`, `bronze`
- [ ] Row count matches `COUNT(DISTINCT seller_id)` from `raw_olist.order_items`
- [ ] `SUM(total_gmv)` across all sellers reconciles with `SUM(total_item_revenue)` from `mart_order_revenue`
- [ ] `classify_tier` macro produces no null tiers (bronze is the catch-all)
- [ ] `safe_divide` macro produces null (not error) when `total_delivered_orders = 0`

## 7. Downstream Consumers

- **Dashboard:** Looker "Seller Performance" (Marketplace Ops) — currently reads from `mart_order_revenue`; migrate to this mart
- **Model:** `mart_product_performance` (#81) — will reuse `classify_tier` and `safe_divide` macros
- **Ops workflow:** Weekly underperformer review (sellers in `bronze` tier with `avg_review_score < 3.0`)

## 8. SLA / Freshness

- **Freshness requirement:** Updated by 8:00 AM BRT daily (after `mart_order_revenue` completes)
- **Staleness alert:** If source data older than 36 hours

## 9. Open Questions / Risks

- [ ] Should `seller_tier` thresholds be based on GMV percentiles (dynamic) or fixed BRL amounts (static)? Fixed amounts chosen for v1 — revisit once we have 6 months of live data.
- [ ] Review scores are at the order level, not the seller level. Orders with multiple sellers will assign the same review score to all sellers on that order — confirm this is acceptable with Ops.
- [ ] `on_time_delivery_rate` nulls when `total_delivered_orders = 0` — confirm dashboard handles nulls gracefully before go-live.
