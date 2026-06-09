## Spring Boot

[back](../README.md)

[Spring Boot Starter](./details/spring-boot-starter.md)

[Annotation Cheat Sheet](annotation-cheat-sheet.md)

[JDBC](./details/jdbc.md)

[JPA](./details/jpa.md)

[Transaction](./details/transaction.md)

[HttpServletRequest-HttpServletResponse](./details/servlet-request-response.md)

[@EventListener](./details/event-listener.md)

[Caching](./details/cache.md)

[AOP](./details/aop.md)

[Jackson Annotation](./details/jackson-json.md)

[OpenFeign](./details/open-feign.md)

[TransactionTemplate - RabbitTemplate](./details/transactional-jdbc-rabbit.md)

[Outbox Pattern](./details/outbox-pattern.md)

[Keycloak](./details/keycloak.md)

[Dockerize](./details/dockerize.md)

Here’s a **practical "must-know" code snippet** for each topic in the suggested order. These are the minimal, high-yield patterns you should be able to write from memory.

---

## 1. Spring Boot Starter

[Spring Boot Starter](./details/spring-boot-starter.md)

```java
@SpringBootApplication
public class MyApp {
    public static void main(String[] args) {
        SpringApplication.run(MyApp.class, args);
    }
}
```

**Must-know:** `@SpringBootApplication` = `@Configuration` + `@EnableAutoConfiguration` + `@ComponentScan`

---

## 2. Annotation Cheat Sheet

[Annotation Cheat Sheet](annotation-cheat-sheet.md)

```java
@Service
@Slf4j
public class UserService {
    @Autowired
    private UserRepository repo;

    @Value("${app.max-users:100}")
    private int maxUsers;

    @PostConstruct
    public void init() { log.info("Service ready"); }
}
```

**Must-know:** `@Autowired` (constructor injection preferred), `@PostConstruct`, `@Value` with defaults

---

## 3. JDBC

[JDBC](./details/jdbc.md)

```java
@Repository
public class UserJdbcRepo {
    private final JdbcTemplate jdbc;

    public UserJdbcRepo(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public User findById(Long id) {
        return jdbc.queryForObject(
            "SELECT * FROM users WHERE id = ?",
            (rs, rowNum) -> new User(rs.getLong("id"), rs.getString("name")),
            id
        );
    }
}
```

**Must-know:** `JdbcTemplate` row mapper, exception translation to `DataAccessException`

---

## 4. JPA

[JPA](./details/jpa.md)

```java
@Entity
@Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @OneToMany(mappedBy = "user", fetch = FetchType.LAZY, cascade = CascadeType.ALL)
    private List<Order> orders = new ArrayList<>();
}

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);  // derived query
    @Query("SELECT u FROM User u JOIN FETCH u.orders WHERE u.id = :id")
    Optional<User> findByIdWithOrders(@Param("id") Long id);
}
```

**Must-know:** LAZY vs EAGER, `JOIN FETCH` to solve N+1, `CascadeType`

---

## 5. Transaction

[Transaction](./details/transaction.md)

```java
@Service
public class OrderService {
    @Transactional(
        propagation = Propagation.REQUIRED,
        isolation = Isolation.READ_COMMITTED,
        rollbackFor = {CustomException.class},
        noRollbackFor = {OptimisticLockException.class}
    )
    public void processOrder(Order order) {
        // multiple DB operations, all commit or rollback together
    }

    @Transactional(readOnly = true)
    public Order findOrder(Long id) { ... }
}
```

**Must-know:** `REQUIRED` (default), `readOnly` optimization, what triggers rollback (RuntimeException by default)

---

## 6. HttpServletRequest / HttpServletResponse

[HttpServletRequest-HttpServletResponse](./details/servlet-request-response.md)

