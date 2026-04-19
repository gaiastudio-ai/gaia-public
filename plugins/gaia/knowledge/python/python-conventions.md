---
name: Python Conventions and Standards
stack: python
version: "1.0"
focus: [python]
---

# Python Conventions and Standards

## Principle

Follow PEP 8 for style, use type hints throughout, manage dependencies with virtual environments and `pyproject.toml`, and structure projects with clear module boundaries. Use `ruff` for linting and formatting, `mypy` for type checking, and `pytest` for testing.

## Rationale

PEP 8 is the universal Python style standard; deviating from it creates friction for contributors and tooling. Type hints enable IDE autocompletion, catch bugs before runtime, and serve as documentation. `pyproject.toml` (PEP 621) consolidates project metadata, dependencies, and tool configuration in a single file, replacing the fragmented `setup.py` + `setup.cfg` + `requirements.txt` approach. Virtual environments isolate dependencies and prevent system-wide conflicts.

## Pattern Examples

### Pattern 1: Project Structure and pyproject.toml

```
my-project/
  src/
    my_project/
      __init__.py
      models/
        __init__.py
        user.py
      services/
        __init__.py
        user_service.py
      api/
        __init__.py
        routes.py
      core/
        __init__.py
        config.py
        exceptions.py
  tests/
    __init__.py
    conftest.py
    test_user_service.py
  pyproject.toml
```

```toml
# pyproject.toml
[project]
name = "my-project"
version = "1.0.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.110",
    "sqlalchemy>=2.0",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-asyncio>=0.23",
    "ruff>=0.4",
    "mypy>=1.10",
]

[tool.ruff]
target-version = "py312"
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM", "RUF"]

[tool.mypy]
strict = true
python_version = "3.12"

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
```

### Pattern 2: Type Hints and Protocols

```python
from typing import Protocol, TypeVar, Generic
from datetime import datetime


# Protocol for structural typing (duck typing with type safety)
class Repository(Protocol[T]):
    async def get(self, id: int) -> T | None: ...
    async def save(self, entity: T) -> T: ...
    async def delete(self, id: int) -> bool: ...


T = TypeVar("T")


class BaseService(Generic[T]):
    """Generic service with typed repository dependency."""

    def __init__(self, repo: Repository[T]) -> None:
        self._repo = repo

    async def get_or_raise(self, id: int) -> T:
        entity = await self._repo.get(id)
        if entity is None:
            raise EntityNotFoundError(f"Entity {id} not found")
        return entity


# Concrete implementation
class UserService(BaseService[User]):
    async def create(self, data: CreateUserRequest) -> User:
        user = User(
            email=data.email,
            name=data.name,
            created_at=datetime.now(),
        )
        return await self._repo.save(user)
```

### Pattern 3: Testing with pytest Fixtures

```python
import pytest
from unittest.mock import AsyncMock


@pytest.fixture
def mock_user_repo() -> AsyncMock:
    repo = AsyncMock(spec=UserRepository)
    repo.get.return_value = User(id=1, email="test@example.com", name="Test")
    return repo


@pytest.fixture
def user_service(mock_user_repo: AsyncMock) -> UserService:
    return UserService(repo=mock_user_repo)


async def test_get_user_returns_user(user_service: UserService) -> None:
    user = await user_service.get_or_raise(1)
    assert user.email == "test@example.com"


async def test_get_user_raises_when_not_found(
    user_service: UserService,
    mock_user_repo: AsyncMock,
) -> None:
    mock_user_repo.get.return_value = None
    with pytest.raises(EntityNotFoundError):
        await user_service.get_or_raise(999)
```

## Anti-Patterns

- **No type hints**: Omitting type annotations loses IDE support and prevents `mypy` from catching bugs. Add hints to all function signatures.
- **`requirements.txt` without pinning**: `requests` instead of `requests==2.31.0` leads to unreproducible builds. Pin all dependencies.
- **Global mutable state**: Module-level mutable variables (e.g., `db = None`) create testing nightmares. Use dependency injection.
- **Wildcard imports**: `from module import *` pollutes the namespace and hides where symbols come from. Import explicitly.
- **No virtual environment**: Installing packages globally causes version conflicts. Always use `venv`, `uv`, or `conda`.

## Integration Points

- **Django**: Django projects follow these conventions with Django-specific additions; see `django-patterns.md`.
- **FastAPI**: FastAPI requires type hints for auto-documentation; see `fastapi-patterns.md`.
- **Data Pipelines**: Pipeline scripts follow the same structure and testing patterns; see `data-pipelines.md`.
- **CI/CD**: Run `ruff check`, `mypy`, and `pytest` in CI. Use `pre-commit` hooks locally.
