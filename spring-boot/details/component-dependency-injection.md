## 🎯 Component & Dependency Injection – Expanded Sample Guide

[back](../annotation-cheat-sheet.md)

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

> **Each annotation is shown on its own, with a short description, a “why it matters” line, and a copy‑paste‑ready code snippet.**  
> All examples target Spring Boot 3.x (Java 17+), but the concepts apply to earlier releases as well.

---

### 1️⃣ `@Component`

**What it is**  
A generic stereotype marking any Spring bean.

**Why you’d use it**  
When the bean doesn’t fit a more specific role (service, repository, etc.) but you still want Spring to manage its lifecycle.

```java
@Component
public class CacheHelper {

    private final CacheManager cacheManager;

    public CacheHelper(CacheManager cacheManager) {
        this.cacheManager = cacheManager;
    }

    public void clearAll() {
        cacheManager.getCache("users").clear();
    }
}
```

> _You can now inject `CacheHelper` anywhere in your application._

---

### 2️⃣ `@Service`

**What it is**  
A stereotype for the business‑logic layer.

**Why you’d use it**  
Adds semantic meaning to the code and allows Spring AOP (e.g., `@Transactional`) to apply automatically.

```java
@Service
public class OrderService {

    private final OrderRepository orderRepo;
    private final NotificationService notificationService;

    public OrderService(OrderRepository orderRepo,
                        NotificationService notificationService) {
        this.orderRepo = orderRepo;
        this.notificationService = notificationService;
    }

    public Order create(OrderDto dto) {
        Order order = new Order(dto);
        Order saved = orderRepo.save(order);
        notificationService.notifyOrderCreated(saved);
        return saved;
    }
}
```

---

### 3️⃣ `@Repository`

**What it is**  
Stereotype for persistence/DAO beans.

**Why you’d use it**  
Spring automatically translates JDBC‑/JPA‑related checked exceptions into Spring’s unchecked `DataAccessException` hierarchy.

```java
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {
    // Spring Data JPA will create the implementation automatically
}
```

> _Because it’s an interface, no constructor is required—Spring Data creates the implementation._

---

### 4️⃣ `@Controller`

**What it is**  
Marks a Spring MVC controller (the original, pre‑Boot stereotype).

**Why you’d use it**  
When you want to return _views_ (Thymeleaf, JSP, etc.) rather than JSON, or you’re migrating a legacy MVC app into Boot.

```java
@Controller
public class PageController {

    @GetMapping("/home")
    public String home(Model model) {
        model.addAttribute("title", "Welcome Home");
        return "home";          // resolves to home.html (Thymeleaf) or home.jsp
    }
}
```

> _`@Controller` + `@ResponseBody` can be mixed manually, but for pure REST use `@RestController`._

---

### 5️⃣ `@RestController`

**What it is**  
A convenience stereotype that combines `@Controller` + `@ResponseBody`.

**Why you’d use it**  
All return values are serialized to JSON (or XML if you add `produces`) – perfect for REST APIs.

```java
@RestController
@RequestMapping("/api/orders")
public class OrderRestController {

    private final OrderService orderService;

    public OrderRestController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    public ResponseEntity<Order> create(@RequestBody OrderDto dto) {
        Order created = orderService.create(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @GetMapping("/{id}")
    public Order get(@PathVariable Long id) {
        return orderService.findById(id)
                           .orElseThrow(() -> new ResponseStatusException(
                               HttpStatus.NOT_FOUND, "Order not found"));
    }
}
```

---

### 6️⃣ `@Scope("prototype")`

**What it is**  
Configures a bean to be _prototype‑scoped_ – a new instance is created on every injection request.

**Why you’d use it**  
When the bean holds state that must not be shared (e.g., per‑request objects that are mutated).

```java
@Component
@Scope("prototype")
public class RequestScopedCounter {
    private int counter = 0;

    public void increment() { counter++; }
    public int get() { return counter; }
}
```

> **Injecting a prototype bean into a singleton causes the singleton to hold a reference to the _same_ instance.**  
> To ensure each usage gets a fresh instance, inject it via a factory method or use `ObjectProvider`:

```java
@Service
public class CounterService {

    private final ObjectProvider<RequestScopedCounter> counterProvider;

    public CounterService(ObjectProvider<RequestScopedCounter> counterProvider) {
        this.counterProvider = counterProvider;
    }

    public void process() {
        RequestScopedCounter counter = counterProvider.getObject(); // fresh instance
        counter.increment();
        System.out.println(counter.get());
    }
}
```

---

### 7️⃣ `@Autowired`

**What it is**  
Performs type‑based dependency injection (field, setter, or constructor).

**Why you’d use it**  
The classic way to wire beans automatically. Constructor injection (the default in Spring Boot) usually eliminates the need for this annotation, but it remains handy for **optional** or **setter‑only** injections.

```java
@Component
public class EmailSender {

    private final SmtpProperties smtpProps;

    @Autowired               // optional, but keeps the example explicit
    public EmailSender(SmtpProperties smtpProps) {
        this.smtpProps = smtpProps;
    }

    public void send(String to, String subject, String body) {
        // use smtpProps to configure the JavaMail session
    }
}
```

> _When you annotate a constructor, the `@Autowired` is optional in Boot; the annotation is still useful for clarity._

---

### 8️⃣ `@Qualifier`

**What it is**  
Specifies which bean to inject when multiple candidates of the same type exist.

**Why you’d use it**  
Avoids `NoUniqueBeanDefinitionException`. Use when you have several beans of the same interface.

