# PRD: [Model/Feature Name]

**Author:** [Your Name]
**Status:** Draft | In Review | Approved | Implemented
**Created:** YYYY-MM-DD
**Last Updated:** YYYY-MM-DD
**Linked Issue:** #___

---

## 1. Business Context

_What business problem does this solve? Who asked for it? Why now?_

## 2. Data Sources

| Source Table | Description | Grain | Refresh Cadence |
|---|---|---|---|
| `raw.table_name` | ... | ... | ... |

## 3. Output Specification

- **Model name:** `mart_xxx` or `int_xxx` or `stg_xxx`
- **Grain:** One row per ___
- **Primary key:** `___`
- **Materialization:** table | view | incremental

### Key Columns

| Column | Type | Description | Business Logic |
|---|---|---|---|
| `column_name` | VARCHAR | ... | ... |

## 4. Metric Definitions

| Metric | Formula | Notes |
|---|---|---|
| `metric_name` | `SUM(x) / COUNT(y)` | Exclude nulls in... |

## 5. Acceptance Criteria

- [ ] Row count within expected range
- [ ] Primary key is unique and not null
- [ ] Metric X reconciles with existing report Y
- [ ] Passes all dbt tests listed in schema.yml

## 6. Downstream Consumers

- Dashboard: ___
- Team: ___
- Other models: ___

## 7. SLA / Freshness

- **Freshness requirement:** Updated by ___ AM daily
- **Staleness alert:** If older than ___ hours

## 8. Open Questions / Risks

- [ ] Question 1