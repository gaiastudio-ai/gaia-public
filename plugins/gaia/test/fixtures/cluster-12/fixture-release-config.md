# Release Configuration (Cluster 12 Test Fixture)

## Environments

- staging
- production

## Environment Progression

1. Deploy to staging
2. Run smoke tests
3. Promote to production

## Rollback Criteria

- Error rate exceeds 1%
- P99 latency exceeds 500ms
- Health check failures on /health or /readiness
