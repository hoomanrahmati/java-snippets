# @EventListener in Spring Boot

[back](../README.md)

`@EventListener` is a Spring annotation that allows you to listen to application events published within your Spring application context. It's an alternative to implementing the `ApplicationListener` interface.

## Key Concepts

- **Event Types**: Can listen to any type of event (custom or built-in)
- **Asynchronous Support**: Can be made async with `@Async`
- **Conditional Listening**: Filter events using SpEL expressions
- **Automatic Events**: Spring publishes many events by default (ApplicationReadyEvent, ContextClosedEvent, etc.)

## Sample 1: Basic Event Listener

### Event Class

```java
package com.example.events;

public class UserRegistrationEvent {
    private String username;
    private String email;

    public UserRegistrationEvent(String username, String email) {
        this.username = username;
        this.email = email;
    }

    // Getters
    public String getUsername() { return username; }
    public String getEmail() { return email; }
}
```

### Component with Event Listener

```java
package com.example.components;

import com.example.events.UserRegistrationEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

@Component
public class UserEventListener {

    @EventListener
    public void handleUserRegistration(UserRegistrationEvent event) {
        System.out.println("New user registered: " + event.getUsername() +
                           " with email: " + event.getEmail());
    }
}
```

### Publishing the Event

```java
package com.example.services;

import com.example.events.UserRegistrationEvent;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;

@Service
public class UserService {

    private final ApplicationEventPublisher eventPublisher;

    public UserService(ApplicationEventPublisher eventPublisher) {
        this.eventPublisher = eventPublisher;
    }

    public void registerUser(String username, String email) {
        // Business logic...
        System.out.println("User " + username + " registered in DB");

        // Publish event
        eventPublisher.publishEvent(new UserRegistrationEvent(username, email));
    }
}
```

## Sample 2: Multiple Event Listeners

```java
package com.example.components;

import com.example.events.UserRegistrationEvent;
import com.example.events.OrderCreatedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

@Component
public class NotificationService {

    @EventListener
    public void sendWelcomeEmail(UserRegistrationEvent event) {
        System.out.println("Sending welcome email to: " + event.getEmail());
        // Email sending logic
    }

    @EventListener
    public void sendOrderConfirmation(OrderCreatedEvent event) {
        System.out.println("Sending order confirmation for order #" + event.getOrderId());
        // SMS/Email logic
    }
}

@Component
public class AuditService {

    @EventListener
    public void auditUserRegistration(UserRegistrationEvent event) {
        System.out.println("AUDIT: User " + event.getUsername() + " registered at " + new Date());
        // Save to audit log
    }
}
```

## Sample 3: Listening to Multiple Events

```java
package com.example.components;

import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

@Component
public class EventLogger {

    // Listen to multiple event types
    @EventListener({UserRegistrationEvent.class, OrderCreatedEvent.class})
    public void logEvent(Object event) {
        if (event instanceof UserRegistrationEvent) {
            UserRegistrationEvent userEvent = (UserRegistrationEvent) event;
            System.out.println("LOG: User registration - " + userEvent.getUsername());
        } else if (event instanceof OrderCreatedEvent) {
            OrderCreatedEvent orderEvent = (OrderCreatedEvent) event;
            System.out.println("LOG: Order created - " + orderEvent.getOrderId());
        }
    }
}
```

## Sample 4: Conditional Event Listening

```java
package com.example.components;

import com.example.events.UserRegistrationEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

@Component
public class ConditionalListener {

    @EventListener(condition = "#event.username.startsWith('admin_')")
    public void handleAdminUser(UserRegistrationEvent event) {
        System.out.println("Special handling for admin user: " + event.getUsername());
        // Send different email, assign roles, etc.
    }

    @EventListener(condition = "#event.email.contains('@company.com')")
    public void handleCorporateUser(UserRegistrationEvent event) {
        System.out.println("Corporate user detected: " + event.getEmail());
        // Assign corporate benefits
    }
}
```

## Sample 5: Asynchronous Event Listener

