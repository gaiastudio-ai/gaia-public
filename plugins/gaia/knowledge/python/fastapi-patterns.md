---
name: FastAPI Application Patterns
stack: python
version: "1.0"
focus: [fastapi]
---

# FastAPI Application Patterns

## Principle

Use Pydantic models for request/response validation and serialization, FastAPI's dependency injection for shared resources (database sessions, auth), async endpoints for I/O-bound work, and background tasks for fire-and-forget operations. Structure the application with routers for modular organization.

## Rationale

FastAPI combines ASGI async performance with automatic OpenAPI documentation generated from Pydantic models and type hints. Dependency injection provides a clean, testable way to manage shared resources like database connections, without global state. Async endpoints allow handling thousands of concurrent connections efficiently, critical for APIs with external service calls or database queries.

## Pattern Examples

### Pattern 1: Pydantic Models and Validation

```python
from pydantic import BaseModel, Field, EmailStr, field_validator
from datetime import datetime
from enum import Enum


class UserRole(str, Enum):
    ADMIN = "admin"
    MEMBER = "member"
    VIEWER = "viewer"


class CreateUserRequest(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=100)
    role: UserRole = UserRole.MEMBER
    tags: list[str] = Field(default_factory=list, max_length=10)

    @field_validator("name")
    @classmethod
    def name_must_not_be_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Name must not be blank")
        return v.strip()


class UserResponse(BaseModel):
    id: int
    email: str
    name: str
    role: UserRole
    created_at: datetime

    model_config = {"from_attributes": True}  # enables ORM mode
```

### Pattern 2: Dependency Injection for DB Sessions

```python
from fastapi import Depends, FastAPI, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from typing import AsyncGenerator

engine = create_async_engine("postgresql+asyncpg://user:pass@localhost/db")
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    user = await user_repo.get_by_token(db, token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )
    return user


# Router with dependencies
router = APIRouter(prefix="/api/v1/users", tags=["users"])

@router.get("/", response_model=list[UserResponse])
async def list_users(
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await user_repo.get_all(db, skip=skip, limit=limit)


@router.post("/", response_model=UserResponse, status_code=201)
async def create_user(
    payload: CreateUserRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Admin required")
    return await user_repo.create(db, payload)
```

### Pattern 3: Background Tasks and Error Handling

```python
from fastapi import BackgroundTasks


async def send_welcome_email(email: str, name: str) -> None:
    """Fire-and-forget background task."""
    await email_service.send(
        to=email,
        subject="Welcome!",
        body=f"Hello {name}, welcome aboard.",
    )


@router.post("/register", response_model=UserResponse, status_code=201)
async def register(
    payload: CreateUserRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    user = await user_repo.create(db, payload)
    background_tasks.add_task(send_welcome_email, user.email, user.name)
    return user


# Centralized exception handler
@app.exception_handler(ValueError)
async def value_error_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": str(exc)},
    )
```

## Anti-Patterns

- **Sync endpoints for I/O**: Using `def` instead of `async def` for endpoints that call databases or external APIs blocks the event loop.
- **Business logic in route handlers**: Route functions should validate and delegate. Put logic in service modules or repository classes.
- **Missing response_model**: Without `response_model`, FastAPI cannot filter sensitive fields or generate accurate OpenAPI docs.
- **Global database sessions**: Creating a single global session instead of per-request sessions via dependency injection causes concurrency issues.
- **Catching broad exceptions silently**: `except Exception: pass` hides bugs. Catch specific exceptions and return meaningful errors.

## Integration Points

- **Django**: FastAPI can complement Django for async-heavy workloads; see `django-patterns.md`.
- **Data Pipelines**: FastAPI endpoints can trigger async pipeline runs; see `data-pipelines.md`.
- **Python Conventions**: Type hints are mandatory in FastAPI; see `python-conventions.md`.
- **Testing**: Use `httpx.AsyncClient` with `app` for async test cases.
