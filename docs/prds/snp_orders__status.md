# PRD: Order Status Snapshot (snp_orders__status)

**Author:** Admin
**Status:** Draft
**Created:** 2026-05-10
**Last Updated:** 2026-05-10
**Linked Issue:** #91

---

## 1. Business Context

Order status changes over time — from `created` to `approved` to `shipped` to
`delivered`. The current `fct_order_items` table only captures the latest status,
meaning there is no record of how long an order spent in each state or when
transitions occurred.

Ops and Finance need this history to answer questions like:
- How long does the average order sit in `approved` before being shipped?
- Are delivery SLAs improving or degrading over time?
- Which sellers have the highest rate of orders stuck in `processing`?

A dbt snapshot captures a new row each time `order_status` changes, giving a
complete audit trail of every status transition per order.

## 2. Snapshot Strategy

dbt supports two strategies for detecting changes:

| Strategy | How it works |
|---|---|
| `timestamp` | Compares an `updated_at` column on each run |
| `check` | Compares specified columns and flags any change |

The raw Olist `orders` table has no `updated_at` column, so the **`check`
strategy on `order_status`** is used. On each `dbt snapshot` run, dbt compares
the current `order_status` against the stored value and inserts a new row if
it has changed.

## 3. Data Sources

| Source Table | Description | Grain | Refresh Cadence |
|---|---|---|---|
| `raw_olist.orders` | Order header with status and timestamps | 1 row per order | Daily |

## 4. Output Specification

- **Snapshot name:** `snp_orders__status`
- **Grain:** One row per **order_id + status version**
- **Unique key:** `order_id`
- **Strategy:** `check` on `order_status`
- **Target schema:** `snapshots`
- **Materialization:** table (managed by dbt snapshot)

### Key Columns

| Column | Type | Description | Source |
|---|---|---|---|
| `order_id` | VARCHAR | Order identifier | `raw_olist.orders` |
| `customer_id` | VARCHAR | FK to customer | `raw_olist.orders` |
| `order_status` | VARCHAR | Status at time of snapshot | `raw_olist.orders` |
| `ordered_at` | TIMESTAMP | Order placement time | `order_purchase_timestamp` |
| `approved_at` | TIMESTAMP | Payment approval time | `order_approved_at` |
| `shipped_at` | TIMESTAMP | Carrier handoff time | `order_delivered_carrier_date` |
| `delivered_at` | TIMESTAMP | Customer delivery time | `order_delivered_customer_date` |
| `estimated_delivery_at` | TIMESTAMP | Promised delivery date | `order_estimated_delivery_date` |
| `dbt_scd_id` | VARCHAR | Unique ID per snapshot row | dbt-managed |
| `dbt_updated_at` | TIMESTAMP | When this row was written | dbt-managed |
| `dbt_valid_from` | TIMESTAMP | When this status version became active | dbt-managed |
| `dbt_valid_to` | TIMESTAMP | When superseded; null = current version | dbt-managed |

## 5. Metric Definitions

| Metric | Formula | Notes |
|---|---|---|
| Time in status | `DATEDIFF('hour', dbt_valid_from, coalesce(dbt_valid_to, current_timestamp))` | Measures how long an order held each status |
| Status transition count | `COUNT(*) - 1` per `order_id` | Number of status changes; 0 = never changed |

## 6. Acceptance Criteria

- [ ] Every `order_id` from `raw_olist.orders` appears at least once
- [ ] `dbt_valid_to` is null for exactly one row per `order_id` (the current version)
- [ ] `dbt_valid_from` < `dbt_valid_to` for all closed rows
- [ ] `order_status` values match the accepted set from `stg_olist__orders`
- [ ] Row count >= `COUNT(DISTINCT order_id)` from raw (one row per order minimum)

## 7. Downstream Consumers

- **Analysis:** Order status duration queries (Ops SLA reporting)
- **Future mart:** `mart_order_fulfillment` — average time per status, seller fulfillment speed

## 8. SLA / Freshness

- **Run cadence:** Daily, after `dbt build` completes
- **Command:** `dbt snapshot --select snp_orders__status`
- **Note:** Snapshots run separately from `dbt build` — they must be scheduled
  as a distinct step in the pipeline

## 9. Open Questions / Risks

- [ ] The Olist Kaggle dataset is static — repeated snapshot runs will not
  accumulate history. This pattern is in place for when the project connects
  to a live data feed.
- [ ] `dbt snapshot` must be run as a separate scheduled job from `dbt build`.
  Confirm pipeline orchestration (e.g. Airflow, dbt Cloud) handles this before
  production deployment.