### Configuration

```java
package com.example.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

@Configuration
@EnableAsync
public class AsyncConfig {
}
```

### Async Event Listener

```java
package com.example.components;

import com.example.events.UserRegistrationEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

@Component
public class AsyncEventListener {

    @Async
    @EventListener
    public void handleAsyncEvent(UserRegistrationEvent event) {
        try {
            // Simulate long running task
            Thread.sleep(5000);
            System.out.println("Async email sent to: " + event.getEmail() +
                               " on thread: " + Thread.currentThread().getName());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
```

## Sample 6: Returning Events (Event Chaining)

```java
package com.example.components;

import com.example.events.UserRegistrationEvent;
import com.example.events.UserUpdatedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

@Component
public class ChainedEventProcessor {

    @EventListener
    public UserUpdatedEvent handleUserRegistration(UserRegistrationEvent event) {
        System.out.println("Processing registration for: " + event.getUsername());

        // Return a new event - Spring will automatically publish it
        return new UserUpdatedEvent(event.getUsername(), "PROCESSED");
    }

    @EventListener
    public void handleUserUpdate(UserUpdatedEvent event) {
        System.out.println("User status updated: " + event.getUsername() +
                           " to " + event.getStatus());
    }
}
```

## Sample 7: Spring Built-in Events

```java
package com.example.components;

import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.ContextClosedEvent;
import org.springframework.context.event.ContextRefreshedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

@Component
public class ApplicationLifecycleListener {

    @EventListener
    public void onApplicationReady(ApplicationReadyEvent event) {
        System.out.println("Application is ready! Starting background tasks...");
        // Initialize caches, start schedulers, etc.
    }

    @EventListener
    public void onContextRefreshed(ContextRefreshedEvent event) {
        System.out.println("Application context refreshed!");
    }

    @EventListener
    public void onContextClosed(ContextClosedEvent event) {
        System.out.println("Application is shutting down... Cleaning up resources");
        // Close connections, save state, etc.
    }
}
```

## Sample 8: Transaction-bound Events

```java
package com.example.components;

import com.example.events.UserRegistrationEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class TransactionalListener {

    // Execute AFTER transaction commits successfully
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleAfterCommit(UserRegistrationEvent event) {
        System.out.println("Transaction committed! Sending welcome email to: " + event.getEmail());
        // Email will only be sent if transaction succeeds
    }

    // Execute BEFORE transaction commit
    @TransactionalEventListener(phase = TransactionPhase.BEFORE_COMMIT)
    public void handleBeforeCommit(UserRegistrationEvent event) {
        System.out.println("Transaction about to commit for user: " + event.getUsername());
    }

    // Execute AFTER transaction rollback
    @TransactionalEventListener(phase = TransactionPhase.AFTER_ROLLBACK)
    public void handleAfterRollback(UserRegistrationEvent event) {
        System.out.println("Transaction rolled back for user: " + event.getUsername());
        // Cleanup or retry logic
    }

    // Execute AFTER transaction completion (commit OR rollback)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMPLETION)
    public void handleAfterCompletion(UserRegistrationEvent event) {
        System.out.println("Transaction completed for user: " + event.getUsername());
        // Always executed
    }
}
```

## Complete Application Example

### Main Application

```java
package com.example;

import com.example.services.UserService;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;

@SpringBootApplication
public class EventListenerApplication {
    public static void main(String[] args) {
        ConfigurableApplicationContext context = SpringApplication.run(EventListenerApplication.class, args);

        UserService userService = context.getBean(UserService.class);

        // This will trigger the event listeners
        userService.registerUser("john_doe", "john@example.com");
        userService.registerUser("admin_jane", "jane@admin.com");
    }
}
```

### application.properties

```properties
# Enable async if needed
spring.task.execution.pool.core-size=5
spring.task.execution.pool.max-size=10
```

## Important Notes

1. **Order of Execution**: By default, order is not guaranteed. Use `@Order` annotation to control execution order.