```java
@RestController
public class UserController {
    @GetMapping("/users/{id}")
    public void getUser(@PathVariable Long id,
                        HttpServletRequest request,
                        HttpServletResponse response) throws IOException {
        String authHeader = request.getHeader("Authorization");
        response.setHeader("X-Request-Id", UUID.randomUUID().toString());
        response.setStatus(HttpStatus.OK.value());
        response.getWriter().write("user data");
    }
}
```

**Must-know:** Reading headers, writing custom response headers, setting status codes

---

## 7. @EventListener

[@EventListener](./details/event-listener.md)

```java
@Component
public class AuditListener {
    @EventListener(condition = "#event.success == true")
    @Async  // needs @EnableAsync on config class
    public void handleUserCreated(UserCreatedEvent event) {
        System.out.println("User created: " + event.getEmail());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void afterTxCommit(OrderPlacedEvent event) {
        // only fires if transaction commits
    }
}
```

**Must-know:** Sync vs async, `@TransactionalEventListener` phase options

---

## 8. Caching

[Caching](./details/cache.md)

```java
@Service
@CacheConfig(cacheNames = "products")
public class ProductService {
    @Cacheable(key = "#id", unless = "#result.price < 1000")
    public Product findById(Long id) { ... }

    @CacheEvict(key = "#id", condition = "#result != null")
    public Product update(Long id, ProductDto dto) { ... }

    @CacheEvict(allEntries = true, beforeInvocation = true)
    public void clearCache() { ... }
}
```

**Must-know:** `@Cacheable`, `@CacheEvict`, `unless`/`condition`, when to use `beforeInvocation`

---

## 9. AOP

[AOP](./details/aop.md)

```java
@Aspect
@Component
public class LoggingAspect {
    @Around("@annotation(com.example.MeasureTime)")
    public Object measureTime(ProceedingJoinPoint joinPoint) throws Throwable {
        long start = System.currentTimeMillis();
        Object result = joinPoint.proceed();
        long duration = System.currentTimeMillis() - start;
        System.out.println(joinPoint.getSignature() + " took " + duration + "ms");
        return result;
    }

    @Before("execution(* com.example..*Service.*(..))")
    public void logBefore(JoinPoint jp) { ... }
}
```

**Must-know:** `@Around` vs `@Before`/`@After`, `ProceedingJoinPoint`, pointcut expressions

---

## 10. Jackson Annotations

[Jackson Annotation](./details/jackson-json.md)

```java
public class UserDto {
    @JsonProperty(access = Access.READ_ONLY)
    private Long id;

    @JsonIgnore
    private String internalPassword;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime createdAt;

    @JsonUnwrapped
    private Address address;

    @JsonView(Views.Public.class)
    private String name;
}
```

**Must-know:** `@JsonProperty` for rename/read-only, `@JsonIgnore`, `@JsonFormat`

---

## 11. OpenFeign

[OpenFeign](./details/open-feign.md)

```java
@FeignClient(name = "payment-service", url = "${payment.api.url}")
public interface PaymentClient {
    @PostMapping("/payments")
    PaymentResponse process(@RequestBody PaymentRequest request,
                            @RequestHeader("X-Idempotency-Key") String idempotencyKey);

    @GetMapping("/payments/{id}")
    PaymentStatus getStatus(@PathVariable Long id);
}

// With custom error decoder
@Configuration
public class FeignConfig {
    @Bean
    public ErrorDecoder errorDecoder() {
        return (methodKey, response) -> {
            if (response.status() == 404) return new NotFoundException();
            return new RuntimeException("API error");
        };
    }
}
```

**Must-know:** `@FeignClient`, `@RequestBody`, `@RequestHeader`, error handling

---

## 12. TransactionTemplate – RabbitTemplate

[TransactionTemplate - RabbitTemplate](./details/transactional-jdbc-rabbit.md)

