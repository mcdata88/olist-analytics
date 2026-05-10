# PRD: Order Items Fact Table (fct_order_items)

**Author:** Admin
**Status:** Draft
**Created:** 2026-05-09
**Last Updated:** 2026-05-09
**Linked Issue:** #89

---

## 1. Business Context

The current mart layer joins staging models independently in each model. As the
number of marts grows, this creates duplicated join logic, inconsistent metric
definitions, and no shared grain to query across dimensions.

`fct_order_items` establishes the **canonical atomic fact** for the Olist dataset:
one row per item sold. Every revenue, delivery, and seller metric in the project
derives from this grain. Building it as a shared foundation allows future marts
to aggregate from a single trusted source instead of rebuilding joins from scratch.

**This is the highest-priority dimensional model** because it unblocks all future
dimension tables and is a prerequisite for migrating existing marts to star-schema
reads in v2.

## 2. Release Approach

This model is released in three phases. Each phase requires sign-off before the
next begins.

| Phase | Scope | Breaking Changes |
|---|---|---|
| **v1 — this PRD** | Build `fct_order_items`. Existing marts unchanged. | None |
| **v2 — separate PRD** | Build `dim_sellers`, `dim_customers`, `dim_products`. | None |
| **v3 — separate PRD** | Migrate `mart_order_revenue`, `mart_seller_performance`, `mart_customer_segmentation` to read from `fct_*` and `dim_*`. Decommission intermediate models. | Downstream query changes |

**v1 is purely additive.** No existing model is modified. Consumers of current marts
are not affected. The fact table is validated in production before any migration
begins in v2 or v3.

## 3. Data Sources

| Source Table | Description | Grain | Refresh Cadence |
|---|---|---|---|
| `stg_olist__order_items` | Line items with price, freight, seller, product | 1 row per order + item | Daily |
| `stg_olist__orders` | Order header with status and timestamps | 1 row per order | Daily |

> **v1 scope:** Only these two staging models are joined. Seller attributes,
> product attributes, customer attributes, and review scores are **not** included
> in the fact table — they belong in dimension tables (v2). Foreign key columns
> (`seller_id`, `product_id`, `customer_id`) are carried as join keys only.

## 4. Output Specification

- **Model name:** `fct_order_items`
- **Grain:** One row per **order_id + order_item_id**
- **Primary key:** `order_item_sk` (surrogate key: `order_id || '-' || order_item_id`)
- **Materialization:** table (full refresh daily)
- **Schema:** `core`

### Key Columns

| Column | Type | Description | Business Logic |
|---|---|---|---|
| `order_item_sk` | VARCHAR | Surrogate primary key | `order_id \|\| '-' \|\| order_item_id` |
| `order_id` | VARCHAR | FK — order header | From `order_items` |
| `order_item_id` | INTEGER | Position within order | From `order_items` |
| `seller_id` | VARCHAR | FK — seller dimension (v2) | From `order_items` |
| `product_id` | VARCHAR | FK — product dimension (v2) | From `order_items` |
| `customer_id` | VARCHAR | FK — customer dimension (v2) | From `orders` |
| `order_status` | VARCHAR | Degenerate dimension | From `orders` |
| `ordered_at` | TIMESTAMP | Order placement time | From `orders.ordered_at` |
| `approved_at` | TIMESTAMP | Payment approval time | From `orders.approved_at` |
| `shipped_at` | TIMESTAMP | Carrier handoff time | From `orders.shipped_at` |
| `delivered_at` | TIMESTAMP | Customer delivery time | From `orders.delivered_at` |
| `estimated_delivery_at` | TIMESTAMP | Promised delivery date | From `orders.estimated_delivery_at` |
| `item_price` | NUMERIC(12,2) | Unit sale price | From `order_items.item_price` |
| `freight_value` | NUMERIC(12,2) | Freight charge for this item | From `order_items.freight_value` |
| `is_delivered` | BOOLEAN | Delivery confirmed | `order_status = 'delivered'` |
| `is_on_time` | BOOLEAN | Delivered by estimated date | `delivered_at <= estimated_delivery_at`; NULL if not delivered |
| `days_to_deliver` | INTEGER | Calendar days purchase → delivery | `DATEDIFF('day', ordered_at, delivered_at)`; NULL if not delivered |

## 5. Metric Definitions

This fact table is the **source of truth** for the metrics below. Marts aggregate
from this table rather than defining the logic themselves.

| Metric | Fact Table Formula | Current Location (pre-v3) |
|---|---|---|
| GMV | `SUM(item_price)` | `mart_order_revenue.total_item_revenue` |
| Total Freight | `SUM(freight_value)` | `mart_order_revenue.total_freight` |
| On-Time Delivery Rate | `{{ safe_divide(SUM(is_on_time::int), SUM(is_delivered::int)) }}` | `mart_seller_performance.on_time_delivery_rate` |
| Avg Days to Deliver | `AVG(days_to_deliver)` where `is_delivered` | `mart_seller_performance.avg_days_to_deliver` |
| Items per Order | `COUNT(order_item_id)` grouped by `order_id` | Inline in intermediate models |

## 6. Acceptance Criteria

- [ ] `order_item_sk` is unique and not null
- [ ] Row count matches `COUNT(*)` from `stg_olist__order_items` exactly
- [ ] `SUM(item_price)` reconciles with `SUM(total_item_revenue)` from `mart_order_revenue`
- [ ] `SUM(freight_value)` reconciles with `SUM(total_freight)` from `mart_order_revenue`
- [ ] `is_on_time` is NULL for all rows where `is_delivered = FALSE`
- [ ] `days_to_deliver` is NULL for all rows where `is_delivered = FALSE`
- [ ] `days_to_deliver >= 0` for all non-null rows
- [ ] No `order_id` in `fct_order_items` is absent from `stg_olist__orders`

## 7. Out of Scope (v1)

The following are explicitly deferred to v2 or v3:

- `dim_sellers`, `dim_customers`, `dim_products`, `dim_dates`
- Surrogate keys for dimension tables
- Review scores (belong in a separate `fct_order_reviews` or as a dim join)
- Payment data (belongs in `fct_order_payments` or a mart aggregation)
- Migrating existing marts to read from this fact table
- Decommissioning `int_order_items_agg` or `int_order_payments_agg`

## 8. Downstream Consumers

**v1 (new consumers of this fact table):**
- Ad-hoc analysis requiring item-level grain (e.g. product mix by seller state)
- Future `dim_*` tables (v2)

**v3 (after migration):**
- `mart_order_revenue` — replaces `int_order_items_agg` reads
- `mart_seller_performance` — replaces direct `stg_olist__order_items` + `stg_olist__orders` joins
- `mart_customer_segmentation` — replaces direct staging joins

## 9. SLA / Freshness

- **Freshness requirement:** Updated by 6:00 AM BRT daily (before all marts)
- **Rationale:** Marts depend on this table in v3; it must complete first in the DAG

## 10. Open Questions / Risks

- [ ] Should `order_item_sk` use `dbt_utils.generate_surrogate_key` (MD5 hash) or a simple string concat? String concat chosen for v1 — revisit if dbt_utils is added as a package.
- [ ] Payment data is excluded from this fact table. Confirm whether a separate `fct_order_payments` is needed or whether payment aggregations live only in marts.
- [ ] Existing intermediate models (`int_order_items_agg`) are not decommissioned in v1 — they remain as dependencies of current marts. Plan their removal in the v3 migration PRD.
