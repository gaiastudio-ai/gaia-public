---
name: contract-testing
tier: specialized
version: '1.0'
---

# Contract Testing

## Principle

Contract testing validates API contracts between consumer and provider services without
requiring integrated end-to-end tests. Consumers define expectations as pact files,
providers verify against them independently. This enables parallel development, catches
breaking changes before merge, and documents API behavior as executable specifications.

## Rationale

Traditional integration testing requires running consumer and provider simultaneously,
creating slow and flaky tests with complex setup. Contract testing decouples services:
consumers define expectations (pact files), providers verify independently. The Pact
Broker acts as a central contract registry, enabling `can-i-deploy` safety checks before
production deployment.

## Pattern Examples

### Consumer Test (Frontend defines expectations)

```typescript
// tests/contract/user-api.pact.spec.ts
import { PactV3, MatchersV3 } from '@pact-foundation/pact';
import { getUserById } from '@/api/user-service';

const { like, string, integer } = MatchersV3;

const provider = new PactV3({
  consumer: 'user-management-web',
  provider: 'user-api-service',
  dir: './pacts',
});

describe('User API Contract', () => {
  it('returns user when exists', async () => {
    await provider
      .given('user with id 1 exists')       // Provider state
      .uponReceiving('a request for user 1')
      .withRequest({
        method: 'GET',
        path: '/users/1',
        headers: { Authorization: like('Bearer token123') },
      })
      .willRespondWith({
        status: 200,
        body: like({
          id: integer(1),
          name: string('John Doe'),
          email: string('john@example.com'),
        }),
      })
      .executeTest(async (mockServer) => {
        const user = await getUserById(1, { baseURL: mockServer.url });
        expect(user.name).toBe('John Doe');
      });
  });

  it('handles 404 when user missing', async () => {
    await provider
      .given('user with id 999 does not exist')
      .uponReceiving('a request for non-existent user')
      .withRequest({ method: 'GET', path: '/users/999' })
      .willRespondWith({
        status: 404,
        body: { error: 'User not found', code: 'USER_NOT_FOUND' },
      })
      .executeTest(async (mockServer) => {
        await expect(getUserById(999, { baseURL: mockServer.url }))
          .rejects.toThrow('User not found');
      });
  });
});
```

### Provider Verification

```typescript
// tests/contract/user-api.provider.spec.ts
import { Verifier } from '@pact-foundation/pact';
import { seedDatabase, resetDatabase } from '../support/db-helpers';

describe('Provider Verification', () => {
  it('verifies pacts from all consumers', async () => {
    await new Verifier({
      provider: 'user-api-service',
      providerBaseUrl: `http://localhost:${PORT}`,
      pactBrokerUrl: process.env.PACT_BROKER_URL,
      pactBrokerToken: process.env.PACT_BROKER_TOKEN,
      publishVerificationResult: process.env.CI === 'true',
      providerVersion: process.env.GIT_SHA,

      stateHandlers: {
        'user with id 1 exists': async () => {
          await seedDatabase({ users: [{ id: 1, name: 'John Doe' }] });
        },
        'user with id 999 does not exist': async () => {
          await resetDatabase();
        },
      },

      requestFilter: (req, res, next) => {
        req.headers['authorization'] = 'Bearer valid-test-token';
        next();
      },
    }).verifyProvider();
  });
});
```

### CI Integration

```yaml
# Consumer: publish pacts on merge
- name: Run consumer contract tests
  run: npm run test:contract
- name: Publish pacts
  run: |
    npx pact-broker publish ./pacts \
      --consumer-app-version ${{ github.sha }} \
      --branch ${{ github.head_ref || github.ref_name }}

# Provider: verify on PR + webhook trigger
- name: Verify pacts
  run: npm run test:contract:provider
- name: Can I Deploy?
  run: |
    npx pact-broker can-i-deploy \
      --pacticipant user-api-service \
      --version ${{ github.sha }} \
      --to-environment production
```

### When Contract vs Integration

| Scenario                      | Contract    | Integration |
|-------------------------------|-------------|-------------|
| API shape validation          | Primary     | Supplement  |
| Cross-team service boundaries | Primary     | Overkill    |
| Same-team microservices       | Supplement  | Primary     |
| Database interactions         | Cannot test | Primary     |
| Breaking change detection     | Primary     | Cannot test |

## Anti-Patterns

1. **Skipping provider states** -- Consumer tests that do not define `given()` states
   leave the provider guessing about what data to set up. Always define states explicitly.

2. **Testing implementation details** -- Contracts should define the API shape, not
   internal behavior. Avoid asserting on exact header values or response timing.

3. **No can-i-deploy check** -- Publishing pacts without checking compatibility before
   deploy defeats the purpose. Always gate deployments on `can-i-deploy`.

4. **Contract sprawl** -- Old pacts from deleted branches clutter the broker. Set up
   weekly cleanup with retention policies (keep 30 days, production tags, branch latest).

5. **Replacing all integration tests** -- Contract tests verify shape, not behavior.
   Keep integration tests for data integrity, transactions, and business logic that
   crosses service boundaries.

## Integration Points

- **Workflows**: `test-design` (deciding when to use contracts), `ci-setup` (Pact broker
  integration)
- **Related fragments**: `api-testing-patterns` (API test structure),
  `test-pyramid` (where contracts fit), `risk-governance` (contracts as quality gates)
