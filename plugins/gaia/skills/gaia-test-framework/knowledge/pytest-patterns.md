---
name: pytest-patterns
tier: unit-testing
version: '1.0'
---

# Pytest Patterns

## Principle

Fixtures are the foundation of test architecture in Python. pytest's fixture system
enables composable, scoped test dependencies that eliminate setup duplication while
maintaining test isolation. Combine fixtures with parameterization for thorough
coverage without test proliferation.

## Rationale

Python's dynamic nature makes test setup verbose without fixtures. pytest's dependency
injection model lets tests declare what they need, not how to build it. This separation
of concern keeps tests focused on assertions while fixtures handle the plumbing.

## Pattern Examples

### conftest.py Hierarchy

```python
# tests/conftest.py — shared across all tests
import pytest
from app import create_app
from app.db import db as _db

@pytest.fixture(scope="session")
def app():
    app = create_app(config="testing")
    yield app

@pytest.fixture(scope="session")
def db(app):
    with app.app_context():
        _db.create_all()
        yield _db
        _db.drop_all()

@pytest.fixture
def session(db):
    connection = db.engine.connect()
    transaction = connection.begin()
    session = db.create_scoped_session(bind=connection)
    yield session
    session.close()
    transaction.rollback()
    connection.close()
```

### Fixture Scoping

```python
# function — fresh per test (default, safest)
@pytest.fixture
def user():
    return User(name="test", email="test@example.com")

# class — shared within a test class
@pytest.fixture(scope="class")
def api_client(app):
    return app.test_client()

# module — shared within a file
@pytest.fixture(scope="module")
def expensive_resource():
    return load_large_dataset()

# session — shared across entire test run
@pytest.fixture(scope="session")
def database_engine():
    return create_engine("sqlite:///:memory:")
```

### Parameterized Tests

```python
@pytest.mark.parametrize("input_val,expected", [
    ("hello", "HELLO"),
    ("Hello World", "HELLO WORLD"),
    ("", ""),
    ("123abc", "123ABC"),
])
def test_uppercase(input_val, expected):
    assert input_val.upper() == expected

@pytest.mark.parametrize("discount_type,amount,expected", [
    ("percentage", 20, 80.0),
    ("fixed", 15, 85.0),
    ("percentage", 100, 0.0),
    ("fixed", 200, 0.0),
])
def test_apply_discount(discount_type, amount, expected):
    result = apply_discount(100, discount_type, amount)
    assert result == expected
```

### Factory Fixtures

```python
@pytest.fixture
def make_user(session):
    def _make_user(name="test", email=None, role="user"):
        email = email or f"{name}@example.com"
        user = User(name=name, email=email, role=role)
        session.add(user)
        session.commit()
        return user
    return _make_user

def test_admin_permissions(make_user):
    admin = make_user(name="admin", role="admin")
    assert admin.can("delete_users")

def test_regular_user_restrictions(make_user):
    user = make_user(name="regular", role="user")
    assert not user.can("delete_users")
```

### Mocking with pytest-mock

```python
def test_send_notification(mocker):
    mock_smtp = mocker.patch("app.notifications.smtplib.SMTP")
    send_welcome_email("user@example.com")
    mock_smtp.return_value.sendmail.assert_called_once()

def test_external_api_call(mocker):
    mocker.patch(
        "app.services.requests.get",
        return_value=mocker.Mock(status_code=200, json=lambda: {"data": "value"})
    )
    result = fetch_external_data()
    assert result == {"data": "value"}
```

### Async Testing

```python
import pytest

@pytest.mark.asyncio
async def test_async_fetch(aiohttp_client):
    client = await aiohttp_client(app)
    resp = await client.get("/api/data")
    assert resp.status == 200
    data = await resp.json()
    assert "items" in data

@pytest.mark.asyncio
async def test_concurrent_operations():
    results = await asyncio.gather(
        process_item("a"),
        process_item("b"),
        process_item("c"),
    )
    assert all(r.success for r in results)
```

## Anti-Patterns

1. **Global state between tests** — Tests modifying module-level variables create
   ordering dependencies. Use fixtures with function scope instead.

2. **Test interdependence** — Test B relying on side effects from Test A. Each test
   must set up its own state via fixtures.

3. **Over-mocking** — Mocking the system under test rather than its dependencies.
   Mock at boundaries, not at the core logic.

4. **Broad fixture scope without cleanup** — Session-scoped fixtures that accumulate
   state across tests. Always pair with proper teardown.

5. **Fixture overuse** — Simple values (strings, numbers) passed as fixtures instead
   of inline constants. Fixtures are for complex setup, not constants.

## Integration Points

- **Frameworks**: pytest-django (Django), pytest-flask (Flask), httpx/TestClient (FastAPI)
- **Workflows**: `test-framework` (initial setup), `test-automation` (coverage expansion)
- **Related fragments**: `fixture-architecture` (fixture design), `test-isolation` (isolation strategies)