```java
@Service
public class PaymentService {
    private final TransactionTemplate txTemplate;
    private final RabbitTemplate rabbitTemplate;

    @Autowired
    public PaymentService(PlatformTransactionManager tm, RabbitTemplate rt) {
        this.txTemplate = new TransactionTemplate(tm);
        this.rabbitTemplate = rt;
    }

    public void processPayment(Payment p) {
        txTemplate.executeWithoutResult(status -> {
            // DB operations
            paymentRepo.save(p);

            // Publish message (won't send if transaction fails)
            rabbitTemplate.convertAndSend("payment.exchange", "payment.route",
                                          new PaymentEvent(p.getId()));
        });
    }
}
```

**Must-know:** `TransactionTemplate` for programmatic tx, `RabbitTemplate` publish/subscribe, **transactional channel** (message only sends on commit)

---

## 13. Outbox Pattern

[Outbox Pattern](./details/outbox-pattern.md)

```java
@Entity
public class OutboxEvent {
    @Id @GeneratedValue private Long id;
    private String aggregateType;  // e.g., "Order"
    private String aggregateId;
    private String eventType;       // e.g., "OrderCreated"
    private String payload;         // JSON
    private LocalDateTime createdAt;
    private LocalDateTime publishedAt;
}

@Component
public class OutboxPoller {
    @Scheduled(fixedDelay = 5000)
    @Transactional
    public void publishEvents() {
        List<OutboxEvent> pending = outboxRepo.findByPublishedAtIsNull();
        for (OutboxEvent event : pending) {
            rabbitTemplate.convertAndSend("outbox", event.getPayload());
            event.setPublishedAt(LocalDateTime.now());
            outboxRepo.save(event);
        }
    }
}
```

**Must-know:** Save event in same DB tx as business data, poller or CDC, idempotent consumers

---

## 14. Keycloak

[Keycloak](./details/keycloak.md)

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.oauth2ResourceServer(oauth2 -> oauth2
            .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtConverter()))
        );
        return http.build();
    }
}

@RestController
public class OrderController {
    @GetMapping("/orders/{id}")
    @PreAuthorize("hasRole('ADMIN') or #id == authentication.name")
    public Order getOrder(@PathVariable String userId) { ... }

    @PreAuthorize("hasAuthority('SCOPE_write')")
    @PostMapping("/orders")
    public Order create(@RequestBody Order order) { ... }
}
```

**Must-know:** OAuth2 resource server setup, `@PreAuthorize` with roles/scopes, extracting user info from JWT

---

## 15. Dockerize

[Dockerize](./details/dockerize.md)

```dockerfile
# Multi-stage build
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app
COPY . .
RUN ./gradlew bootJar

FROM eclipse-temurin:21-jre
COPY --from=builder /app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

```yaml
# docker-compose.yml
version: "3.8"
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://db:5432/mydb
      SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: http://keycloak:8080/realms/myrealm
    depends_on:
      - db
      - keycloak

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: mydb
      POSTGRES_PASSWORD: secret

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
```

**Must-know:** Multi-stage builds, environment variables for configuration, `depends_on` for startup order

---

## Bean Scope and Lifecycle

In Spring Boot, **bean scope** defines the lifecycle and visibility of a bean within the container.

### Common Scopes:

- **Singleton** (default): One instance per Spring container. Shared across the whole app.
- **Prototype**: New instance every time requested.
- **Request**: One bean per HTTP request (web apps only). `@Scope("request"), @RequestScope`(use `@RequestScope`)
- **Session**: One bean per HTTP session.
- **Application**: One bean per `ServletContext`.

### Lifecycle (simplified):

1. **Instantiate** – Constructor called.
2. **Populate properties** – Dependencies injected (`@Autowired`).
3. **BeanNameAware / BeanFactoryAware** – Optional: bean gets its name or factory.
4. **`@PostConstruct`** – Custom init method runs.
5. **Bean ready for use**.
6. **`@PreDestroy`** – Called before container shutdown (for cleanup).

Only **singleton** beans go through the full lifecycle; **prototype** beans don't run destruction callbacks unless manually handled.

---
