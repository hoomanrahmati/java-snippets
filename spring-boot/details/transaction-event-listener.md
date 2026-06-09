## `@TransactionalEventListener` and `TransactionSynchronizationManager`

[back](./transaction.md)

```java
@Service
@Slf4j
public class OrderService {

    @Autowired
    private OrderRepository orderRepository;

    @Transactional
    public void processOrder(Order order) {
        // 1. Save to database
        orderRepository.save(order);
        log.info("Order saved, but transaction not yet committed");

        // 2. Register after-commit callback
        TransactionSynchronizationManager.registerSynchronization(
            new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    // This runs ONLY after successful commit
                    sendConfirmationEmail(order);
                }

                @Override
                public void afterCompletion(int status) {
                    if (status == STATUS_ROLLED_BACK) {
                        log.warn("Transaction rolled back for order: {}", order.getId());
                        cleanupOnRollback(order);
                    }
                }
            }
        );

        // 3. More database operations if needed
        log.info("Method ending - transaction will commit now");
    }

    private void sendConfirmationEmail(Order order) {
        log.info("Sending email after commit for order: {}", order.getId());
        // Email logic here
    }

    private void cleanupOnRollback(Order order) {
        log.info("Cleanup after rollback for order: {}", order.getId());
    }
}
```

```java
@Transactional
public void createOrder(Order order) {
    orderRepository.save(order);
    outboxRepository.save(OutboxEvent.from(order));
    // Publish Spring application event
    applicationEventPublisher.publishEvent(new OrderCreatedEvent(order));
}

@Async
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void handleAfterCommit(OrderCreatedEvent event) {
    try {
        kafkaTemplate.send(event.getTopic(), event.getPayload())
            .get(10, TimeUnit.SECONDS);

        // ✅ Mark as sent ONLY after Kafka confirms
        event.setSent(true);
        outboxRepository.save(event);

    } catch (Exception e) {
        // Leave sent = false → retry next poll
        log.error("Failed to send event {}", event.getId(), e);
    }
}

@Transactional
@Scheduled(fixedDelay = 1000)
public void processOutbox() {
    List<OutboxEvent> unsent = outboxRepository.findBySentFalse();

    for (OutboxEvent event : unsent) {
        try {
            kafkaTemplate.send(event.getTopic(), event.getPayload())
                .get(10, TimeUnit.SECONDS);

            // ✅ Mark as sent ONLY after Kafka confirms
            event.setSent(true);
            outboxRepository.save(event);

        } catch (Exception e) {
            // Leave sent = false → retry next poll
            log.error("Failed to send event {}", event.getId(), e);
        }
    }
}
```

```java
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationAdapter;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class MyBusinessService {

    private final TransactionTemplate transactionTemplate;
    private final SomeDatabaseRepository databaseRepository;
    private final MessageQueueService messageQueueService;

    public MyBusinessService(TransactionTemplate transactionTemplate,
                             SomeDatabaseRepository databaseRepository,
                             MessageQueueService messageQueueService) {
        this.transactionTemplate = transactionTemplate;
        this.databaseRepository = databaseRepository;
        this.messageQueueService = messageQueueService;
    }

    public void executeBusinessLogic() {
        // TransactionTemplate manages the transaction lifecycle
        transactionTemplate.execute(status -> {
            // 1. This code runs INSIDE the transaction
            System.out.println("Executing database operation...");
            databaseRepository.saveCriticalData();

            // 2. Register a synchronization to run AFTER the transaction commits
            TransactionSynchronizationManager.registerSynchronization(
                new TransactionSynchronizationAdapter() {
                    @Override
                    public void afterCommit() {
                        // 3. This code runs AFTER the transaction successfully commits
                        System.out.println("Transaction committed! Now reliably sending notification...");
                        messageQueueService.sendNotification();
                    }

                    @Override
                    public void afterCompletion(int status) {
                        // Optional: Perform cleanup after commit OR rollback
                        if (status == TransactionSynchronization.STATUS_ROLLED_BACK) {
                            System.out.println("Transaction rolled back. Cleaning up...");
                        }
                    }
                }
            );

            return null; // **Return value for the callback**
        });
    }
}
```

---

`@TransactionalEventListener(phase = TransactionPhase.???)` is actually the **more modern and recommended approach** compared to manually registering synchronizations with `TransactionSynchronizationManager`.

## Key Difference: Manual vs. Event-Driven

| Aspect             | `TransactionSynchronizationManager` | `@TransactionalEventListener`   |
| ------------------ | ----------------------------------- | ------------------------------- |
| **Approach**       | Manual, procedural                  | Declarative, event-driven       |
| **Complexity**     | More boilerplate code               | Cleaner, separation of concerns |
| **Testing**        | Harder to unit test                 | Easier to test in isolation     |
| **Type Safety**    | No compile-time guarantees          | Type-safe method signatures     |
| **Spring Version** | Any Spring version                  | Spring 4.2+                     |

## How to Use `@TransactionalEventListener`

Here's the same example refactored to use the event-driven approach:

