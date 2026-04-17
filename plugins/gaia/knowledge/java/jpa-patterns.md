---
name: JPA Entity and Repository Patterns
stack: java
version: "1.0"
focus: [jpa]
---

# JPA Entity and Repository Patterns

## Principle

Map entities to the database with explicit fetch strategies and avoid the N+1 query problem. Use Spring Data JPA repositories for standard CRUD, custom queries for complex operations, and projections for read-only data. Always define fetch types explicitly and prefer `FetchType.LAZY` as the default.

## Rationale

JPA's default fetch strategy for `@ManyToOne` is `EAGER`, which loads related entities immediately and causes cascading queries. The N+1 problem occurs when iterating a collection triggers one query per element. Explicit `LAZY` fetching, combined with `JOIN FETCH` in queries where related data is needed, gives precise control over SQL execution. Projections (interfaces or DTOs) avoid loading full entity graphs for read-only use cases.

## Pattern Examples

### Pattern 1: Entity with Explicit Fetch Strategies

```java
@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @Enumerated(EnumType.STRING)
    private OrderStatus status;

    // Explicit LAZY — loaded only when accessed or JOIN FETCHed
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private Customer customer;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItem> items = new ArrayList<>();

    // Helper method maintains bidirectional consistency
    public void addItem(OrderItem item) {
        items.add(item);
        item.setOrder(this);
    }

    public void removeItem(OrderItem item) {
        items.remove(item);
        item.setOrder(null);
    }
}
```

### Pattern 2: Solving N+1 with JOIN FETCH

```java
public interface OrderRepository extends JpaRepository<Order, Long> {

    // BAD: triggers N+1 when accessing order.customer for each order
    // List<Order> findByStatus(OrderStatus status);

    // GOOD: JOIN FETCH loads customers in one query
    @Query("""
        SELECT o FROM Order o
        JOIN FETCH o.customer
        WHERE o.status = :status
        """)
    List<Order> findByStatusWithCustomer(@Param("status") OrderStatus status);

    // Pagination with JOIN FETCH requires a count query
    @Query(value = """
        SELECT o FROM Order o
        JOIN FETCH o.customer
        WHERE o.status = :status
        """,
        countQuery = "SELECT COUNT(o) FROM Order o WHERE o.status = :status")
    Page<Order> findByStatusWithCustomerPaged(
        @Param("status") OrderStatus status, Pageable pageable);
}
```

### Pattern 3: DTO Projections for Read-Only Queries

```java
// Interface-based projection — JPA generates implementation
public interface OrderSummary {
    Long getId();
    LocalDateTime getCreatedAt();
    OrderStatus getStatus();
    String getCustomerName();  // derived from JOIN
}

public interface OrderRepository extends JpaRepository<Order, Long> {

    // Returns lightweight projections, not full entities
    @Query("""
        SELECT o.id AS id,
               o.createdAt AS createdAt,
               o.status AS status,
               c.name AS customerName
        FROM Order o JOIN o.customer c
        WHERE o.createdAt >= :since
        """)
    List<OrderSummary> findRecentOrderSummaries(
        @Param("since") LocalDateTime since);
}

// Record-based DTO projection (alternative)
public record OrderDto(Long id, String customerName, BigDecimal total) {}

@Query("""
    SELECT new com.example.dto.OrderDto(o.id, c.name, o.total)
    FROM Order o JOIN o.customer c
    WHERE o.status = :status
    """)
List<OrderDto> findOrderDtos(@Param("status") OrderStatus status);
```

## Anti-Patterns

- **Implicit EAGER fetching**: `@ManyToOne` defaults to `EAGER`. Always set `fetch = FetchType.LAZY`.
- **SELECT in a loop**: Iterating a list and calling `repository.findById()` per item. Use `findAllById()` or a batch query.
- **Returning entities from REST controllers**: Exposes internal structure, causes serialization issues with lazy proxies. Map to DTOs.
- **Missing `orphanRemoval`**: Without `orphanRemoval = true` on `@OneToMany`, removed children stay in the database.
- **`CascadeType.ALL` on `@ManyToOne`**: Cascading from child to parent can delete the parent when a child is removed.

## Integration Points

- **Spring Boot**: JPA auto-configuration sets up `EntityManager` and transaction management; see `spring-boot-patterns.md`.
- **Microservices**: Each service owns its database and entities; see `microservices.md` for bounded context.
- **Build Tools**: JPA metamodel generation requires annotation processing in Maven/Gradle; see `maven-gradle.md`.
- **Testing**: Use `@DataJpaTest` for repository tests with an in-memory database.
