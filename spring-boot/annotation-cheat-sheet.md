## 🎯 Annotation Cheat‑Sheet (Spring Boot)

[back](README.md)

> **TL;DR** – Annotations are the “magic glue” that wires a Spring Boot application together.  
> The list below is grouped by purpose; keep it handy as a quick reference.

---

### 1️⃣ **Configuration & Boot‑up**

[more](./details/configuration.md)

| Annotation                                    | What it does                                                                                                                                                 |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `@SpringBootApplication`                      | Marks the main class, enables component scanning, auto‑configuration, and property support (`@Configuration`, `@EnableAutoConfiguration`, `@ComponentScan`). |
| `@SpringBootConfiguration`                    | The same as `@Configuration` but with `@ComponentScan` + `@EnableAutoConfiguration`.                                                                         |
| `@EnableAutoConfiguration`                    | Tells Spring Boot to automatically configure beans based on the classpath and `application‑*` files.                                                         |
| `@ComponentScan`                              | Scans the current package (and subpackages) for Spring components.                                                                                           |
| `@Import`                                     | Imports additional configuration classes or beans.                                                                                                           |
| `@Bean`                                       | Declares a singleton bean in the application context.                                                                                                        |
| `@ConfigurationProperties`                    | Binds external properties (`application.yml`) to a POJO.                                                                                                     |
| `@PropertySource`                             | Adds an external `.properties` file to the environment.                                                                                                      |
| `@PropertySource("classpath:foo.properties")` | Loads a specific properties file.                                                                                                                            |
| `@ConditionalOn…` / `@Conditional`            | Conditional bean registration (e.g. `@ConditionalOnMissingBean`).                                                                                            |
| `@EnableAspectJAutoProxy`                     | Enables Spring AOP support (used under‑the‑hood by many starters).                                                                                           |

---

### 2️⃣ **Component & Dependency Injection**

[more](./details/component-dependency-injection.md)

| Annotation            | What it does                                                         |
| --------------------- | -------------------------------------------------------------------- |
| `@Component`          | Generic stereotype for a Spring bean.                                |
| `@Service`            | Stereotype for service-layer beans (business logic).                 |
| `@Repository`         | Stereotype for persistence beans; adds exception translation.        |
| `@Controller`         | Marks a Spring MVC controller (pre‑Spring Boot).                     |
| `@RestController`     | Combines `@Controller` + `@ResponseBody`; returns JSON/XML directly. |
| `@Scope("prototype")` | Creates a new bean instance each time it is injected.                |
| `@Autowired`          | Injects a bean by type (and qualifier if needed).                    |
| `@Qualifier`          | Resolves ambiguity when multiple beans of the same type exist.       |
| `@Inject`             | JSR‑330 equivalent of `@Autowired`.                                  |
| `@Value`              | Injects a property value (e.g. `@Value("${app.name}")`).             |
| `@Lazy`               | Defers bean creation until first use.                                |
| `@Primary`            | Gives a bean higher priority when autowiring multiple candidates.    |

---

### 3️⃣ **Web & MVC**

[more](./details/web-mvc.md)

| Annotation           | What it does                                                    |
| -------------------- | --------------------------------------------------------------- |
| `@RequestMapping`    | Maps HTTP requests to handler methods (class or method level).  |
| `@GetMapping`        | Shortcut for `@RequestMapping(method = GET)`.                   |
| `@PostMapping`       | Shortcut for `@RequestMapping(method = POST)`.                  |
| `@PutMapping`        | Shortcut for `@RequestMapping(method = PUT)`.                   |
| `@DeleteMapping`     | Shortcut for `@RequestMapping(method = DELETE)`.                |
| `@PatchMapping`      | Shortcut for `@RequestMapping(method = PATCH)`.                 |
| `@PathVariable`      | Binds a URI template variable to a method argument.             |
| `@RequestParam`      | Binds a query/form parameter to a method argument.              |
| `@RequestBody`       | Deserializes the HTTP body into a Java object.                  |
| `@ResponseBody`      | Serializes a method return value to the HTTP response.          |
| `@ResponseStatus`    | Sets a custom HTTP status code for a method or exception.       |
| `@CrossOrigin`       | Enables CORS for a controller or method.                        |
| `@ExceptionHandler`  | Handles exceptions thrown from controller methods.              |
| `@ControllerAdvice`  | Global exception handling / response advice across controllers. |
| `@ModelAttribute`    | Adds an attribute to the model (or binds a form object).        |
| `@SessionAttributes` | Persists model attributes in the HTTP session.                  |
| `@InitBinder`        | Configures data binding and validation for web requests.        |
| `@SessionScope`      | Creates a bean that lives in the HTTP session.                  |
| `@RequestScope`      | Creates a bean that lives per HTTP request.                     |

