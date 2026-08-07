## ScopedValue

[back](./README.md)

With **virtual threads** in Spring Boot, `ThreadLocal` can be problematic because virtual threads are pooled differently and can be pinned. **`ScopedValue`** (introduced in Java 20, finalized in Java 21+) is the modern replacement for `ThreadLocal` when using virtual threads.

## Why ScopedValue Over ThreadLocal with Virtual Threads?

| Feature                | ThreadLocal                 | ScopedValue                   |
| ---------------------- | --------------------------- | ----------------------------- |
| Virtual thread support | Can cause pinning issues    | Fully compatible              |
| Inheritance            | InheritableThreadLocal      | Structured inheritance        |
| Mutation               | Can be modified anywhere    | Immutable within scope        |
| Memory leak risk       | High (manual cleanup)       | Low (automatic cleanup)       |
| Performance            | Slower with virtual threads | Optimized for virtual threads |

## Complete ScopedValue Example for Request Context

### 1. Define Your ScopedValue Context

```java
import java.lang.ScopedValue;
import java.util.UUID;

public class RequestContext {
    // Define ScopedValue for each piece of context data
    public static final ScopedValue<String> REQUEST_ID =
        ScopedValue.newInstance();

    public static final ScopedValue<UserContext> CURRENT_USER =
        ScopedValue.newInstance();

    public static final ScopedValue<String> TENANT_ID =
        ScopedValue.newInstance();

    public static final ScopedValue<Map<String, Object>> ATTRIBUTES =
        ScopedValue.newInstance();

    // Helper to create a context map
    public static record ContextData(
        String requestId,
        UserContext user,
        String tenantId
    ) {}
}
```

### 2. Create the ScopedValue Filter

```java
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.util.UUID;

@Component
public class ScopedValueFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) {

        // Extract data from request
        String requestId = UUID.randomUUID().toString();
        UserContext user = extractUserFromToken(request);
        String tenantId = request.getHeader("X-Tenant-ID");

        // CRITICAL: Run with ScopedValue bindings
        // The data is ONLY available within this scope
        ScopedValue.where(RequestContext.REQUEST_ID, requestId)
            .and(RequestContext.CURRENT_USER, user)
            .and(RequestContext.TENANT_ID, tenantId)
            .and(RequestContext.ATTRIBUTES, new HashMap<>())
            .run(() -> {
                try {
                    // All processing happens inside this scope
                    // The context is automatically available to all methods
                    filterChain.doFilter(request, response);
                } catch (Exception e) {
                    // Handle exceptions
                    throw new RuntimeException(e);
                }
                // NO MANUAL CLEANUP NEEDED!
                // ScopedValue automatically removes bindings when scope exits
            });

        // After this point, the ScopedValue values are NOT accessible
    }

    private UserContext extractUserFromToken(HttpServletRequest request) {
        // Extract user from JWT or session
        String token = request.getHeader("Authorization");
        // ... parse token
        return new UserContext("user123", "john@example.com", "ADMIN");
    }
}
```

### 3. Access Request Context Anywhere

```java
import org.springframework.stereotype.Service;

@Service
public class OrderService {

    public void processOrder(Order order) {
        // Access ScopedValue directly - NO passing parameters!
        String requestId = RequestContext.REQUEST_ID.get();
        UserContext user = RequestContext.CURRENT_USER.get();
        String tenantId = RequestContext.TENANT_ID.get();

        System.out.printf("Processing order for tenant %s, user %s%n",
                         tenantId, user.email());

        // You can also get the attributes map
        Map<String, Object> attrs = RequestContext.ATTRIBUTES.get();
        attrs.put("orderId", order.getId());

        // Call nested methods - context flows automatically
        auditLog(order, user);
    }

    private void auditLog(Order order, UserContext user) {
        // Even deeper method calls have access
        String requestId = RequestContext.REQUEST_ID.get(); // Still accessible!
        System.out.printf("[%s] User %s created order %d%n",
                         requestId, user.email(), order.getId());
    }
}

@Service
public class AuditService {
    public void logAction(String action) {
        // Access context from anywhere
        String requestId = RequestContext.REQUEST_ID.get();
        UserContext user = RequestContext.CURRENT_USER.get();
        System.out.printf("[%s] %s performed: %s%n",
                         requestId, user.email(), action);
    }
}
```

### 4. Repository with Tenant Isolation

```java
@Repository
public class OrderRepository {

    @Autowired
    private EntityManager entityManager;

    public List<Order> findOrdersByCurrentTenant() {
        // Get tenant from context automatically
        String tenantId = RequestContext.TENANT_ID.get();

        return entityManager.createQuery(
            "FROM Order o WHERE o.tenantId = :tenantId", Order.class)
            .setParameter("tenantId", tenantId)
            .getResultList();
    }
}
```

### 5. Controller Example

```java
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @Autowired
    private OrderService orderService;

    @PostMapping
    public ResponseEntity<Order> createOrder(@RequestBody Order order) {
        // Context is already available from the filter
        // No need to pass any context data!
        Order created = orderService.processOrder(order);

        // Access context even after service call
        String requestId = RequestContext.REQUEST_ID.get();

        return ResponseEntity.ok()
            .header("X-Request-ID", requestId)
            .body(created);
    }
}
```

