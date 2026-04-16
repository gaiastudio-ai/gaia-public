# Health Endpoints (Cluster 12 Test Fixture)

## Health Check Configuration

| Endpoint | Expected Status | Timeout |
|----------|----------------|---------|
| /health | 200 | 5s |
| /readiness | 200 | 10s |
| /liveness | 200 | 3s |

## Validation Rules

- All endpoints must return expected status within timeout
- Response body must contain {"status": "ok"} or {"status": "healthy"}
