---
name: Microservices Patterns
stack: java
version: "1.0"
focus: [microservices]
---

# Microservices Patterns

## Principle

Decompose systems along bounded context boundaries. Each service owns its data, communicates via well-defined APIs (sync) or events (async), and is independently deployable. Use circuit breakers for resilience, saga pattern for distributed transactions, and service discovery for dynamic routing.

## Rationale

Microservices enable independent scaling, deployment, and technology choices per bounded context. However, distributed systems introduce network failures, data consistency challenges, and operational complexity. Circuit breakers prevent cascading failures by failing fast when a downstream service is unhealthy. The saga pattern replaces distributed transactions with a sequence of local transactions and compensating actions. Service discovery eliminates hard-coded URLs.

## Pattern Examples

### Pattern 1: Circuit Breaker with Resilience4j

```java
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentClient paymentClient;

    @CircuitBreaker(name = "payment", fallbackMethod = "paymentFallback")
    @TimeLimiter(name = "payment")
    @Retry(name = "payment")
    public CompletableFuture<PaymentResult> processPayment(PaymentRequest request) {
        return CompletableFuture.supplyAsync(
            () -> paymentClient.charge(request)
        );
    }

    private CompletableFuture<PaymentResult> paymentFallback(
            PaymentRequest request, Throwable ex) {
        log.warn("Payment service unavailable, queuing: {}", ex.getMessage());
        return CompletableFuture.completedFuture(
            PaymentResult.queued(request.orderId())
        );
    }
}

// application.yml
// resilience4j:
//   circuitbreaker:
//     instances:
//       payment:
//         sliding-window-size: 10
//         failure-rate-threshold: 50
//         wait-duration-in-open-state: 30s
//   retry:
//     instances:
//       payment:
//         max-attempts: 3
//         wait-duration: 500ms
```

### Pattern 2: Saga Pattern (Orchestration)

```java
// Saga orchestrator — coordinates local transactions across services
@Service
@RequiredArgsConstructor
public class OrderSagaOrchestrator {

    private final OrderService orderService;
    private final InventoryClient inventoryClient;
    private final PaymentClient paymentClient;

    @Transactional
    public OrderResult createOrder(CreateOrderCommand cmd) {
        // Step 1: Create order (local transaction)
        var order = orderService.create(cmd);

        try {
            // Step 2: Reserve inventory (remote call)
            inventoryClient.reserve(order.getId(), cmd.items());

            try {
                // Step 3: Process payment (remote call)
                paymentClient.charge(order.getId(), cmd.total());
                orderService.confirm(order.getId());
                return OrderResult.success(order);

            } catch (PaymentException e) {
                // Compensate Step 2
                inventoryClient.release(order.getId());
                orderService.cancel(order.getId(), "Payment failed");
                return OrderResult.failed(order, e.getMessage());
            }
        } catch (InventoryException e) {
            // Compensate Step 1
            orderService.cancel(order.getId(), "Insufficient inventory");
            return OrderResult.failed(order, e.getMessage());
        }
    }
}
```

### Pattern 3: Event-Driven Communication

```java
// Publishing domain events
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public Order confirm(Long orderId) {
        var order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));
        order.setStatus(OrderStatus.CONFIRMED);
        var saved = orderRepository.save(order);

        // Publish event — listeners can be in-process or forward to Kafka
        eventPublisher.publishEvent(new OrderConfirmedEvent(
            saved.getId(), saved.getCustomerId(), saved.getTotal()
        ));
        return saved;
    }
}

// Event listener — async processing
@Component
@RequiredArgsConstructor
public class NotificationListener {

    private final NotificationService notificationService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async
    public void onOrderConfirmed(OrderConfirmedEvent event) {
        notificationService.sendOrderConfirmation(
            event.customerId(), event.orderId()
        );
    }
}
```

## Anti-Patterns

- **Distributed monolith**: Splitting a monolith into services that still share a database or require synchronous calls for every operation.
- **Two-phase commit across services**: Distributed transactions do not scale. Use sagas with compensating actions instead.
- **Chatty inter-service calls**: Multiple fine-grained synchronous calls per request. Batch calls or use async events.
- **Shared domain models**: Services sharing entity JARs creates tight coupling. Each service defines its own models.

## Integration Points

- **Spring Boot**: Each microservice is a Spring Boot application; see `spring-boot-patterns.md`.
- **JPA**: Each service owns its database schema; see `jpa-patterns.md` for per-service data modeling.
- **Build Tools**: Multi-module Maven/Gradle builds manage microservice projects; see `maven-gradle.md`.
- **Docker**: Services are containerized for deployment; integrate with Docker Compose or Kubernetes.
