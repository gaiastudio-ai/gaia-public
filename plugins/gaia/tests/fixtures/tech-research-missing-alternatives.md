---
title: Tech Research — E42-S4 Negative Fixture
date: 2026-04-24
technologies: ["PostgreSQL"]
---

# Tech Research: Primary Datastore Selection

> Negative fixture for VCP-CHK-08: only one alternative is considered — the "At least 2 alternatives compared" V1 rule MUST fail under finalize.sh.

## Technology Overview

This technical research evaluates **PostgreSQL** as the primary transactional datastore. The use case is OLTP for a payments platform with a 3-person backend team and open-source licensing preference.

- Technology evaluated: PostgreSQL 16.
- Use case: OLTP datastore for a payments platform.
- Constraints: 3 engineers, 12-month runway, open-source licensing preferred.

## Evaluation Matrix

| Dimension | PostgreSQL |
|-----------|-----------|
| Maturity | 25+ years |
| Community | Large, PostgreSQL Global Development Group |
| Learning curve | Moderate |
| Licensing | PostgreSQL License (permissive) |
| Ecosystem | PostGIS, TimescaleDB, pgvector |
| Production readiness | Extremely stable, ACID, MVCC |

## Trade-off Analysis

Pros/cons for PostgreSQL:

**Pros**

- ACID transactions native.
- Permissive license.
- Rich SQL analytics.

**Cons**

- Horizontal scaling requires Citus.
- Schema migrations on hot tables need care.

## Recommendation

**Recommended technology: PostgreSQL 16.** Rationale: team fluency, permissive license, ACID fit for strong-consistency requirements.

## Migration / Adoption Considerations

- Timeline: 2-week schema design sprint.
- Team ramp-up: low — most engineers SQL-fluent.
- Risks: hot-table migration strategy.
