---
name: junit5-patterns
tier: unit-testing
version: '1.0'
---

# JUnit 5 Patterns

## Principle

Strong typing enables compile-time test safety in Java. JUnit 5's extension model
and parameterized test support provide flexible, type-safe test composition. Combined
with Mockito and Spring test slices, it covers the full testing spectrum from unit
to integration.

## Rationale

Java's verbose syntax makes test readability a priority. JUnit 5's annotations,
@Nested classes for grouping, and @ParameterizedTest for data-driven tests reduce
boilerplate while maintaining clarity. Spring Boot's test slices load only necessary
context, keeping tests fast.

## Pattern Examples

### Basic Structure

```java
import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;

class PriceCalculatorTest {

    private PriceCalculator calculator;

    @BeforeEach
    void setUp() {
        calculator = new PriceCalculator();
    }

    @Test
    @DisplayName("applies percentage discount correctly")
    void appliesPercentageDiscount() {
        BigDecimal result = calculator.applyDiscount(
            new BigDecimal("100.00"),
            Discount.percentage(20)
        );
        assertThat(result).isEqualByComparingTo("80.00");
    }

    @Test
    @DisplayName("floors discount at zero")
    void floorsDiscountAtZero() {
        BigDecimal result = calculator.applyDiscount(
            new BigDecimal("10.00"),
            Discount.fixed(new BigDecimal("20.00"))
        );
        assertThat(result).isEqualByComparingTo("0.00");
    }
}
```

### Nested Groups and Parameterized Tests

```java
class UserServiceTest {
    @Nested @DisplayName("when creating a user")
    class CreateUser {
        @Test void savesUserToDatabase() { /* ... */ }
        @Test void sendsWelcomeEmail() { /* ... */ }
        @Test void rejectsDuplicateEmail() { /* ... */ }
    }
    @Nested @DisplayName("when deleting a user")
    class DeleteUser {
        @Test void removesFromDatabase() { /* ... */ }
        @Test void requiresAdminRole() { /* ... */ }
    }
}
```

```java
@ParameterizedTest
@CsvSource({
    "hello, HELLO",
    "Hello World, HELLO WORLD",
    "'', ''",
    "123abc, 123ABC"
})
void convertsToUpperCase(String input, String expected) {
    assertThat(input.toUpperCase()).isEqualTo(expected);
}

@ParameterizedTest
@MethodSource("provideInvalidEmails")
void rejectsInvalidEmails(String email) {
    assertThat(validator.isValid(email)).isFalse();
}

static Stream<String> provideInvalidEmails() {
    return Stream.of("invalid", "@example.com", "user@", "", null);
}
```

### Mockito Patterns

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {
    @Mock private OrderRepository orderRepository;
    @Mock private PaymentGateway paymentGateway;
    @InjectMocks private OrderService orderService;

    @Test
    void processesOrderSuccessfully() {
        when(paymentGateway.charge(any())).thenReturn(PaymentResult.success());
        Order order = orderService.placeOrder(new OrderRequest("item-1", 2));
        assertThat(order.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
        verify(orderRepository).save(order);
    }
}
```

### Testcontainers for Integration

```java
@Testcontainers
@SpringBootTest
class UserRepositoryIntegrationTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
        .withDatabaseName("testdb");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired private UserRepository userRepository;

    @Test
    void savesAndRetrievesUser() {
        userRepository.save(new User("Alice", "alice@example.com"));
        Optional<User> found = userRepository.findByEmail("alice@example.com");
        assertThat(found).isPresent();
    }
}
```

### Spring Boot Test Slices

```java
@WebMvcTest(UserController.class) // Only loads web layer
class UserControllerTest {
    @Autowired private MockMvc mockMvc;
    @MockBean private UserService userService;

    @Test
    void returnsUserById() throws Exception {
        when(userService.findById(1L)).thenReturn(new UserDto("Alice"));
        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Alice"));
    }
}

@DataJpaTest // Only loads JPA layer
class OrderRepositoryTest {
    @Autowired private TestEntityManager entityManager;
    @Autowired private OrderRepository orderRepository;

    @Test
    void findsByStatus() {
        entityManager.persist(new Order(OrderStatus.PENDING));
        assertThat(orderRepository.findByStatus(OrderStatus.PENDING)).hasSize(1);
    }
}
```

## Anti-Patterns

1. **Testing private methods** — If you need to test a private method, the class likely
   violates SRP. Extract the logic into a separate class and test its public API.

2. **Excessive mocking** — Mocking so many dependencies that the test validates nothing
   real. If a test has 5+ mocks, consider an integration test instead.

3. **Slow test suites** — Using @SpringBootTest for everything loads the full context.
   Use test slices (@WebMvcTest, @DataJpaTest) for focused, fast tests.

4. **Testing getters and setters** — Trivial code that cannot fail does not need tests.

5. **Ignoring test naming** — @DisplayName should describe the expected behavior,
   not the method name. "saves user" not "testSaveUser".

## Integration Points

- **Frameworks**: Spring Boot, JPA/Hibernate, Maven Surefire (unit), Failsafe (integration)
- **Workflows**: `test-framework` (initial setup), `test-automation` (coverage expansion)
- **Related fragments**: `fixture-architecture` (factory patterns), `test-isolation` (database isolation)