```java
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.stereotype.Component;

// 1. Define an event class
public class DataSavedEvent {
    private final Long entityId;
    private final String data;

    public DataSavedEvent(Long entityId, String data) {
        this.entityId = entityId;
        this.data = data;
    }

    // getters...
}

// 2. Service that publishes the event
@Service
public class MyBusinessService {

    private final TransactionTemplate transactionTemplate;
    private final SomeDatabaseRepository databaseRepository;
    private final ApplicationEventPublisher eventPublisher; // Inject this!

    public MyBusinessService(TransactionTemplate transactionTemplate,
                             SomeDatabaseRepository databaseRepository,
                             ApplicationEventPublisher eventPublisher) {
        this.transactionTemplate = transactionTemplate;
        this.databaseRepository = databaseRepository;
        this.eventPublisher = eventPublisher;
    }

    public void executeBusinessLogic() {
        transactionTemplate.execute(status -> {
            // Save data to database
            User savedUser = databaseRepository.saveCriticalData();

            System.out.println("   Transaction active: " +
              TransactionSynchronizationManager.isActualTransactionActive());

            // Publish event (still inside transaction)
            eventPublisher.publishEvent(new DataSavedEvent(savedUser.getId(), savedUser.getData()));

            return null;
        });
        // Event listener will fire AFTER commit automatically
    }
}

// 3. Separate component that listens for the event
@Component
public class PostCommitNotificationHandler {

    private final MessageQueueService messageQueueService;

    public PostCommitNotificationHandler(MessageQueueService messageQueueService) {
        this.messageQueueService = messageQueueService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleDataSaved(DataSavedEvent event) {
        System.out.println("   Transaction active: " +
                    TransactionSynchronizationManager.isActualTransactionActive());

        // This only runs if the transaction commits successfully
        System.out.println("Transaction committed! Sending notification for ID: " + event.getEntityId());
        messageQueueService.sendNotification(event.getEntityId());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_ROLLBACK)
    public void handleRollback(DataSavedEvent event) {
        // Optional: handle rollback scenarios
        System.out.println("Transaction rolled back! Cleaning up for ID: " + event.getEntityId());
    }
}
```

## Transaction Phases Available

You can listen to different transaction phases:

| Phase                        | When It Fires                | Common Use Case                                              |
| ---------------------------- | ---------------------------- | ------------------------------------------------------------ |
| **`AFTER_COMMIT`** (default) | After successful commit      | Sending emails, publishing to message queues, cache eviction |
| **`AFTER_ROLLBACK`**         | After transaction rolls back | Cleanup, logging failures                                    |
| **`AFTER_COMPLETION`**       | After commit OR rollback     | Resource cleanup, always-run logging                         |
| **`BEFORE_COMMIT`**          | Just before commit           | Final validation                                             |

## Advanced Features

### 1. **Conditional Listening with SpEL**

```java
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT,
                            condition = "#event.entityId > 1000")
public void handleOnlyLargeIds(DataSavedEvent event) {
    // Only fires if entityId > 1000
}
```

### 2. **Fallback for Non-Transactional Context**

```java
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT,
                            fallbackExecution = true)
public void handleEvenWithoutTransaction(DataSavedEvent event) {
    // Also executes if there's NO active transaction (as a regular event)
}
```

### 3. **Make Listener Asynchronous**

```java
@Async
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void handleAsync(DataSavedEvent event) {
    // Runs in a separate thread, doesn't block original request
    messageQueueService.sendSlowNotification(event.getEntityId());
}
```

_Note: You need `@EnableAsync` on your configuration class._

## When to Use Which?

| Use Case                                                    | Recommendation                                                |
| ----------------------------------------------------------- | ------------------------------------------------------------- |
| **New projects (Spring 4.2+)**                              | `@TransactionalEventListener` - cleaner and more maintainable |
| **Legacy Spring (pre-4.2)**                                 | `TransactionSynchronizationManager`                           |
| **Simple, one-off post-commit action**                      | Either approach works                                         |
| **Multiple post-commit actions**                            | `@TransactionalEventListener` - better separation of concerns |
| **Need to conditionally execute based on event properties** | `@TransactionalEventListener` with SpEL conditions            |
| **Already using Application Events elsewhere**              | `@TransactionalEventListener` for consistency                 |

## Important Caveats

1. **Same Thread by Default**: Like manual synchronization, the listener runs in the **same thread** as the transaction by default. Use `@Async` if you need to offload heavy work.

2. **Proxy Limitations**: `@TransactionalEventListener` methods must be **public** and cannot be called from within the same class (due to Spring proxy limitations).

3. **No Return Value**: These methods should return `void`. If they need to produce something, publish another event.

4. **Serialization for Distributed Systems**: If using this across microservices, consider message brokers (Kafka, RabbitMQ) instead.

## Bottom Line

**Use `@TransactionalEventListener` for modern Spring applications (Spring Boot 2.x/3.x).** It's more readable, testable, and maintainable than manually registering synchronizations. The manual `TransactionSynchronizationManager` approach is still valid but is essentially "old style" Spring compared to the event-driven approach.