---

### 4️⃣ **Data & JPA**

| Annotation                                                | What it does                                                             |
| --------------------------------------------------------- | ------------------------------------------------------------------------ |
| `@Entity`                                                 | Marks a JPA entity.                                                      |
| `@Table`                                                  | Customizes the database table name.                                      |
| `@Id`                                                     | Designates the primary‑key field.                                        |
| `@GeneratedValue`                                         | Auto‑generates primary‑key values.                                       |
| `@Column`                                                 | Maps a field to a table column (with options like `nullable`, `length`). |
| `@ManyToOne` / `@OneToMany` / `@OneToOne` / `@ManyToMany` | Defines JPA relationships.                                               |
| `@JoinColumn`                                             | Specifies the foreign‑key column.                                        |
| `@JoinTable`                                              | Specifies a join table for many‑to‑many.                                 |
| `@Transient`                                              | Excludes a field from persistence.                                       |
| `@Version`                                                | Enables optimistic locking.                                              |
| `@Repository`                                             | Marks a DAO bean and triggers exception translation.                     |
| `@EnableJpaRepositories`                                  | Enables JPA repository support.                                          |
| `@Query`                                                  | Declares a custom JPQL/SQL query on a repository method.                 |
| `@Modifying`                                              | Indicates that a repository method performs an update/insert/delete.     |
| `@EntityListeners`                                        | Attaches listeners (e.g. `AuditingEntityListener`).                      |
| `@Audited`                                                | (Envers) Marks an entity for audit logging.                              |

---

### 4️⃣ **Inheritance**

| Annotation                                      | What it does                                                                                                            | Typical usage example (Spring Boot + JPA/Hibernate)                                  |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **`@Entity`**                                   | Declares a class as a JPA entity (required for every persistent class).                                                 | `@Entity`                                                                            |
| **`@MappedSuperclass`**                         | Marks a class whose fields are inherited by its subclasses but which is **not** an entity itself.                       | `@MappedSuperclass`                                                                  |
| **`@Inheritance`**                              | Specifies the inheritance strategy for the entity hierarchy.                                                            | `@Inheritance(strategy = InheritanceType.SINGLE_TABLE)`                              |
| **`InheritanceType` (enum)**                    | The three JPA‑defined strategies: `SINGLE_TABLE`, `JOINED`, `TABLE_PER_CLASS`.                                          | N/A (used inside `@Inheritance`)                                                     |
| **`@DiscriminatorColumn`**                      | Defines the column used to store the discriminator value when using `SINGLE_TABLE`.                                     | `@DiscriminatorColumn(name = "dtype", discriminatorType = DiscriminatorType.STRING)` |
| **`@DiscriminatorValue`**                       | Assigns a specific discriminator value to a concrete subclass.                                                          | `@DiscriminatorValue("EMP")`                                                         |
| **`@DiscriminatorFormula`** _(Hibernate‑only)_  | Allows the discriminator to be computed with a SQL expression instead of a column.                                      | `@DiscriminatorFormula("case when type=1 then 'A' else 'B' end")`                    |
| **`@PrimaryKeyJoinColumn`** _(JOINED strategy)_ | Specifies the join column for a subclass that uses the `JOINED` strategy (usually the same as the parent PK).           | `@PrimaryKeyJoinColumn(name = "id")`                                                 |
| **`@Polymorphism`** _(Hibernate‑only)_          | Controls whether queries against a superclass are polymorphic or not.                                                   | `@Polymorphism(type = PolymorphismType.EXPLICIT)`                                    |
| **`@Where`** _(Hibernate‑only)_                 | Adds a SQL clause that is applied to all queries for that entity, useful for soft‑deleting or filtering inherited rows. | `@Where(clause = "deleted_at IS NULL")`                                              |

