# Architecture Excerpt — Fixture

## Component: Form Submission Service

- **Pattern:** Client-server with retry
- **Stack:** TypeScript, React, Express
- **Risk areas:** Network resilience, validation edge cases

## ADR-999: Retry with Exponential Backoff

Use exponential backoff for all client-to-server calls. Max retries: 3. Base delay: 1000ms.
