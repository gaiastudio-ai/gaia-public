---
name: Express.js Application Patterns
stack: typescript
version: "1.0"
focus: [express]
---

# Express.js Application Patterns

## Principle

Structure Express applications with a clear middleware chain: parsing, authentication, route-specific logic, and centralized error handling. Use typed request/response objects, validation middleware for input sanitization, and async error wrappers to prevent unhandled promise rejections. Organize routes into modular routers by domain.

## Rationale

Express processes requests through a middleware chain in the order middleware is registered. This linear flow makes it easy to reason about request processing but requires discipline to avoid middleware order bugs. TypeScript types on request/response objects catch shape mismatches at compile time. Centralized error handling via a four-argument middleware ensures consistent error responses and prevents leaked stack traces in production.

## Pattern Examples

### Pattern 1: Typed Middleware Chain

```typescript
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';

// Extend Express Request with typed properties
interface AuthenticatedRequest extends Request {
  user: { id: string; role: string };
}

// Auth middleware — adds typed user to request
function authenticate(req: Request, res: Response, next: NextFunction): void {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }
  try {
    const payload = verifyToken(token);
    (req as AuthenticatedRequest).user = payload;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

// Role guard middleware factory
function requireRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const user = (req as AuthenticatedRequest).user;
    if (!roles.includes(user.role)) {
      res.status(403).json({ error: 'Insufficient permissions' });
      return;
    }
    next();
  };
}

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use('/api', authenticate);  // All /api routes require auth
```

### Pattern 2: Modular Router with Validation

```typescript
import { Router } from 'express';
import { z } from 'zod';

const router = Router();

// Validation middleware factory
function validate(schema: z.ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      res.status(422).json({
        error: 'Validation failed',
        details: result.error.flatten().fieldErrors,
      });
      return;
    }
    req.body = result.data;
    next();
  };
}

const CreateUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

// Async handler wrapper — catches rejected promises
function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>
) {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res, next).catch(next);
  };
}

router.post(
  '/',
  validate(CreateUserSchema),
  asyncHandler(async (req: Request, res: Response) => {
    const user = await userService.create(req.body);
    res.status(201).json(user);
  })
);

router.get(
  '/:id',
  asyncHandler(async (req: Request, res: Response) => {
    const user = await userService.findById(req.params.id);
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }
    res.json(user);
  })
);

export const userRouter = router;
```

### Pattern 3: Centralized Error Handling

```typescript
// Custom error classes
class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public isOperational = true
  ) {
    super(message);
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

class NotFoundError extends AppError {
  constructor(resource: string) {
    super(404, `${resource} not found`);
  }
}

// Error handling middleware — MUST have 4 parameters
function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: err.message,
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
    });
    return;
  }

  // Unexpected errors — log and return generic message
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
}

// Register AFTER all routes
app.use('/api/users', userRouter);
app.use('/api/orders', orderRouter);
app.use(errorHandler);  // Must be last
```

## Anti-Patterns

- **No async error handling**: Unhandled promise rejections in route handlers crash the process. Always use an async wrapper or express-async-errors.
- **Error middleware not last**: Registering the error handler before routes means it never catches route errors.
- **Business logic in route handlers**: Route handlers should validate, delegate to a service, and format the response. Keep them thin.
- **No input validation**: Trusting `req.body` without validation opens injection and type-mismatch vulnerabilities.

## Integration Points

- **React/Next.js**: Express APIs are consumed by React client components; see `react-patterns.md` and `nextjs-patterns.md`.
- **TypeScript**: Strict typing for middleware, requests, and responses; see `ts-conventions.md`.
- **Testing**: Use `supertest` for HTTP-level integration tests against the Express app.
- **Docker**: Express apps are containerized with multi-stage builds for production deployment.