```java
@EventListener
@Order(1)
public void firstHandler(UserRegistrationEvent event) { }

@EventListener
@Order(2)
public void secondHandler(UserRegistrationEvent event) { }
```

2. **Exception Handling**: Exceptions in event listeners won't affect the event publisher by default.

3. **Performance**: Avoid long-running operations in synchronous listeners. Use `@Async` for heavy operations.

4. **Type Safety**: Events can be any object type; Spring uses reflection to match event types with listener parameters.

This pattern is excellent for implementing loose coupling between different parts of your application, especially for cross-cutting concerns like logging, auditing, or notifications.

---

# Listener Execution Timing: Complete Answer

**Timing depends on the method and event type, but by default - listeners run synchronously in the SAME thread.**

Let me explain with clear examples:

## Default Behavior: Synchronous (Same Thread)

```java
@Service
public class OrderService {
    private final ApplicationEventPublisher eventPublisher;

    public OrderService(ApplicationEventPublisher eventPublisher) {
        this.eventPublisher = eventPublisher;
    }

    public void createOrder() {
        System.out.println("1️⃣ Publisher method started - Thread: " + Thread.currentThread().getName());

        // Publish event
        eventPublisher.publishEvent(new OrderCreatedEvent(123L));
        System.out.println("3️⃣ Publisher method continues after event publication");

        // More business logic
        System.out.println("4️⃣ Publisher method finishing");
    }
}

@Component
public class OrderEventListener {

    @EventListener
    public void handleOrderCreated(OrderCreatedEvent event) {
        System.out.println("2️⃣ Listener executing - Thread: " + Thread.currentThread().getName());
        // This runs BEFORE the publisher method continues
        try {
            Thread.sleep(2000); // Simulate work
        } catch (InterruptedException e) {}
        System.out.println("2️⃣ Listener finished");
    }
}
```

### Output (Default Behavior):

```
1️⃣ Publisher method started - Thread: http-nio-8080-exec-1
2️⃣ Listener executing - Thread: http-nio-8080-exec-1
2️⃣ Listener finished
3️⃣ Publisher method continues after event publication
4️⃣ Publisher method finishing
```

**Key Insight:** The listener runs COMPLETELY before the publisher method continues!

## Execution Flow Diagram

```
Publisher Method
     │
     ├─ Start execution
     │
     ├─ Publish Event → ──┐
     │                    │
     │                    ↓
     │              Listener(s) execute
     │              (synchronously)
     │                    │
     │                    ↓
     │              Listener completes
     │                    │
     ├─ Continue publisher ←──┘
     │
     └─ End execution
```

## Different Scenarios

### 1. **Multiple Listeners (Sequential)**

```java
@Service
public class UserService {
    public void registerUser() {
        System.out.println("📢 Publishing user registration event");
        eventPublisher.publishEvent(new UserRegisteredEvent("john"));
        System.out.println("✅ User registration complete");
    }
}

@Component
public class MultipleListeners {

    @EventListener
    @Order(1)
    public void sendEmail(UserRegisteredEvent event) {
        System.out.println("  ✉️ Sending email (1/3) - START");
        Thread.sleep(1000);
        System.out.println("  ✉️ Sending email (1/3) - END");
    }

    @EventListener
    @Order(2)
    public void updateAudit(UserRegisteredEvent event) {
        System.out.println("  📝 Updating audit (2/3) - START");
        Thread.sleep(500);
        System.out.println("  📝 Updating audit (2/3) - END");
    }

    @EventListener
    @Order(3)
    public void sendNotification(UserRegisteredEvent event) {
        System.out.println("  🔔 Sending notification (3/3) - START");
        Thread.sleep(300);
        System.out.println("  🔔 Sending notification (3/3) - END");
    }
}
```

**Output:**

```
📢 Publishing user registration event
  ✉️ Sending email (1/3) - START
  ✉️ Sending email (1/3) - END
  📝 Updating audit (2/3) - START
  📝 Updating audit (2/3) - END
  🔔 Sending notification (3/3) - START
  🔔 Sending notification (3/3) - END
✅ User registration complete
```