> **Quick checklist for a `SINGLE_TABLE` hierarchy in Spring Boot:**
>
> 1. Mark the root class with `@Entity` + `@Inheritance(strategy = InheritanceType.SINGLE_TABLE)`.
> 2. (Optional) Define a discriminator column with `@DiscriminatorColumn`.
> 3. On each concrete subclass, use `@DiscriminatorValue`.
> 4. Add `@Entity` to every subclass.
>
> **For a `JOINED` hierarchy:**
>
> 1. Root: `@Entity` + `@Inheritance(strategy = InheritanceType.JOINED)`.
> 2. Each subclass: `@Entity` + `@PrimaryKeyJoinColumn` (if you want a custom name).

---

### 5️⃣ **Validation**

[more](./details/validation.md)

| Annotation                                                        | What it does                                                  |
| ----------------------------------------------------------------- | ------------------------------------------------------------- |
| `@Valid`                                                          | Triggers validation on a method argument or bean.             |
| `@Validated`                                                      | Same as `@Valid` but allows group validation on method level. |
| `@NotNull`                                                        | Value must not be `null`.                                     |
| `@NotBlank`                                                       | String must not be `null` and must contain non‑whitespace.    |
| `@NotEmpty`                                                       | Collection/array/CharSequence must not be empty.              |
| `@Size(min=, max=)`                                               | Enforces length bounds.                                       |
| `@Min` / `@Max`                                                   | Numeric range.                                                |
| `@Email`                                                          | Valid email format.                                           |
| `@Pattern(regexp=)`                                               | Regex validation.                                             |
| `@Past` / `@Future`                                               | Date/time constraints.                                        |
| `@AssertTrue` / `@AssertFalse`                                    | Boolean property must be true/false.                          |
| `@Positive` / `@PositiveOrZero` / `@Negative` / `@NegativeOrZero` | Numeric sign constraints.                                     |
| `@DecimalMin` / `@DecimalMax`                                     | Decimal bounds.                                               |

---

### 6️⃣ **Security**

[more](./details/security.md)

| Annotation                                             | What it does                                                                   |
| ------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `@EnableWebSecurity`                                   | Activates Spring Security’s web security support.                              |
| `@Configuration` + `@EnableWebSecurity`                | Customizes security configuration via `WebSecurityConfigurerAdapter`.          |
| `@EnableGlobalMethodSecurity`                          | Enables method‑level security (`@PreAuthorize`, `@PostAuthorize`, `@Secured`). |
| `@PreAuthorize("hasRole('ADMIN')")`                    | Authorizes based on SpEL expressions.                                          |
| `@Secured("ROLE_ADMIN")`                               | Authorizes based on roles.                                                     |
| `@RolesAllowed("ADMIN")`                               | JSR‑250 role‑based authorization.                                              |
| `@AuthenticationPrincipal`                             | Injects the current `UserDetails` into a controller method.                    |
| `@WithMockUser`                                        | Mocks an authenticated user in tests.                                          |
| `@SecurityConfigurerAdapter`                           | Custom security filter configuration.                                          |
| `@EnableOAuth2Client`                                  | Enables OAuth2 client support (deprecated in Spring 6).                        |
| `@EnableAuthorizationServer` / `@EnableResourceServer` | Deprecated; use Spring Authorization Server & Resource Server.                 |

---

### 7️⃣ **Actuator & Monitoring**

| Annotation              | What it does                                                     |
| ----------------------- | ---------------------------------------------------------------- |
| `@Endpoint`             | Declares a custom Actuator endpoint.                             |
| `@ReadOperation`        | Handles HTTP GET on the endpoint.                                |
| `@WriteOperation`       | Handles HTTP POST/PATCH/DELETE on the endpoint.                  |
| `@HealthIndicator`      | Provides custom health checks.                                   |
| `@Timed`                | Records execution time of a method (Micrometer).                 |
| `@Counted`              | Records the number of times a method is invoked.                 |
| `@Metered`              | Generalized metrics collection.                                  |
| `@EnableCircuitBreaker` | Enables Hystrix‑style circuit breaking (deprecated in Spring 6). |
| `@EnableRetry`          | Enables retry logic for annotated methods.                       |

---

### 8️⃣ **Messaging (Spring AMQP / Kafka / JMS)**

[more](./details/messaging.md)