```java
public interface PaymentProcessor {
    void process(Payment payment);
}

@Component("paypalProcessor")
public class PaypalProcessor implements PaymentProcessor { … }

@Component("stripeProcessor")
public class StripeProcessor implements PaymentProcessor { … }

@Service
public class PaymentService {

    private final PaymentProcessor processor;

    public PaymentService(@Qualifier("stripeProcessor") PaymentProcessor processor) {
        this.processor = processor;
    }
}
```

---

### 9️⃣ `@Inject`

**What it is**  
JSR‑330 (Java standard) equivalent of `@Autowired`.

**Why you’d use it**  
If you prefer standard annotations or are sharing code with non‑Spring projects that also use JSR‑330.

```java
@Component
public class InvoiceGenerator {

    private final TemplateEngine engine;

    @Inject
    public InvoiceGenerator(TemplateEngine engine) {
        this.engine = engine;
    }

    public String generate(Invoice invoice) { … }
}
```

---

### 🔟 `@Value`

**What it is**  
Injects a literal value from `application.yml` (or `application.properties`) or an expression.

**Why you’d use it**  
When you need a configuration value that isn’t part of a full `@ConfigurationProperties` group (simple flags, URLs, etc.).

```java
@Component
public class ExternalApiClient {

    @Value("${external.api.base-url}")
    private String baseUrl;

    @Value("${external.api.token:#{null}}")   // optional – defaults to null
    private String apiToken;

    public String getFullEndpoint(String path) {
        return UriComponentsBuilder.fromHttpUrl(baseUrl)
                .path(path)
                .toUriString();
    }
}
```

```java
// UUID (object)
@Value("#{T(java.util.UUID).randomUUID()}")              // java.util.UUID

// UUID string
@Value("#{T(java.util.UUID).randomUUID().toString()}")    // String

// Current date/time
@Value("#{T(java.time.LocalDateTime).now()}")             // LocalDateTime

// Current instant (epoch ms)
@Value("#{T(java.time.Instant).now().toEpochMilli()}")    // long

// Random double [0.0, 1.0)
@Value("#{T(java.lang.Math).random()}")                   // double

// Random int [min, max)
@Value("#{T(java.util.concurrent.ThreadLocalRandom).current().nextInt(10, 20)}") // int

// Random int via bean
@Value("#{random.nextInt(0, 100)}")                       // int (bean named 'random')

```

---

### 11️⃣ `@Lazy`

**What it is**  
Defers bean initialization until it is actually requested.

**Why you’d use it**  
Breaks circular dependencies, reduces startup time for heavy beans, or saves resources for beans that are rarely used.

```java
@Component
@Lazy
public class HeavyAnalyticsEngine {

    public HeavyAnalyticsEngine() {
        // long‑running initialization
    }

    public void analyze() { … }
}
```

> _Inject it as usual; the first call to `analyze()` triggers the bean’s creation._

---

### 12️⃣ `@Primary`

**What it is**  
Marks a bean as the default when the container finds multiple candidates.

**Why you’d use it**  
When you have two beans of the same type but one is the “default” you want Spring to pick automatically.

```java
@Component
@Primary
public class DefaultNotificationService implements NotificationService {
    public void notify(String msg) { … }
}

@Component
public class SmsNotificationService implements NotificationService {
    public void notify(String msg) { … }
}
```

> _Now `@Autowired NotificationService service` will inject `DefaultNotificationService` unless you explicitly use `@Qualifier`. _

---

### 🧩 Bonus: Putting It All Together

```java
// -------------------
//  Application Setup
// -------------------
@SpringBootApplication
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}

// -------------------
//  Repository
// -------------------
@Repository
public interface CustomerRepository extends JpaRepository<Customer, Long> {
    Optional<Customer> findByEmail(String email);
}

// -------------------
//  Service
// -------------------
@Service
public class CustomerService {

    private final CustomerRepository repo;
    private final NotificationService notifier; // injected via @Qualifier

    public CustomerService(CustomerRepository repo,
                           @Qualifier("emailNotifier") NotificationService notifier) {
        this.repo = repo;
        this.notifier = notifier;
    }

    public Customer register(CustomerDto dto) {
        Customer c = new Customer(dto);
        Customer saved = repo.save(c);
        notifier.notify("Customer registered: " + saved.getEmail());
        return saved;
    }
}

// -------------------
//  Notification – two implementations
// -------------------
@Component
@Qualifier("emailNotifier")
public class EmailNotificationService implements NotificationService {
    @Value("${mail.from}")
    private String from;

    @Override
    public void notify(String msg) {
        // send email using JavaMailSender
    }
}

@Component
@Qualifier("smsNotifier")
public class SmsNotificationService implements NotificationService {
    @Override
    public void notify(String msg) {
        // send SMS via Twilio
    }
}

// -------------------
//  Rest Controller
// -------------------
@RestController
@RequestMapping("/customers")
public class CustomerRestController {

    private final CustomerService service;
    private final ObjectProvider<RequestScopedCounter> counterProvider;

    public CustomerRestController(CustomerService service,
                                  ObjectProvider<RequestScopedCounter> counterProvider) {
        this.service = service;
        this.counterProvider = counterProvider;
    }

    @PostMapping
    public Customer create(@RequestBody CustomerDto dto) {
        Customer c = service.register(dto);

        // each call gets a brand‑new counter
        RequestScopedCounter counter = counterProvider.getObject();
        counter.increment();
        System.out.println("Counter value: " + counter.get());

        return c;
    }
}
```

> _This minimal example demonstrates all key stereotypes and injection mechanisms._

---

> **Final Note**  
> While most of the time you’ll rely on constructor injection (no annotation needed), the annotations above remain essential for advanced wiring patterns, configuration, and when you need finer control over bean scopes or selection.