## Advanced: Complex ScopedValue with Multiple Values

```java
// More sophisticated context with structured data
public class RequestContext {
    public static final ScopedValue<RequestContextData> CONTEXT =
        ScopedValue.newInstance();

    public static record RequestContextData(
        String requestId,
        UserContext user,
        String tenantId,
        Map<String, Object> attributes,
        Instant startTime,
        String clientIp
    ) {
        public RequestContextData {
            // Validation
            if (requestId == null || requestId.isBlank()) {
                throw new IllegalArgumentException("requestId is required");
            }
        }
    }
}

// Updated filter
@Component
public class ScopedValueFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) {

        var contextData = new RequestContext.RequestContextData(
            UUID.randomUUID().toString(),
            extractUserFromToken(request),
            request.getHeader("X-Tenant-ID"),
            new ConcurrentHashMap<>(),
            Instant.now(),
            request.getRemoteAddr()
        );

        // Bind the entire context object
        ScopedValue.where(RequestContext.CONTEXT, contextData)
            .run(() -> {
                try {
                    filterChain.doFilter(request, response);
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            });
    }
}

// Usage anywhere
@Service
public class PaymentService {
    public void processPayment(Payment payment) {
        var context = RequestContext.CONTEXT.get();
        log.info("Processing payment for user: {}, request: {}",
                 context.user().email(),
                 context.requestId());
    }
}
```

## Integration with Logging (MDC)

```java
@Component
public class LoggingScopedFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) {

        String requestId = UUID.randomUUID().toString();

        // Combine ScopedValue with MDC for logging
        ScopedValue.where(RequestContext.REQUEST_ID, requestId)
            .run(() -> {
                // Also set MDC for logging
                MDC.put("requestId", requestId);
                MDC.put("clientIp", request.getRemoteAddr());

                try {
                    filterChain.doFilter(request, response);
                } catch (Exception e) {
                    log.error("Request failed", e);
                    throw new RuntimeException(e);
                } finally {
                    // Still need to clear MDC as it's not ScopedValue
                    MDC.clear();
                }
            });
    }
}
```

## Async Processing with ScopedValue

```java
@Service
public class AsyncService {

    public CompletableFuture<String> processAsync() {
        // Capture context before async
        String requestId = RequestContext.REQUEST_ID.get();

        return CompletableFuture.supplyAsync(() -> {
            // ScopedValue is NOT automatically inherited in async
            // Need to rebind or pass data
            return ScopedValue.where(RequestContext.REQUEST_ID, requestId)
                .call(() -> {
                    // Now has context in async thread
                    return "Processed: " + RequestContext.REQUEST_ID.get();
                });
        });
    }
}
```

## Exception Handling

```java
@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleException(Exception e) {
        // Access context even in exception handler
        String requestId = "unknown";
        try {
            requestId = RequestContext.REQUEST_ID.get();
        } catch (NoSuchElementException ex) {
            // Context might not be available
        }

        return ResponseEntity.internalServerError()
            .body(new ErrorResponse(requestId, e.getMessage()));
    }
}
```

## Complete Test Example

```java
@SpringBootTest
@AutoConfigureMockMvc
public class ScopedValueFilterTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void shouldPropagateScopedValueThroughRequest() throws Exception {
        mockMvc.perform(get("/api/test")
                .header("X-Tenant-ID", "tenant-123"))
                .andExpect(status().isOk())
                .andExpect(header().exists("X-Request-ID"));

        // Verify context is NOT leaked to other requests
        assertThrows(NoSuchElementException.class,
                     () -> RequestContext.REQUEST_ID.get());
    }
}
```

## Key Benefits of ScopedValue with Virtual Threads

1. **No Manual Cleanup** - Values are automatically removed when scope exits
2. **Immutable** - Values cannot be modified, making them thread-safe
3. **Structured Concurrency** - Works perfectly with virtual threads
4. **No Memory Leaks** - Automatic cleanup prevents leaks
5. **Performance** - Optimized for virtual threads

## Migration from ThreadLocal to ScopedValue

```java
// OLD: ThreadLocal approach
public class OldContext {
    private static final ThreadLocal<String> REQUEST_ID = new ThreadLocal<>();

    public static void setRequestId(String id) { REQUEST_ID.set(id); }
    public static String getRequestId() { return REQUEST_ID.get(); }
    public static void clear() { REQUEST_ID.remove(); }
}

// NEW: ScopedValue approach
public class NewContext {
    public static final ScopedValue<String> REQUEST_ID = ScopedValue.newInstance();

    // No set/clear methods needed
    // Just use: NewContext.REQUEST_ID.get()
}
```

## Summary

With `ScopedValue`, you get:

- ✅ Clean, automatic context management
- ✅ No `finally` block cleanup needed
- ✅ Perfect for virtual threads
- ✅ Immutable, thread-safe context
- ✅ No memory leaks
- ✅ Cleaner code without manual cleanup

The filter becomes simpler because you don't need the `try-finally` pattern - the `ScopedValue` scope handles everything automatically!
