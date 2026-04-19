---
name: k6-patterns
tier: performance
version: '1.0'
---

# k6 Patterns

## Principle

k6 is a developer-centric load testing tool that uses JavaScript for test scripts.
It runs locally or in CI, produces metrics in real-time, and integrates with monitoring
systems. Write load tests as code, version them with your application, and run them
as part of your deployment pipeline.

## Rationale

Performance problems discovered in production are expensive to fix. k6 enables
shift-left performance testing — running load tests in CI catches regressions before
deployment. Its JavaScript API is familiar to developers, reducing the barrier to
writing and maintaining performance tests.

## Pattern Examples

### Basic Load Test

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 50 },   // ramp up to 50 users
    { duration: '5m', target: 50 },   // hold at 50
    { duration: '2m', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    http_req_failed: ['rate<0.01'],    // less than 1% failure rate
  },
};

export default function () {
  const res = http.get('https://api.example.com/users');

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
    'body has users': (r) => JSON.parse(r.body).length > 0,
  });

  sleep(1); // think time between requests
}
```

### Test Scenarios

```javascript
// Spike test — sudden traffic surge
export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '1m', target: 500 },   // sudden spike
    { duration: '30s', target: 500 },
    { duration: '1m', target: 10 },    // recovery
  ],
};

// Soak test — sustained load over time
export const options = {
  stages: [
    { duration: '5m', target: 100 },
    { duration: '4h', target: 100 },   // long duration
    { duration: '5m', target: 0 },
  ],
};

// Stress test — increasing load to find breaking point
export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '2m', target: 300 },
    { duration: '2m', target: 400 },   // keep increasing
    { duration: '2m', target: 500 },
    { duration: '5m', target: 0 },
  ],
};
```

### Virtual User Profiles

```javascript
import { scenario } from 'k6/execution';

export const options = {
  scenarios: {
    browse: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [{ duration: '5m', target: 100 }],
      exec: 'browseProducts',
    },
    checkout: {
      executor: 'constant-arrival-rate',
      rate: 10,
      timeUnit: '1s',
      duration: '5m',
      preAllocatedVUs: 50,
      exec: 'completePurchase',
    },
    api: {
      executor: 'constant-vus',
      vus: 20,
      duration: '5m',
      exec: 'apiCalls',
    },
  },
};

export function browseProducts() {
  http.get('https://api.example.com/products');
  sleep(Math.random() * 3 + 1);
}
export function completePurchase() {
  const cart = http.post('https://api.example.com/cart', JSON.stringify({
    items: [{ id: 1, quantity: 1 }],
  }), { headers: { 'Content-Type': 'application/json' } });
  http.post('https://api.example.com/checkout', JSON.stringify({
    cartId: JSON.parse(cart.body).id,
  }), { headers: { 'Content-Type': 'application/json' } });
}
```

### Thresholds and Custom Metrics

```javascript
export const options = {
  thresholds: {
    http_req_duration: ['p(50)<200', 'p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
    'http_req_duration{name:login}': ['p(95)<300'],
    checks: ['rate>0.99'],
  },
};
```

### Custom Metrics

```javascript
import { Trend, Counter, Rate } from 'k6/metrics';

const loginDuration = new Trend('login_duration');
const errorCount = new Counter('errors');
const successRate = new Rate('success_rate');

export default function () {
  const start = Date.now();
  const res = http.post('https://api.example.com/login', JSON.stringify({
    email: 'test@example.com',
    password: 'password',
  }));

  loginDuration.add(Date.now() - start);
  errorCount.add(res.status !== 200 ? 1 : 0);
  successRate.add(res.status === 200);
}
```

### CI Integration (GitHub Actions)

```yaml
- name: Run k6 load test
  uses: grafana/k6-action@v0.3.1
  with:
    filename: tests/performance/load-test.js
```

## Anti-Patterns

1. **No think time** — Omitting `sleep()` between requests creates unrealistic load
   patterns. Real users pause between actions.

2. **Single endpoint testing** — Load testing only one endpoint misses interaction
   effects. Test realistic user journeys across multiple endpoints.

3. **Ignoring ramp-up** — Jumping straight to peak load triggers cold-start failures
   that mask real issues. Always ramp up gradually.

4. **Testing in development** — Load test results are only meaningful against
   production-like infrastructure. Test against staging with realistic data.

5. **No thresholds** — Running load tests without pass/fail criteria makes them
   informational only. Define thresholds and fail CI on violations.

## Integration Points

- **Tools**: k6, Grafana Cloud, InfluxDB, GitHub Actions
- **Workflows**: `performance-testing` (test plan), `ci-setup` (pipeline integration)
- **Related fragments**: `lighthouse-ci` (frontend performance)
