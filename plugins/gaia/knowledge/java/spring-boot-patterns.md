---
name: Spring Boot Patterns
stack: java
version: "1.0"
focus: [spring-boot]
---

# Spring Boot Patterns

## Principle

Leverage Spring Boot's auto-configuration and convention-over-configuration philosophy. Use constructor injection for mandatory dependencies, profiles for environment-specific configuration, and Actuator for production observability. Structure applications in layers (controller, service, repository) with clear dependency direction.

## Rationale

Spring Boot eliminates boilerplate by auto-configuring beans based on classpath contents. Constructor injection makes dependencies explicit and immutable, and enables testing without the Spring container. Profiles allow the same codebase to run against different environments without code changes. Actuator provides production-ready health checks, metrics, and management endpoints with zero custom code.

## Pattern Examples

### Pattern 1: Layered Architecture with Constructor Injection

```java
// Controller — thin, delegates to service
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor  // Lombok generates constructor
public class UserController {

    private final UserService userService;

    @GetMapping
    public ResponseEntity<List<UserDto>> getAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        var users = userService.findAll(PageRequest.of(page, size));
        return ResponseEntity.ok(users.getContent());
    }

    @PostMapping
    public ResponseEntity<UserDto> create(@Valid @RequestBody CreateUserRequest request) {
        var user = userService.create(request);
        var uri = URI.create("/api/v1/users/" + user.id());
        return ResponseEntity.created(uri).body(user);
    }
}

// Service — business logic
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    public Page<UserDto> findAll(Pageable pageable) {
        return userRepository.findAll(pageable).map(userMapper::toDto);
    }

    @Transactional
    public UserDto create(CreateUserRequest request) {
        var entity = userMapper.toEntity(request);
        var saved = userRepository.save(entity);
        return userMapper.toDto(saved);
    }
}
```

### Pattern 2: Profile-Based Configuration

```yaml
# application.yml — common settings
spring:
  application:
    name: user-service
  jpa:
    open-in-view: false

---
# application-dev.yml
spring:
  config:
    activate:
      on-profile: dev
  datasource:
    url: jdbc:h2:mem:devdb
  jpa:
    show-sql: true

---
# application-prod.yml
spring:
  config:
    activate:
      on-profile: prod
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/users
  jpa:
    show-sql: false
```

```java
// Profile-conditional bean
@Configuration
public class CacheConfig {

    @Bean
    @Profile("prod")
    public CacheManager redisCacheManager(RedisConnectionFactory factory) {
        return RedisCacheManager.builder(factory).build();
    }

    @Bean
    @Profile("!prod")
    public CacheManager simpleCacheManager() {
        return new ConcurrentMapCacheManager("users");
    }
}
```

### Pattern 3: Actuator and Custom Health Indicator

```java
@Component
@RequiredArgsConstructor
public class DatabaseHealthIndicator implements HealthIndicator {

    private final DataSource dataSource;

    @Override
    public Health health() {
        try (var conn = dataSource.getConnection()) {
            if (conn.isValid(2)) {
                return Health.up()
                    .withDetail("database", "reachable")
                    .build();
            }
        } catch (SQLException e) {
            return Health.down()
                .withDetail("error", e.getMessage())
                .build();
        }
        return Health.down().build();
    }
}
```

## Anti-Patterns

- **Field injection with `@Autowired`**: Hides dependencies, prevents immutability, and complicates testing. Use constructor injection.
- **Business logic in controllers**: Controllers should validate input and delegate. Logic belongs in the service layer.
- **`spring.jpa.open-in-view=true` (default)**: Keeps DB sessions open during view rendering, causing lazy-loading surprises and connection pool exhaustion. Set to `false`.
- **Catching all exceptions in each controller method**: Use `@ControllerAdvice` with `@ExceptionHandler` for centralized error handling.

## Integration Points

- **JPA**: Repository layer uses Spring Data JPA; see `jpa-patterns.md` for entity mapping and query optimization.
- **Microservices**: Spring Boot apps are the unit of deployment; see `microservices.md` for service decomposition.
- **Build Tools**: Spring Boot plugin integrates with Maven/Gradle; see `maven-gradle.md`.
- **Testing**: Use `@SpringBootTest` for integration tests, plain JUnit for service unit tests.