## 2. **Async Listener (Different Thread)**

```java
@Configuration
@EnableAsync
public class AsyncConfig {
}

@Service
public class PaymentService {
    public void processPayment() {
        System.out.println("1️⃣ [Publisher] Processing payment - Thread: " + Thread.currentThread().getName());

        eventPublisher.publishEvent(new PaymentSuccessEvent(123L));

        System.out.println("3️⃣ [Publisher] Payment method continues immediately!");
        System.out.println("4️⃣ [Publisher] Payment method finished");
    }
}

@Component
public class AsyncListener {

    @Async
    @EventListener
    public void handlePayment(PaymentSuccessEvent event) throws InterruptedException {
        System.out.println("2️⃣ [Listener] START - Thread: " + Thread.currentThread().getName());
        Thread.sleep(3000); // Long operation
        System.out.println("2️⃣ [Listener] END - Thread: " + Thread.currentThread().getName());
    }
}
```

**Output:**

```
1️⃣ [Publisher] Processing payment - Thread: http-nio-8080-exec-1
3️⃣ [Publisher] Payment method continues immediately!
4️⃣ [Publisher] Payment method finished
2️⃣ [Listener] START - Thread: SimpleAsyncTaskExecutor-1
2️⃣ [Listener] END - Thread: SimpleAsyncTaskExecutor-1
```

**Key Difference:** With `@Async`, the publisher DOES NOT wait for the listener!

## 3. **ApplicationEvent vs Simple Object**

```java
// Both have the SAME synchronous behavior by default

// Option A: Extending ApplicationEvent (legacy)
public class LegacyEvent extends ApplicationEvent {
    public LegacyEvent(Object source) {
        super(source);
    }
}

// Option B: Simple POJO (modern, recommended)
public class ModernEvent {
    private String data;
}

// Both behave identically - synchronous execution
```

## 4. **Transaction Synchronization (Different Timing)**

```java
@Service
public class BankService {

    @Transactional
    public void transferMoney() {
        System.out.println("💰 Transfer started");

        // Normal event - executes immediately (within transaction)
        eventPublisher.publishEvent(new MoneyTransferredEvent(100.00));

        System.out.println("💰 Transfer method ending");
        // Transaction commits here
    }
}

@Component
public class TransactionalListener {

    @EventListener  // Regular listener
    public void regularListener(MoneyTransferredEvent event) {
        System.out.println("  🔴 Regular listener - Transaction active: " +
                          TransactionSynchronizationManager.isActualTransactionActive());
        // Runs right after publish, before transaction commits
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void afterCommitListener(MoneyTransferredEvent event) {
        System.out.println("  🟢 AFTER_COMMIT listener - Transaction active: " +
                          TransactionSynchronizationManager.isActualTransactionActive());
        // Runs AFTER transaction commits
    }
}
```

**Output:**

```
💰 Transfer started
  🔴 Regular listener - Transaction active: true
💰 Transfer method ending
(Transaction commits)
  🟢 AFTER_COMMIT listener - Transaction active: false
```

## 5. **Exception Handling Impact**

```java
@Service
public class ProductService {

    public void updateProduct() {
        System.out.println("Updating product...");

        try {
            eventPublisher.publishEvent(new ProductUpdatedEvent(1L));
            System.out.println("Event published successfully");
        } catch (Exception e) {
            System.out.println("Event publishing failed: " + e.getMessage());
        }

        System.out.println("Product update continues");
    }
}

@Component
public class FaultyListener {

    @EventListener
    public void badListener(ProductUpdatedEvent event) {
        System.out.println("Listener: About to throw exception");
        throw new RuntimeException("Listener failed!");
    }
}
```

**Output:**

```
Updating product...
Listener: About to throw exception
Event publishing failed: Listener failed!
Product update continues
```

**Important:** The publisher method catches exceptions from listeners unless they're async!

## Real-World Comparison