| Annotation                          | What it does                                                           |
| ----------------------------------- | ---------------------------------------------------------------------- |
| `@EnableRabbit`                     | Enables RabbitMQ listener infrastructure.                              |
| `@RabbitListener(queues = "foo")`   | Marks a method to receive messages from a Rabbit queue.                |
| `@EnableKafka`                      | Enables Kafka listener infrastructure.                                 |
| `@KafkaListener(topics = "foo")`    | Marks a method to consume Kafka messages.                              |
| `@EnableJms`                        | Enables JMS listener infrastructure.                                   |
| `@JmsListener(destination = "foo")` | Marks a method to receive JMS messages.                                |
| `@EnablePulsar`                     | Enables Pulsar listener infrastructure (Spring Boot 3.2+).             |
| `@PulsarClient` / `@PulsarListener` | Pulsar consumer / producer annotations.                                |
| `@Transactional`                    | Wraps message handling in a transaction (e.g. AMQP “transacted” mode). |

---

### 9️⃣ **Testing**

[more](./details/testing.md)

| Annotation                      | What it does                                              |
| ------------------------------- | --------------------------------------------------------- |
| `@SpringBootTest`               | Boots the full application context for integration tests. |
| `@WebMvcTest`                   | Loads only the web layer (controllers, MVC config).       |
| `@DataJpaTest`                  | Loads JPA components and an in‑memory DB.                 |
| `@AutoConfigureMockMvc`         | Adds a `MockMvc` bean for MVC tests.                      |
| `@MockBean`                     | Replaces a bean in the context with a Mockito mock.       |
| `@TestConfiguration`            | Adds test‑specific bean configuration.                    |
| `@Transactional`                | Rolls back transactions after each test method.           |
| `@DirtiesContext`               | Marks the context as dirty so it gets recreated.          |
| `@Sql(scripts = "/schema.sql")` | Executes SQL scripts before a test.                       |
| `@SqlGroup`                     | Groups multiple `@Sql` annotations.                       |
| `@ActiveProfiles("test")`       | Activates the `application‑test.yml` profile.             |
| `@MockBean(name="myBean")`      | Creates a named mock.                                     |
| `@WithMockUser`                 | Provides a fake authenticated user (security tests).      |
| `@MockRestServiceServer`        | Mocks a REST client’s HTTP calls.                         |

---

### 🔟 **Miscellaneous / Advanced**

| Annotation                                         | What it does                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------- |
| `@EventListener`                                   | Handles Spring application events.                                  |
| `@Async`                                           | Executes a method asynchronously (using `@EnableAsync`).            |
| `@ConfigurationPropertiesBinding`                  | Custom conversion for `@ConfigurationProperties`.                   |
| `@LazyInit`                                        | (Spring Boot 2.7+) Lazy initialization of configuration properties. |
| `@Profile`                                         | Activates beans only for a given profile.                           |
| `@Order`                                           | Sets the order of filters, interceptors, or component scans.        |
| `@Bean(initMethod = "...", destroyMethod = "...")` | Specifies init/destroy callbacks.                                   |
| `@Scheduled`                                       | Schedules a method to run at fixed intervals (Spring Scheduling).   |
| `@SchedulerLock`                                   | (Resilience4j) Locks a scheduled task across a cluster.             |
| `@TransactionalEventListener`                      | Handles domain events within a transaction context.                 |

---

## 📌 Key Takeaways

- **Most of the annotations above are _stereotypes_** (e.g. `@Service`, `@Repository`) that simply declare a component’s role.
- **Configuration annotations** (`@Configuration`, `@Import`, `@Bean`, etc.) build the application context.
- **Web annotations** are mostly method‑level (`@GetMapping`, `@PostMapping`, etc.) for REST controllers.
- **Data annotations** map domain objects to the database and expose CRUD via Spring Data JPA.
- **Validation** is a combination of Bean Validation (JSR‑380) annotations and `@Valid`/`@Validated`.
- **Security** relies heavily on method‑level annotations for fine‑grained access control.
- **Actuator** and **metrics** annotations (`@HealthIndicator`, `@Timed`) enable runtime monitoring.
- **Messaging** (RabbitMQ, Kafka, JMS) uses `@RabbitListener`, `@KafkaListener`, etc. to process messages.

---

### 🎯 Bottom‑Line

In Spring Boot you rarely write these annotations from scratch—most are **provided by starters** (e.g. `spring‑boot‑starter‑web`, `spring‑boot‑starter‑data‑jpa`, `spring‑boot‑starter‑amqp`).  
But understanding what each annotation does gives you **fine‑grained control** when you need to override default behaviour, create custom endpoints, or build complex, testable applications.
