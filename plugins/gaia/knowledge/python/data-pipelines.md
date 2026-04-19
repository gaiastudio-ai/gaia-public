---
name: Data Pipeline Patterns
stack: python
version: "1.0"
focus: [data-pipelines]
---

# Data Pipeline Patterns

## Principle

Design pipelines as composable, idempotent stages: extract, transform, load. Use pandas for batch tabular processing, async I/O for concurrent data fetching, and chunked processing for large datasets that do not fit in memory. Choose batch vs. stream based on latency requirements, not data volume.

## Rationale

ETL pipelines are the backbone of data-driven applications. Composable stages make pipelines testable in isolation and rerunnable without side effects (idempotency). Pandas provides powerful vectorized operations but can consume excessive memory on large datasets; chunked reading and processing prevent OOM errors. Async I/O dramatically speeds up the extract phase when pulling from multiple sources concurrently.

## Pattern Examples

### Pattern 1: Chunked Pandas Processing

```python
import pandas as pd
from pathlib import Path
from typing import Iterator


def read_in_chunks(
    filepath: Path, chunk_size: int = 10_000
) -> Iterator[pd.DataFrame]:
    """Read large CSV in chunks to avoid memory exhaustion."""
    return pd.read_csv(
        filepath,
        chunksize=chunk_size,
        dtype={"user_id": str, "amount": float},
        parse_dates=["created_at"],
    )


def transform_chunk(df: pd.DataFrame) -> pd.DataFrame:
    """Apply transformations to a single chunk."""
    return (
        df
        .dropna(subset=["user_id", "amount"])
        .assign(
            amount_usd=lambda x: x["amount"] * x["exchange_rate"],
            month=lambda x: x["created_at"].dt.to_period("M"),
        )
        .query("amount_usd > 0")
    )


def run_pipeline(input_path: Path, output_path: Path) -> int:
    """Process file in chunks and write aggregated results."""
    results = []
    total_rows = 0

    for chunk in read_in_chunks(input_path):
        transformed = transform_chunk(chunk)
        aggregated = (
            transformed
            .groupby("month")
            .agg(total=("amount_usd", "sum"), count=("amount_usd", "size"))
            .reset_index()
        )
        results.append(aggregated)
        total_rows += len(transformed)

    final = pd.concat(results).groupby("month").sum().reset_index()
    final.to_parquet(output_path, index=False)
    return total_rows
```

### Pattern 2: Async Extract from Multiple APIs

```python
import asyncio
import httpx
from dataclasses import dataclass


@dataclass
class ExtractResult:
    source: str
    data: list[dict]
    record_count: int


async def fetch_source(
    client: httpx.AsyncClient, name: str, url: str
) -> ExtractResult:
    """Fetch data from a single API source."""
    response = await client.get(url, timeout=30.0)
    response.raise_for_status()
    data = response.json()["results"]
    return ExtractResult(source=name, data=data, record_count=len(data))


async def extract_all(sources: dict[str, str]) -> list[ExtractResult]:
    """Fetch from all sources concurrently."""
    async with httpx.AsyncClient() as client:
        tasks = [
            fetch_source(client, name, url)
            for name, url in sources.items()
        ]
        return await asyncio.gather(*tasks, return_exceptions=True)


# Usage
sources = {
    "users": "https://api.example.com/users",
    "orders": "https://api.example.com/orders",
    "products": "https://api.example.com/products",
}
results = asyncio.run(extract_all(sources))
```

### Pattern 3: Idempotent Load with Upsert

```python
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def upsert_records(
    session: AsyncSession,
    records: list[dict],
    table: str,
    conflict_key: str,
) -> int:
    """Idempotent upsert — safe to rerun without duplicates."""
    if not records:
        return 0

    columns = list(records[0].keys())
    col_list = ", ".join(columns)
    val_placeholders = ", ".join(f":{col}" for col in columns)
    update_set = ", ".join(
        f"{col} = EXCLUDED.{col}"
        for col in columns
        if col != conflict_key
    )

    query = text(f"""
        INSERT INTO {table} ({col_list})
        VALUES ({val_placeholders})
        ON CONFLICT ({conflict_key})
        DO UPDATE SET {update_set}
    """)

    await session.execute(query, records)
    await session.commit()
    return len(records)
```

## Anti-Patterns

- **Loading entire dataset into memory**: `pd.read_csv("huge.csv")` on a 10GB file. Use `chunksize` parameter or Dask for out-of-core processing.
- **Non-idempotent loads**: INSERT without conflict handling causes duplicate records on rerun. Always use upsert or delete-then-insert.
- **Sequential API calls**: Fetching 20 API sources one at a time when they are independent. Use `asyncio.gather` for concurrent extraction.
- **String concatenation for SQL**: Building queries with f-strings opens SQL injection risks. Use parameterized queries.
- **No error handling per stage**: A failure in transform should not require re-extracting. Checkpoint intermediate results.

## Integration Points

- **Django**: Management commands (`manage.py run_pipeline`) invoke pipeline stages; see `django-patterns.md`.
- **FastAPI**: API endpoints trigger pipeline runs or report status; see `fastapi-patterns.md`.
- **Python Conventions**: Type hints and project structure apply to pipeline code; see `python-conventions.md`.
- **Testing**: Test each stage independently with fixture data; verify idempotency by running load twice.
