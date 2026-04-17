---
name: Next.js Application Patterns
stack: typescript
version: "1.0"
focus: [nextjs]
---

# Next.js Application Patterns

## Principle

Use the App Router with React Server Components (RSC) as the default rendering strategy. Fetch data on the server to reduce client bundle size and improve initial load. Use client components (`'use client'`) only when interactivity (hooks, event handlers, browser APIs) is required. Leverage Next.js caching layers (request memoization, data cache, full route cache) deliberately.

## Rationale

Server Components eliminate the client-side JavaScript for data display, reducing bundle sizes by 30-50%. The App Router's nested layout system prevents re-rendering shared UI (navigation, sidebars) during navigation. Next.js provides multiple caching layers that must be understood to avoid stale data in production. Route handlers replace API routes with a more natural request/response model.

## Pattern Examples

### Pattern 1: Server Component with Data Fetching

```typescript
// app/users/page.tsx — Server Component (default, no 'use client')
import { UserList } from './user-list';

interface User {
  id: number;
  name: string;
  email: string;
}

async function getUsers(): Promise<User[]> {
  const res = await fetch('https://api.example.com/users', {
    next: { revalidate: 60 },  // ISR: revalidate every 60 seconds
  });
  if (!res.ok) throw new Error('Failed to fetch users');
  return res.json();
}

export default async function UsersPage() {
  const users = await getUsers();
  return (
    <main>
      <h1>Users</h1>
      {/* UserList can be a client component for interactivity */}
      <UserList initialUsers={users} />
    </main>
  );
}

// app/users/loading.tsx — Automatic Suspense boundary
export default function Loading() {
  return <UserListSkeleton />;
}

// app/users/error.tsx — Error boundary
'use client';
export default function Error({ error, reset }: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

### Pattern 2: Nested Layouts

```typescript
// app/layout.tsx — Root layout (wraps all pages)
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Navbar />
        {children}
      </body>
    </html>
  );
}

// app/dashboard/layout.tsx — Dashboard layout (persists across dashboard pages)
import { Sidebar } from '@/components/sidebar';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex">
      <Sidebar />
      <main className="flex-1 p-6">{children}</main>
    </div>
  );
}

// app/dashboard/analytics/page.tsx — inherits both layouts
export default async function AnalyticsPage() {
  const metrics = await getMetrics();
  return <MetricsDashboard data={metrics} />;
}
```

### Pattern 3: Route Handler with Validation

```typescript
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';

const CreateUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  role: z.enum(['admin', 'member']).default('member'),
});

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const validated = CreateUserSchema.parse(body);
    const user = await db.user.create({ data: validated });
    return NextResponse.json(user, { status: 201 });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { errors: error.flatten().fieldErrors },
        { status: 422 }
      );
    }
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const page = parseInt(searchParams.get('page') ?? '1');
  const limit = parseInt(searchParams.get('limit') ?? '20');
  const users = await db.user.findMany({
    skip: (page - 1) * limit,
    take: limit,
  });
  return NextResponse.json(users);
}
```

## Anti-Patterns

- **`'use client'` on everything**: Treating the App Router like the Pages Router. Default to server components; opt into client only for interactivity.
- **Fetching in client components**: Using `useEffect` to fetch data that could be fetched on the server wastes client bandwidth and reveals API details.
- **Ignoring caching semantics**: Not setting `revalidate` or `cache` options on `fetch` leads to unexpected stale or always-fresh behavior.
- **Passing functions as props from server to client**: Functions are not serializable across the RSC boundary. Use server actions or route handlers.

## Integration Points

- **React**: Client components use React hooks and patterns; see `react-patterns.md`.
- **Express**: Next.js can sit behind an Express server for custom middleware; see `express-patterns.md`.
- **TypeScript**: Strict typing for route handlers, page props, and metadata; see `ts-conventions.md`.
- **Testing**: Use `@testing-library/react` with Next.js test utilities for component and integration tests.
