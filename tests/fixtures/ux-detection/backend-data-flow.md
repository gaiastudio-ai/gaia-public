---
key: "E99-S1"
title: "Refactor backend data flow pipeline"
epic: "E99"
status: "ready-for-dev"
---

# Story: Refactor backend data flow pipeline

## User Story

As a backend engineer, I want the data flow between the ingestion service and the
warehouse simplified so that operational metrics are computed faster.

## Acceptance Criteria

- [ ] AC1: Given the ingestion service, when a record arrives, then the data flow
  routes it directly to the warehouse without an intermediate broker.
