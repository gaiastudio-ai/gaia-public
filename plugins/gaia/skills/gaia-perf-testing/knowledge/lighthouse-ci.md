---
name: lighthouse-ci
tier: performance
version: '1.0'
---

# Lighthouse CI

## Principle

Lighthouse CI integrates Google Lighthouse into your CI/CD pipeline, enforcing
performance budgets and Core Web Vitals targets on every build. It tracks scores
over time, preventing gradual performance degradation that manual testing misses.

## Rationale

Frontend performance regressions are introduced incrementally — a new dependency here,
an unoptimized image there. By the time the impact is noticed, dozens of changes
contribute to the problem. Lighthouse CI creates a performance ratchet that catches
regressions at the PR level, when they are cheapest to fix.

## Pattern Examples

### Lighthouse CI Configuration

```javascript
// lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: [
        'http://localhost:3000/',
        'http://localhost:3000/dashboard',
        'http://localhost:3000/products',
      ],
      startServerCommand: 'npm run start',
      numberOfRuns: 3, // median of 3 runs for stability
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'categories:best-practices': ['warn', { minScore: 0.85 }],
        'categories:seo': ['warn', { minScore: 0.9 }],
      },
    },
    upload: {
      target: 'temporary-public-storage', // or 'lhci' for self-hosted
    },
  },
};
```

### Core Web Vitals Targets

```javascript
// lighthouserc.js — CWV-focused assertions
module.exports = {
  ci: {
    assert: {
      assertions: {
        // Largest Contentful Paint — under 2.5s
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],

        // Interaction to Next Paint (replaces FID) — under 200ms
        'interactive': ['error', { maxNumericValue: 3800 }],

        // Cumulative Layout Shift — under 0.1
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],

        // First Contentful Paint — under 1.8s
        'first-contentful-paint': ['warn', { maxNumericValue: 1800 }],

        // Total Blocking Time — under 200ms
        'total-blocking-time': ['error', { maxNumericValue: 200 }],

        // Speed Index — under 3.4s
        'speed-index': ['warn', { maxNumericValue: 3400 }],
      },
    },
  },
};
```

### Performance Budgets

```javascript
// lighthouserc.js — resource budgets
module.exports = {
  ci: {
    assert: {
      assertions: {
        'resource-summary:script:size': ['error', { maxNumericValue: 300000 }],  // 300KB JS
        'resource-summary:stylesheet:size': ['warn', { maxNumericValue: 50000 }], // 50KB CSS
        'resource-summary:image:size': ['warn', { maxNumericValue: 500000 }],     // 500KB images
        'resource-summary:total:size': ['error', { maxNumericValue: 1000000 }],   // 1MB total
        'resource-summary:third-party:size': ['warn', { maxNumericValue: 200000 }],
      },
    },
  },
};

```

### GitHub Actions Integration

```yaml
- name: Run Lighthouse CI
  uses: treosh/lighthouse-ci-action@v11
  with:
    configPath: './lighthouserc.js'
    uploadArtifacts: true
    temporaryPublicStorage: true
```

### Bundle Analysis Integration

```javascript
// webpack.config.js
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
module.exports = {
  plugins: [
    new BundleAnalyzerPlugin({
      analyzerMode: process.env.CI ? 'static' : 'server',
      reportFilename: 'bundle-report.html',
    }),
  ],
};

// Next.js — next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});
module.exports = withBundleAnalyzer({ /* next config */ });
```

## Anti-Patterns

1. **Warning-only thresholds** — Using `warn` for critical metrics lets regressions
   through. Use `error` for Core Web Vitals and `warn` for secondary metrics.

2. **Single-run results** — One Lighthouse run has high variance. Always use
   `numberOfRuns: 3` or more and take the median.

3. **Testing development builds** — Development builds include source maps and debug
   code. Always test production builds for accurate results.

4. **Ignoring third-party impact** — Third-party scripts (analytics, ads, widgets)
   significantly affect performance. Budget for and track them separately.

5. **No historical tracking** — Without a Lighthouse CI server, you lose trending data.
   Set up self-hosted LHCI or use temporary public storage for PR comparisons.

## Integration Points

- **Tools**: Lighthouse CI, webpack-bundle-analyzer, @next/bundle-analyzer
- **Workflows**: `performance-testing` (test plan), `ci-setup` (pipeline integration)
- **Related fragments**: `k6-patterns` (backend performance)
