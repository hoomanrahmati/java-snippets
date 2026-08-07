## ThreadLocal

[back](./README.md)

**Request context** refers to data that's tied to a specific HTTP request and needs to be accessible throughout the request processing chain, but should be cleaned up after the request completes to prevent memory leaks or data contamination.

## What is Request Context?

Request context is essentially a **storage mechanism** that holds request-scoped data, making it available to any component (filters, interceptors, controllers, services) during the processing of a single HTTP request.

### Common Examples:

## 1. ThreadLocal-Based Context

This is the most common pattern in Spring applications:

```java
public class RequestContext {
    // ThreadLocal stores data per thread
    private static final ThreadLocal<UserContext> currentUser = new ThreadLocal<>();
    private static final ThreadLocal<String> requestId = new ThreadLocal<>();
    private static final ThreadLocal<Map<String, Object>> attributes = new ThreadLocal<>();

    public static void setUser(UserContext user) {
        currentUser.set(user);
    }

    public static UserContext getUser() {
        return currentUser.get();
    }

    public static void setRequestId(String id) {
        requestId.set(id);
    }

    public static String getRequestId() {
        return requestId.get();
    }

    public static void clear() {
        currentUser.remove();
        requestId.remove();
        attributes.remove();
    }
}

// Usage in filter:
public class ContextFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                   HttpServletResponse response,
                                   FilterChain filterChain) {
        try {
            // Set context at beginning
            RequestContext.setRequestId(UUID.randomUUID().toString());
            RequestContext.setUser(getUserFromToken(request));

            filterChain.doFilter(request, response);
        } finally {
            // CRITICAL: Clean up to prevent memory leaks
            RequestContext.clear();
        }
    }
}

// Usage anywhere in your code:
@Service
public class UserService {
    public void doSomething() {
        // Access context without passing parameters everywhere
        UserContext user = RequestContext.getUser();
        String requestId = RequestContext.getRequestId();
        // ... business logic
    }
}
```

## 2. Spring's Built-in RequestContextHolder

Spring provides `RequestContextHolder` for this purpose:

```java
@Service
public class AuditService {
    public void logAction() {
        // Get current request attributes from Spring's context
        RequestAttributes attributes = RequestContextHolder.getRequestAttributes();
        if (attributes != null) {
            HttpServletRequest request =
                ((ServletRequestAttributes) attributes).getRequest();
            String sessionId = request.getSession().getId();
            // ... audit logging
        }
    }
}
```

**Important**: Spring automatically clears `RequestContextHolder` after each request, but if you add custom ThreadLocal data, you must clear it yourself.

## 3. MDC (Mapped Diagnostic Context) - Logging Context

SLF4J's MDC is a popular request context for logging:

```java
@Component
public class LoggingFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                   HttpServletResponse response,
                                   FilterChain filterChain) {
        try {
            // Add correlation ID for tracing
            MDC.put("requestId", UUID.randomUUID().toString());
            MDC.put("userId", getUserId(request));
            MDC.put("ip", request.getRemoteAddr());

            filterChain.doFilter(request, response);
        } finally {
            // CRITICAL: Clean up MDC
            MDC.clear();
        }
    }
}

// In your logback configuration:
// %X{requestId} %X{userId} - %msg%n
// Output: 550e8400-e29b-41d4-a716-446655440000 user123 - Processing order
```

## 4. Transaction Context

Spring's transaction management uses request context:

```java
@Service
@Transactional
public class OrderService {
    // Transaction context is tied to the request thread
    // Spring cleans it up after the request
}
```

## Why Cleanup is Critical

### ❌ Without Cleanup (Memory Leak):

```java
// BAD: No cleanup
public class BadFilter extends OncePerRequestFilter {
    private static final ThreadLocal<LargeObject> context = new ThreadLocal<>();

    @Override
    protected void doFilterInternal(...) {
        context.set(new LargeObject(100MB)); // Sets data
        filterChain.doFilter(request, response);
        // NO CLEANUP!
    }
}

// Problem:
// 1. Thread pool reuses threads
// 2. Next request on same thread still has old data
// 3. Memory leak and data contamination
```

### ✅ With Cleanup:

```java
// GOOD: Proper cleanup
public class GoodFilter extends OncePerRequestFilter {
    private static final ThreadLocal<LargeObject> context = new ThreadLocal<>();

    @Override
    protected void doFilterInternal(...) {
        try {
            context.set(new LargeObject(100MB));
            filterChain.doFilter(request, response);
        } finally {
            context.remove(); // Clean up!
        }
    }
}
```

## Real-World Example: Multi-Tenancy

```java
@Component
public class TenantFilter extends OncePerRequestFilter {
    private static final ThreadLocal<String> currentTenant = new ThreadLocal<>();

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                   HttpServletResponse response,
                                   FilterChain filterChain) {
        try {
            // Extract tenant from header
            String tenantId = request.getHeader("X-Tenant-ID");
            currentTenant.set(tenantId);

            // Now all downstream code knows which tenant
            filterChain.doFilter(request, response);

        } finally {
            // CRITICAL: Clear tenant context
            currentTenant.remove();
        }
    }

    public static String getCurrentTenant() {
        return currentTenant.get();
    }
}

// Usage in repository:
@Repository
public class OrderRepository {
    public List<Order> findOrders() {
        String tenant = TenantFilter.getCurrentTenant();
        // Query only orders for this tenant
        return entityManager.createQuery(
            "FROM Order WHERE tenantId = :tenant")
            .setParameter("tenant", tenant)
            .getResultList();
    }
}
```

## Spring's Built-in Context Cleanup

Spring automatically manages some contexts:

```java
// Spring automatically clears these:
- RequestContextHolder
- SecurityContextHolder (in web environments)
- TransactionContext
- LocaleContextHolder
- TimeZoneContextHolder
```

But **custom ThreadLocal variables require manual cleanup**.

## Summary Table

| Context Type          | Example                   | Cleanup Needed | Spring Handles? |
| --------------------- | ------------------------- | -------------- | --------------- |
| RequestContextHolder  | Spring request attributes | No             | Yes             |
| SecurityContextHolder | Authentication info       | No (in web)    | Yes             |
| MDC                   | Logging context           | Yes            | No              |
| Custom ThreadLocal    | Tenant ID, user context   | Yes            | No              |
| Transaction context   | @Transactional            | No             | Yes             |

## Best Practice

```java
@Component
public class RequestContextFilter extends OncePerRequestFilter {

    // Always use try-finally for ThreadLocal cleanup
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                   HttpServletResponse response,
                                   FilterChain filterChain) {
        try {
            // 1. Set context
            setupContext(request);

            // 2. Process request
            filterChain.doFilter(request, response);

        } finally {
            // 3. ALWAYS cleanup in finally block
            clearContext();
        }
    }

    private void setupContext(HttpServletRequest request) {
        // Set custom ThreadLocal values
        MDC.put("requestId", generateRequestId());
        // Set tenant, user, etc.
    }

    private void clearContext() {
        // Remove all ThreadLocal values
        MDC.clear();
        // Remove custom ThreadLocals
        // This prevents memory leaks and thread contamination
    }
}
```

**Remember**: The `finally` block in your filter is the perfect place for this cleanup because it executes regardless of exceptions and after all processing is complete, ensuring your request context doesn't leak to other requests.
