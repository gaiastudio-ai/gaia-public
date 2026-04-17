---
name: Django Application Patterns
stack: python
version: "1.0"
focus: [django]
---

# Django Application Patterns

## Principle

Leverage Django's "batteries included" philosophy: use the ORM for data access, class-based views (CBVs) for reusable view logic, DRF serializers for API contracts, middleware for cross-cutting concerns, and signals sparingly for decoupled event handling. Keep business logic in model methods or dedicated service modules, not in views.

## Rationale

Django's ORM, admin, and middleware system are deeply integrated. Fighting the framework (e.g., using raw SQL everywhere, avoiding CBVs) increases maintenance burden. CBVs with mixins enable code reuse across views. DRF serializers validate input, serialize output, and document the API shape in one place. Signals enable loose coupling but overuse makes control flow invisible.

## Pattern Examples

### Pattern 1: Model with Business Logic

```python
from django.db import models
from django.utils import timezone


class Order(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        CONFIRMED = "confirmed", "Confirmed"
        SHIPPED = "shipped", "Shipped"
        CANCELLED = "cancelled", "Cancelled"

    customer = models.ForeignKey(
        "customers.Customer",
        on_delete=models.PROTECT,
        related_name="orders",
    )
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.DRAFT
    )
    created_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "created_at"]),
        ]

    def confirm(self) -> None:
        if self.status != self.Status.DRAFT:
            raise ValueError(f"Cannot confirm order in {self.status} status")
        self.status = self.Status.CONFIRMED
        self.confirmed_at = timezone.now()
        self.save(update_fields=["status", "confirmed_at"])

    @property
    def total(self) -> Decimal:
        return sum(item.subtotal for item in self.items.all())
```

### Pattern 2: DRF Serializer and ViewSet

```python
from rest_framework import serializers, viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response


class OrderSerializer(serializers.ModelSerializer):
    total = serializers.DecimalField(read_only=True, max_digits=10, decimal_places=2)
    items = OrderItemSerializer(many=True, read_only=True)

    class Meta:
        model = Order
        fields = ["id", "customer", "status", "total", "items", "created_at"]
        read_only_fields = ["status", "created_at"]


class OrderViewSet(viewsets.ModelViewSet):
    queryset = Order.objects.select_related("customer").prefetch_related("items")
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return super().get_queryset().filter(customer__user=self.request.user)

    @action(detail=True, methods=["post"])
    def confirm(self, request, pk=None):
        order = self.get_object()
        try:
            order.confirm()
            return Response(self.get_serializer(order).data)
        except ValueError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
```

### Pattern 3: Custom Middleware

```python
import time
import logging

logger = logging.getLogger(__name__)


class RequestTimingMiddleware:
    """Logs request duration for performance monitoring."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        start = time.monotonic()
        response = self.get_response(request)
        duration_ms = (time.monotonic() - start) * 1000

        logger.info(
            "request_completed",
            extra={
                "method": request.method,
                "path": request.path,
                "status": response.status_code,
                "duration_ms": round(duration_ms, 2),
            },
        )
        response["X-Request-Duration-Ms"] = str(round(duration_ms, 2))
        return response
```

## Anti-Patterns

- **Business logic in views**: Views should validate input and delegate to model methods or service functions. Keep views thin.
- **Signal spaghetti**: Overusing signals makes control flow untraceable. Prefer explicit method calls; reserve signals for truly decoupled concerns (e.g., audit logging).
- **Missing `select_related`/`prefetch_related`**: Accessing related objects in loops without prefetching causes N+1 queries.
- **Raw SQL in views**: Use the ORM or at minimum `RawSQL` within the queryset API. Raw SQL bypasses Django's protections and is harder to maintain.
- **Fat serializers with nested writes**: Deeply nested writable serializers are fragile. Use separate endpoints for nested resources.

## Integration Points

- **FastAPI**: Django ORM can be used alongside FastAPI for async needs; see `fastapi-patterns.md`.
- **Data Pipelines**: Django management commands often serve as ETL entry points; see `data-pipelines.md`.
- **Python Conventions**: Follow PEP 8 and type hints throughout Django code; see `python-conventions.md`.
- **Testing**: Use `pytest-django` with fixtures and factory_boy for test data generation.
