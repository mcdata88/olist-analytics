# PRD: Customer Segmentation (mart_customer_segmentation)

**Author:** Carlos Mendes
**Status:** Approved
**Created:** 2026-04-20
**Last Updated:** 2026-04-28
**Linked Issue:** #58

---

## 1. Business Context

Marketing needs a customer-level table with lifetime metrics and behavioral
segments to power targeted email campaigns and churn prediction. Currently the
data science team rebuilds this from scratch every quarter in a Jupyter notebook
that takes 3 hours to run and has undocumented business rules. Moving this into
dbt makes it reproducible, testable, and available to the whole org.

## 2. Data Sources

| Source Table | Description | Grain | Refresh Cadence |
|---|---|---|---|
| `raw_olist.customers` | Customer profile with zip code | 1 row per customer_unique_id | Daily |
| `raw_olist.orders` | Order header | 1 row per order | Daily |
| `raw_olist.order_items` | Line items | 1 row per order + product | Daily |
| `raw_olist.order_reviews` | Post-delivery reviews | 1 row per review | Daily |

## 3. Output Specification

- **Model name:** `mart_customer_segmentation`
- **Grain:** One row per **customer_unique_id**
- **Primary key:** `customer_unique_id`
- **Materialization:** table

### Key Columns

| Column | Type | Description | Business Logic |
|---|---|---|---|
| `customer_unique_id` | VARCHAR | Deduplicated customer | From `customers` |
| `customer_city` | VARCHAR | City | From `customers` |
| `customer_state` | VARCHAR | State code | From `customers` |
| `first_order_at` | TIMESTAMP | Earliest purchase | `MIN(order_purchase_timestamp)` |
| `last_order_at` | TIMESTAMP | Most recent purchase | `MAX(order_purchase_timestamp)` |
| `lifetime_orders` | INTEGER | Total orders placed | `COUNT(DISTINCT order_id)` where status = 'delivered' |
| `lifetime_gmv` | NUMERIC | Total spent on products | `SUM(price)` from delivered order items |
| `lifetime_freight` | NUMERIC | Total freight paid | `SUM(freight_value)` |
| `avg_review_score` | NUMERIC | Mean review score | `AVG(review_score)` |
| `days_since_last_order` | INTEGER | Recency metric | `CURRENT_DATE - last_order_at` |
| `is_repeat_buyer` | BOOLEAN | Bought more than once | `lifetime_orders > 1` |
| `customer_segment` | VARCHAR | RFM-based segment | See Metric Definitions |

## 4. Metric Definitions

| Metric | Formula | Notes |
|---|---|---|
| Recency (R) | Days since last delivered order | Lower = better |
| Frequency (F) | Count of delivered orders | Higher = better |
| Monetary (M) | lifetime_gmv | Higher = better |
| customer_segment | Rule-based on R/F/M | See below |

**Segmentation rules (v1 — simple):**

| Segment | Criteria |
|---|---|
| `champion` | F >= 3 AND R <= 90 |
| `loyal` | F >= 2 AND R <= 180 |
| `at_risk` | F >= 2 AND R > 180 |
| `new` | F = 1 AND R <= 90 |
| `one_and_done` | F = 1 AND R > 90 |

## 5. Acceptance Criteria

- [ ] `customer_unique_id` is unique and not null
- [ ] `lifetime_orders >= 1` for all rows (no zero-order customers)
- [ ] `lifetime_gmv > 0` for all rows
- [ ] Every `customer_segment` value is one of the 5 defined segments
- [ ] `is_repeat_buyer` = TRUE only where `lifetime_orders > 1`
- [ ] Row count matches `COUNT(DISTINCT customer_unique_id)` from raw data
      (for customers with at least one delivered order)

## 6. Downstream Consumers

- **Dashboard:** Looker "Customer Health" (Marketing)
- **Pipeline:** Email campaign targeting (Braze integration)
- **Model:** ML churn prediction feature store (Data Science)

## 7. SLA / Freshness

- **Freshness requirement:** Updated by 8:00 AM BRT daily
- **Staleness alert:** If older than 48 hours

## 8. Open Questions / Risks

- [ ] Revisit segment thresholds after 30 days in production — current rules are hypothesis-based.
- [x] ~Use `customer_id` or `customer_unique_id`?~ **Decision: `customer_unique_id` — one customer can have multiple `customer_id` values across orders.**