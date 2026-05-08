## What does this PR do?

_Brief description of the change._

## Linked PRD

> Every model change must link to an approved PRD.

- **PRD:** `docs/prds/_____.md`
- **Issue:** #___

## Checklist

### PRD Compliance
- [ ] PRD was approved before development began
- [ ] Output columns match PRD Key Columns specification
- [ ] Metric definitions match PRD definitions
- [ ] All acceptance criteria from PRD are covered by dbt tests

### Code Quality
- [ ] Follows staging > intermediate > mart layering
- [ ] No business logic in staging models
- [ ] CTEs are named clearly and commented

### Testing
- [ ] `dbt build` passes locally
- [ ] Schema tests added for new/changed columns
- [ ] PRD acceptance criteria mapped to dbt tests

### Documentation
- [ ] Schema YAML descriptions updated
- [ ] PRD updated if scope changed during implementation