### Scenario: User Registration with Email

```java
@Service
public class UserRegistrationService {

    // OPTION 1: Direct call (blocking)
    public void registerDirect(User user) {
        userRepo.save(user);              // 100ms
        emailService.sendWelcome(user);   // 2000ms - USER WAITS!
        smsService.sendOTP(user);         // 500ms
        // Total: 2600ms before response
    }

    // OPTION 2: Event with sync listeners (still blocking)
    public void registerSyncEvent(User user) {
        userRepo.save(user);              // 100ms
        eventPublisher.publishEvent(new UserRegisteredEvent(user)); // 2500ms total!
        // Total: 2600ms before response
    }

    // OPTION 3: Event with async listeners (non-blocking)
    public void registerAsyncEvent(User user) {
        userRepo.save(user);              // 100ms
        eventPublisher.publishEvent(new UserRegisteredEvent(user)); // <1ms to publish
        return; // 100ms total response time!
    }
}

@Component
public class NotificationListener {

    @Async
    @EventListener
    public void sendWelcomeEmail(UserRegisteredEvent event) {
        // This runs in background
        emailService.sendWelcome(event.getUser()); // 2000ms
    }

    @Async
    @EventListener
    public void sendOTPSMS(UserRegisteredEvent event) {
        // This runs in background
        smsService.sendOTP(event.getUser()); // 500ms
    }
}
```

## Summary Table

| Scenario                  | Publisher waits?      | Executes in same thread? | Publisher continues after...       |
| ------------------------- | --------------------- | ------------------------ | ---------------------------------- |
| Default @EventListener    | ✅ YES                | ✅ YES                   | All listeners finish               |
| @Async @EventListener     | ❌ NO                 | ❌ NO                    | Immediately after publish          |
| Multiple listeners (sync) | ✅ YES                | ✅ YES                   | All listeners finish sequentially  |
| Transaction AFTER_COMMIT  | ✅ YES                | ❌ NO (different phase)  | After transaction commits          |
| Listener throws exception | ✅ YES (unless async) | ✅ YES (unless async)    | Immediately (exception propagates) |

## Best Practices

```java
@Service
public class BestPracticesService {

    // 1. For fast operations - sync is fine
    public void updateCache() {
        eventPublisher.publishEvent(new CacheUpdateEvent()); // Listeners do fast work
    }

    // 2. For slow operations - use async
    @Async
    public void processReport() {
        eventPublisher.publishEvent(new ReportGenerationEvent()); // Listeners should be @Async
    }

    // 3. For critical operations - consider transaction phases
    @Transactional
    public void criticalOperation() {
        // Publish AFTER_COMMIT to ensure data is persisted
        eventPublisher.publishEvent(new CriticalEvent());
    }
}
```

## The Golden Rule

> **By default: Publisher waits for ALL sync listeners to complete before continuing.**
>
> For non-blocking behavior, use `@Async` on your listener or make the publisher method itself async.

This design ensures data consistency by default, but gives you flexibility for performance when needed!

---

### ApplicationReadyEvent

- instead of using Bean use @EventListener(ApplicationReadyEvent.class) to run a function

```java
@Component
public class TopologyBuilder {

    private final Serde<PersonalBalance> serde;

    public TopologyBuilder(Serde<PersonalBalance> serde) {
        this.serde = serde;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void buildTopology(StreamsBuilder builder) {
        builder.stream("personal-balance-input", Consumed.with(Serdes.String(), serde))
            .selectKey((k, v) -> v.getName())
            .groupByKey(Grouped.with(Serdes.String(), serde))
            .aggregate(
                PersonalBalance::new,
                (key, value, agg) -> {
                    agg.setAmount(agg.getAmount() + value.getAmount());
                    agg.setName(key);
                    agg.setDateTime(value.getDateTime());
                    return agg;
                },
                Materialized.with(Serdes.String(), serde)
            )
            .toStream()
            .to("personal-balance-output", Produced.with(Serdes.String(), serde));
    }
}
```
