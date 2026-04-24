---
title: Tech Research — E42-S4 Positive Fixture
date: 2026-04-24
technologies: ["PostgreSQL", "MongoDB"]
---

# Tech Research: Primary Datastore Selection

## Technology Overview

This technical research compares two datastore candidates — **PostgreSQL** and **MongoDB** — for the primary transactional store of a cross-border payments platform. The use case is medium-write-volume OLTP with strong consistency requirements and rich relational reporting. Constraints: a 3-person backend team with mixed SQL/NoSQL experience, a 12-month runway, and a preference for open-source licensing.

- Technologies evaluated: PostgreSQL 16, MongoDB 7.
- Use case: OLTP datastore for a regulated payments platform with ~500 TPS and strong consistency.
- Constraints: 3 engineers, 12-month runway, open-source licensing preferred.

## Evaluation Matrix

| Dimension | PostgreSQL | MongoDB |
|-----------|-----------|---------|
| Maturity | 25+ years, battle-tested | 15+ years, mature |
| Community | Very large, active PostgreSQL Global Development Group | Large, MongoDB Inc-led |
| Learning curve | Moderate (SQL familiar to most) | Moderate (document model) |
| Licensing | PostgreSQL License (permissive, OSI-approved) | SSPL (source-available, not OSI-approved) |
| Ecosystem | Extensions (PostGIS, TimescaleDB, pgvector), broad tool support | Atlas, Compass, Realm |
| IDE / tooling support | First-class in JetBrains, VS Code, pgAdmin | MongoDB Compass, VS Code extension |
| Documentation | Excellent, comprehensive manual | Excellent, product-driven docs |
| Production readiness | Extremely stable, ACID, MVCC | Stable; distributed transactions since 4.0 |
| Performance | Predictable on OLTP workloads | Strong on denormalized reads |
| Scalability | Vertical-first; read replicas, logical replication; Citus for sharding | Horizontal sharding native |

## Trade-off Analysis

Pros/cons matrix comparing the two alternatives across the dimensions above:

**PostgreSQL — Pros**

- ACID transactions native; well-understood consistency model.
- Permissive license eliminates SSPL contamination concerns for a payments SaaS.
- Rich SQL analytics without a separate warehouse for early-stage.
- Mature migration tooling (Flyway, Liquibase, sqitch).

**PostgreSQL — Cons**

- Horizontal scaling requires Citus or application-level sharding.
- Schema migrations on hot tables need careful planning.

**MongoDB — Pros**

- Flexible document model accelerates early iteration on evolving schemas.
- Horizontal sharding is built-in.
- Strong developer ergonomics for JSON-heavy payloads.

**MongoDB — Cons**

- SSPL licensing raises redistribution concerns for commercial SaaS.
- Distributed transactions have higher latency than single-node Postgres.
- Ad-hoc analytics require more tooling (Atlas Data Federation, BI connector).

### Alternatives Compared

Two alternatives are compared across the dimensions above: **PostgreSQL** (relational) and **MongoDB** (document). The compare spans maturity, licensing, scalability, performance, and ecosystem — the axes that materially differentiate the candidates for this use case.

## Recommendation

**Recommended technology: PostgreSQL 16**, with Citus as a future-proofing option for horizontal scale.

Rationale:

- The licensing constraint (open-source preferred, commercial SaaS redistribution) strongly favors the permissive PostgreSQL License over MongoDB's SSPL.
- The team's SQL familiarity shortens ramp-up compared with the document-model retraining MongoDB would require.
- ACID on a single node is a better fit for the strong-consistency requirement than MongoDB's distributed transactions at 500 TPS.
- Vertical scaling plus read replicas covers the 500 TPS target for the runway duration.

## Migration / Adoption Considerations

- **Timeline:** 2-week schema design sprint; 4-week build of the migrations pipeline; rolling out to staging by month 3.
- **Team ramp-up:** low — 2 of 3 engineers already fluent. A half-day internal workshop on MVCC/VACUUM suffices.
- **Risk factors:** hot-table migration strategy, replication lag under burst load, and pgvector stability for future ML workloads.

## Web Access

Web access was available during this session; live version/licensing research was incorporated.
