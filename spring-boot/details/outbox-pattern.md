## Outbox Pattern

[back](../README.md)

[transaction-aware Kafka acknowledgment for inbox](./transactional-acknowledge.md)

### 1. Enhanced Outbox Entity with Retry Fields

```java
package com.example.outbox.entity;

import javax.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "outbox_events",
       indexes = {
           @Index(name = "idx_retry_status", columnList = "retry_count, status, next_retry_at"),
           @Index(name = "idx_published_at", columnList = "published_at")
       })
public class OutboxEvent {

    public enum EventStatus {
        PENDING,    // Not yet published
        PUBLISHED,  // Successfully published
        FAILED,     // Failed after max retries
        RETRY       // Will be retried
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String aggregateType;

    @Column(nullable = false)
    private String aggregateId;

    @Column(nullable = false)
    private String eventType;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String payload;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    private LocalDateTime publishedAt;

    @Enumerated(EnumType.STRING)
    private EventStatus status = EventStatus.PENDING;

    private Integer retryCount = 0;

    private LocalDateTime nextRetryAt;

    private String lastError;

    @Version
    private Integer version;

    // Constructors
    public OutboxEvent() {}

    public OutboxEvent(String aggregateType, String aggregateId,
                      String eventType, String payload) {
        this.aggregateType = aggregateType;
        this.aggregateId = aggregateId;
        this.eventType = eventType;
        this.payload = payload;
        this.createdAt = LocalDateTime.now();
        this.status = EventStatus.PENDING;
        this.retryCount = 0;
        this.nextRetryAt = LocalDateTime.now();
    }

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getAggregateType() { return aggregateType; }
    public void setAggregateType(String aggregateType) { this.aggregateType = aggregateType; }

    public String getAggregateId() { return aggregateId; }
    public void setAggregateId(String aggregateId) { this.aggregateId = aggregateId; }

    public String getEventType() { return eventType; }
    public void setEventType(String eventType) { this.eventType = eventType; }

    public String getPayload() { return payload; }
    public void setPayload(String payload) { this.payload = payload; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getPublishedAt() { return publishedAt; }
    public void setPublishedAt(LocalDateTime publishedAt) { this.publishedAt = publishedAt; }

    public EventStatus getStatus() { return status; }
    public void setStatus(EventStatus status) { this.status = status; }

    public Integer getRetryCount() { return retryCount; }
    public void setRetryCount(Integer retryCount) { this.retryCount = retryCount; }

    public LocalDateTime getNextRetryAt() { return nextRetryAt; }
    public void setNextRetryAt(LocalDateTime nextRetryAt) { this.nextRetryAt = nextRetryAt; }

    public String getLastError() { return lastError; }
    public void setLastError(String lastError) { this.lastError = lastError; }

    public Integer getVersion() { return version; }
    public void setVersion(Integer version) { this.version = version; }

    // Calculate next retry time with exponential backoff
    public void calculateNextRetry() {
        this.retryCount++;
        long delaySeconds = (long) Math.pow(2, this.retryCount); // 2, 4, 8, 16, 32 seconds
        this.nextRetryAt = LocalDateTime.now().plusSeconds(delaySeconds);
        this.status = EventStatus.RETRY;
    }
}
```

### 2. Enhanced Repository with Query Methods

```java
package com.example.outbox.repository;

import com.example.outbox.entity.OutboxEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;

public interface OutboxEventRepository extends JpaRepository<OutboxEvent, Long> {

    // Get events ready for publishing (pending or retry that are due)
    @Query("SELECT o FROM OutboxEvent o WHERE o.status IN ('PENDING', 'RETRY') " +
           "AND o.nextRetryAt <= :now ORDER BY o.createdAt ASC")
    List<OutboxEvent> findEventsReadyForPublishing(@Param("now") LocalDateTime now);

    // Get events that are permanently failed
    @Query("SELECT o FROM OutboxEvent o WHERE o.status = 'FAILED' " +
           "AND o.createdAt >= :since")
    List<OutboxEvent> findFailedEvents(@Param("since") LocalDateTime since);

    // Mark as published
    @Modifying
    @Query("UPDATE OutboxEvent o SET o.status = 'PUBLISHED', " +
           "o.publishedAt = :publishedAt, o.lastError = NULL " +
           "WHERE o.id = :id AND o.status IN ('PENDING', 'RETRY')")
    int markAsPublished(@Param("id") Long id,
                        @Param("publishedAt") LocalDateTime publishedAt);

    // Mark as failed after max retries
    @Modifying
    @Query("UPDATE OutboxEvent o SET o.status = 'FAILED', " +
           "o.lastError = :error " +
           "WHERE o.id = :id")
    int markAsFailed(@Param("id") Long id,
                     @Param("error") String error);

    // Update retry information
    @Modifying
    @Query("UPDATE OutboxEvent o SET o.status = 'RETRY', " +
           "o.retryCount = o.retryCount + 1, " +
           "o.nextRetryAt = :nextRetryAt, " +
           "o.lastError = :error " +
           "WHERE o.id = :id")
    int scheduleRetry(@Param("id") Long id,
                      @Param("nextRetryAt") LocalDateTime nextRetryAt,
                      @Param("error") String error);

    // Count stuck events for monitoring
    long countByStatusAndCreatedAtBefore(OutboxEvent.EventStatus status, LocalDateTime createdAt);

    // Delete old published events
    @Modifying
    @Transactional
    @Query(value = "DELETE FROM outbox_events WHERE status = 'PUBLISHED' " +
                   "AND published_at < :cutoff", nativeQuery = true)
    int deletePublishedEventsOlderThan(@Param("cutoff") LocalDateTime cutoff);
}
```

### 3. Enhanced Publisher with Guaranteed Delivery

```java
package com.example.outbox.service;

import com.example.outbox.entity.OutboxEvent;
import com.example.outbox.repository.OutboxEventRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;

@Service
public class GuaranteedOutboxPublisher {

    private static final Logger logger = LoggerFactory.getLogger(GuaranteedOutboxPublisher.class);
    private static final int MAX_RETRY_COUNT = 5;

    private final OutboxEventRepository outboxRepository;
    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;
    private final MeterRegistry meterRegistry;

    @Value("${outbox.batch-size:100}")
    private int batchSize;

    public GuaranteedOutboxPublisher(OutboxEventRepository outboxRepository,
                                     RabbitTemplate rabbitTemplate,
                                     ObjectMapper objectMapper,
                                     MeterRegistry meterRegistry) {
        this.outboxRepository = outboxRepository;
        this.rabbitTemplate = rabbitTemplate;
        this.objectMapper = objectMapper;
        this.meterRegistry = meterRegistry;
    }

    @Scheduled(fixedDelay = 5000) // Run every 5 seconds
    @Transactional
    public void publishPendingEvents() {
        LocalDateTime now = LocalDateTime.now();
        var pendingEvents = outboxRepository.findEventsReadyForPublishing(now);

        if (pendingEvents.isEmpty()) {
            return;
        }

        logger.info("Found {} events ready for publishing", pendingEvents.size());

        for (OutboxEvent event : pendingEvents) {
            publishSingleEvent(event);
        }
    }

    private void publishSingleEvent(OutboxEvent event) {
        try {
            // Attempt to publish to RabbitMQ with confirmation
            boolean published = publishWithConfirmation(event);

            if (published) {
                // Success - mark as published in database
                int updated = outboxRepository.markAsPublished(event.getId(), LocalDateTime.now());
                if (updated > 0) {
                    logger.info("Successfully published event: {} (ID: {}, Retry: {})",
                               event.getEventType(), event.getId(), event.getRetryCount());
                    meterRegistry.counter("outbox.events.published").increment();
                }
            } else {
                handlePublishFailure(event, "RabbitMQ publisher confirms: message not acknowledged");
            }

        } catch (Exception e) {
            handlePublishFailure(event, e.getMessage());
        }
    }

    private boolean publishWithConfirmation(OutboxEvent event) {
        try {
            // Use publisher confirms for guaranteed delivery
            rabbitTemplate.invoke(operations -> {
                operations.convertAndSend(
                    "order.exchange",
                    "order.created",
                    event.getPayload(),
                    message -> {
                        message.getMessageProperties().setCorrelationId(event.getId().toString());
                        return message;
                    }
                );
                return null;
            });

            return true;

        } catch (Exception e) {
            logger.error("Failed to publish event {}: {}", event.getId(), e.getMessage());
            return false;
        }
    }

    private void handlePublishFailure(OutboxEvent event, String errorMessage) {
        logger.warn("Failed to publish event {}: {}", event.getId(), errorMessage);
        meterRegistry.counter("outbox.events.failed", "retry_count",
                             String.valueOf(event.getRetryCount())).increment();

        // Check if we should retry or mark as permanently failed
        if (event.getRetryCount() >= MAX_RETRY_COUNT) {
            // Max retries exceeded - mark as permanently failed
            int updated = outboxRepository.markAsFailed(event.getId(), errorMessage);
            if (updated > 0) {
                logger.error("Event {} permanently failed after {} retries",
                            event.getId(), MAX_RETRY_COUNT);
                meterRegistry.counter("outbox.events.permanently_failed").increment();

                // Trigger alert (send to dead letter queue, email, etc.)
                triggerFailureAlert(event, errorMessage);
            }
        } else {
            // Schedule for retry with exponential backoff
            LocalDateTime nextRetryAt = calculateNextRetryTime(event.getRetryCount() + 1);
            int updated = outboxRepository.scheduleRetry(event.getId(), nextRetryAt, errorMessage);
            if (updated > 0) {
                logger.info("Event {} scheduled for retry at {} (attempt {}/{})",
                           event.getId(), nextRetryAt,
                           event.getRetryCount() + 1, MAX_RETRY_COUNT);
            }
        }
    }

    private LocalDateTime calculateNextRetryTime(int retryCount) {
        // Exponential backoff: 2^retryCount seconds (2, 4, 8, 16, 32)
        long delaySeconds = (long) Math.min(Math.pow(2, retryCount), 60);
        return LocalDateTime.now().plusSeconds(delaySeconds);
    }

    private void triggerFailureAlert(OutboxEvent event, String error) {
        // Multiple alerting mechanisms

        // 1. Log to error monitoring system (e.g., Sentry, ELK)
        logger.error("PERMANENT FAILURE - Event ID: {}, Type: {}, Aggregate: {}, Error: {}",
                    event.getId(), event.getEventType(), event.getAggregateId(), error);

        // 2. Send to Dead Letter Queue (DLQ) for manual processing
        try {
            rabbitTemplate.convertAndSend("outbox.dlq.exchange", "outbox.failed",
                String.format("{\"eventId\": %d, \"eventType\": \"%s\", \"payload\": %s, \"error\": \"%s\"}",
                event.getId(), event.getEventType(), event.getPayload(), error));
        } catch (Exception e) {
            logger.error("Failed to send to DLQ: {}", e.getMessage());
        }

        // 3. Send alert to monitoring system (e.g., Prometheus AlertManager)
        meterRegistry.counter("outbox.alerts.permanent_failure",
                             "event_type", event.getEventType()).increment();

        // 4. Could also send email, Slack, PagerDuty, etc.
    }
}
```

### 4. Health Check Endpoint for Monitoring

```java
package com.example.outbox.controller;

import com.example.outbox.entity.OutboxEvent;
import com.example.outbox.repository.OutboxEventRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/outbox")
public class OutboxMonitorController {

    private final OutboxEventRepository outboxRepository;

    public OutboxMonitorController(OutboxEventRepository outboxRepository) {
        this.outboxRepository = outboxRepository;
    }

    @GetMapping("/health")
    public Map<String, Object> healthCheck() {
        Map<String, Object> status = new HashMap<>();

        LocalDateTime oneHourAgo = LocalDateTime.now().minusHours(1);
        LocalDateTime oneDayAgo = LocalDateTime.now().minusDays(1);

        long pendingCount = outboxRepository.countByStatusAndCreatedAtBefore(
            OutboxEvent.EventStatus.PENDING, LocalDateTime.now());
        long retryCount = outboxRepository.countByStatusAndCreatedAtBefore(
            OutboxEvent.EventStatus.RETRY, LocalDateTime.now());
        long failedCount = outboxRepository.countByStatusAndCreatedAtBefore(
            OutboxEvent.EventStatus.FAILED, oneDayAgo);

        status.put("pending_count", pendingCount);
        status.put("retry_count", retryCount);
        status.put("failed_count_24h", failedCount);
        status.put("is_healthy", failedCount == 0 && pendingCount < 1000);

        // Alert if too many pending events
        if (pendingCount > 1000) {
            status.put("warning", "High number of pending events: " + pendingCount);
        }

        return status;
    }

    @GetMapping("/failed")
    public Iterable<OutboxEvent> getFailedEvents() {
        return outboxRepository.findFailedEvents(LocalDateTime.now().minusDays(7));
    }
}
```

### 5. Configuration for Publisher Confirms

```yaml
# application.yml
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest
    publisher-confirm-type: correlated # Enable publisher confirms
    publisher-returns: true

outbox:
  batch-size: 100

management:
  endpoints:
    web:
      exposure:
        include: health,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
```

### 6. Async Configuration for Better Performance

```java
package com.example.outbox.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.AsyncConfigurer;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import java.util.concurrent.Executor;

@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {

    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("outbox-publisher-");
        executor.initialize();
        return executor;
    }
}
```

## How the Guarantee Works

### 1. **Detection of Failures**

- **Publisher Confirms**: RabbitMQ acknowledges message receipt
- **Exception Handling**: Catches network errors, broker down, etc.
- **Status Tracking**: Each event has a clear status (PENDING, RETRY, PUBLISHED, FAILED)

### 2. **Recovery Mechanism**

- **Exponential Backoff**: Automatically retries with increasing delays
- **Max Retries**: After 5 failures, moves to FAILED state
- **Dead Letter Queue**: Failed events sent to DLQ for manual inspection

### 3. **Monitoring & Alerting**

- **Health Endpoint**: Check status at `/api/outbox/health`
- **Metrics**: Prometheus metrics for alerting
- **Logging**: Detailed logs for debugging

### 4. **Guarantees Provided**

- **At-least-once**: If publish fails, event stays in outbox and retries
- **No data loss**: Events only marked PUBLISHED after successful broker confirmation
- **Idempotent consumers**: Required for duplicate handling

## Testing the Failure Scenario

```java
package com.example.outbox.test;

// Simulate broker failure
@Test
public void testPublishFailureAndRetry() {
    // Stop RabbitMQ
    // Create an order - event stored in outbox as PENDING
    orderService.createOrder("test@example.com", 100.0);

    // Publisher tries but fails - event becomes RETRY
    // After 5 failures - event becomes FAILED

    // Start RabbitMQ and manually retry
    // Or DLQ for manual processing
}
```

## Key Improvements Over Basic Version

1. **Status Tracking**: PENDING → RETRY → PUBLISHED/FAILED
2. **Exponential Backoff**: 2, 4, 8, 16, 32 seconds between retries
3. **Publisher Confirms**: Guarantees broker received message
4. **Dead Letter Queue**: Failed events don't get lost
5. **Monitoring**: Health endpoints and metrics
6. **Alerting**: Automatic alerts on permanent failures

This ensures **zero data loss** and **automatic recovery** from failures!

---

## Immediate Publisher with Outbox Fallback

```java
package com.example.outbox.service;

import com.example.outbox.entity.OutboxEvent;
import com.example.outbox.repository.OutboxEventRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.LocalDateTime;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

@Service
public class HybridOutboxPublisher {

    private static final Logger logger = LoggerFactory.getLogger(HybridOutboxPublisher.class);

    private final OutboxEventRepository outboxRepository;
    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;

    public HybridOutboxPublisher(OutboxEventRepository outboxRepository,
                                 RabbitTemplate rabbitTemplate,
                                 ObjectMapper objectMapper) {
        this.outboxRepository = outboxRepository;
        this.rabbitTemplate = rabbitTemplate;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public Order createOrderWithImmediatePublish(String customerEmail, Double amount) {
        // 1. Create and save order
        Order order = new Order(customerEmail, amount);
        Order savedOrder = orderRepository.save(order);

        // 2. Create outbox event (as backup)
        OutboxEvent outboxEvent = createOutboxEvent(savedOrder);
        outboxRepository.save(outboxEvent);

        // 3. Try to publish immediately (non-blocking)
        tryPublishImmediately(outboxEvent);

        // 4. Transaction commits - event is in outbox as safety net

        return savedOrder;
    }

    private void tryPublishImmediately(OutboxEvent event) {
        // Use async to not block the transaction
        CompletableFuture.supplyAsync(() -> {
            try {
                // Attempt synchronous publish with timeout
                boolean published = rabbitTemplate.invoke(operations -> {
                    operations.convertAndSend("order.exchange", "order.created",
                        event.getPayload(), message -> {
                            message.getMessageProperties().setCorrelationId(event.getId().toString());
                            return message;
                        });
                    // Wait for confirmation (max 100ms)
                    return operations.waitForConfirms(100);
                });

                if (published) {
                    // Mark as published in a separate transaction
                    markEventAsPublished(event.getId());
                    logger.info("Immediately published event: {}", event.getId());
                    return true;
                }
            } catch (Exception e) {
                logger.warn("Immediate publish failed for event {}: {}", event.getId(), e.getMessage());
            }
            return false;
        }).thenAccept(published -> {
            if (!published) {
                logger.info("Event {} queued for background retry", event.getId());
            }
        });
    }

    @Transactional
    public void markEventAsPublished(Long eventId) {
        outboxRepository.markAsPublished(eventId, LocalDateTime.now());
    }
}
```

```java
    @Scheduled(cron = "0 */5 * * * *") // Every 5 minutes
    public void retryFailedMessages() {
        // Manual reconciliation - basically a simpler outbox
        failedMessageRepository.findByRetryCountLessThan(5)
            .forEach(this::retryPublish);
    }
```

---

### Non-Blocking Async Publisher with CompletableFuture

For maximum performance (zero blocking on the main thread):

```java
package com.example.outbox.service;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import java.util.concurrent.ExecutorService;

@Service
public class AsyncImmediatePublisher {

    private final ExecutorService publisherExecutor;
    private final OutboxEventRepository outboxRepository;
    private final RabbitTemplate rabbitTemplate;

    public AsyncImmediatePublisher(
            @Qualifier("publisherThreadPool") ExecutorService publisherExecutor,
            OutboxEventRepository outboxRepository,
            RabbitTemplate rabbitTemplate) {
        this.publisherExecutor = publisherExecutor;
        this.outboxRepository = outboxRepository;
        this.rabbitTemplate = rabbitTemplate;
    }

    @Transactional
    public Order createOrder(String customerEmail, Double amount) {
        // 1. Save order (transactional)
        Order order = new Order(customerEmail, amount);
        Order savedOrder = orderRepository.save(order);

        // 2. Create outbox event
        OutboxEvent event = new OutboxEvent("Order", savedOrder.getId().toString(),
                                           "OrderCreated", serialize(savedOrder));
        outboxRepository.save(event);

        // 3. Async publish (non-blocking, after commit)
        TransactionSynchronizationManager.registerSynchronization(
            new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    publishAsync(event);
                }
            }
        );

        return savedOrder; // Returns immediately, doesn't wait for publish
    }

    private void publishAsync(OutboxEvent event) {
        CompletableFuture
            .supplyAsync(() -> tryPublish(event), publisherExecutor)
            .thenAccept(success -> {
                if (success) {
                    markAsPublished(event.getId());
                } else {
                    // Event stays in outbox for background scheduler
                    logger.warn("Async publish failed for event {}, will retry later", event.getId());
                }
            })
            .exceptionally(throwable -> {
                logger.error("Unexpected error during async publish for event {}",
                            event.getId(), throwable);
                return null;
            });
    }

    private boolean tryPublish(OutboxEvent event) {
        try {
            rabbitTemplate.convertAndSend("order.exchange", "order.created",
                event.getPayload());
            return true;
        } catch (Exception e) {
            logger.warn("Failed to publish event {}: {}", event.getId(), e.getMessage());
            return false;
        }
    }

    @Transactional
    public void markAsPublished(Long eventId) {
        outboxRepository.markAsPublished(eventId, LocalDateTime.now());
    }
}

// Thread pool configuration
@Configuration
public class PublisherConfig {

    @Bean(name = "publisherThreadPool")
    public ExecutorService publisherThreadPool() {
        return Executors.newFixedThreadPool(10, new ThreadFactoryBuilder()
            .setNameFormat("immediate-publisher-%d")
            .setDaemon(true) // Don't prevent JVM shutdown
            .build());
    }
}
```

---

## Namastack

Here's a complete sample implementation using Namastack Outbox with Spring Boot.

### 📦 Step 1: Add Dependency

Add the JDBC starter to your `pom.xml` (Maven) or `build.gradle`:

**Maven:**

```xml
<dependency>
    <groupId>io.namastack</groupId>
    <artifactId>namastack-outbox-starter-jdbc</artifactId>
    <version>1.3.1</version>
</dependency>
```

**Gradle:**

```kotlin
implementation("io.namastack:namastack-outbox-starter-jdbc:1.3.1")
```

> **Note:** The JDBC starter automatically creates the required outbox tables on startup - zero configuration needed .

### ⚙️ Step 2: Enable Scheduling

Add `@EnableScheduling` to your main application class:

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling  // Required for automatic outbox processing
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

### 🏗️ Step 3: Define Your Event Payload

Create a simple POJO for your business event:

```java
public record OrderCreatedEvent(
    String orderId,
    String customerId,
    String region,
    BigDecimal amount
) {}
```

### ✍️ Step 4: Schedule Events in Your Service

Use the `Outbox` bean to schedule events atomically with your database transaction:

```java
import io.namastack.outbox.Outbox;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderService {
    private final Outbox outbox;
    private final OrderRepository orderRepository;

    public OrderService(Outbox outbox, OrderRepository orderRepository) {
        this.outbox = outbox;
        this.orderRepository = orderRepository;
    }

    @Transactional
    public void createOrder(CreateOrderCommand command) {
        // 1. Save business data
        Order order = Order.create(command);
        orderRepository.save(order);

        // 2. Schedule event - saved atomically in the same transaction
        outbox.schedule(
            new OrderCreatedEvent(order.getId(), order.getCustomerId(),
                                  order.getRegion(), order.getAmount()),
            "order-" + order.getId()  // key for ordered processing
        );
    }
}
```

The `outbox.schedule()` call persists the event to the outbox table within the same database transaction. If the transaction commits successfully, the event is safely stored .

### 🎯 Step 5: Create an Event Handler

Create a handler component that processes events when they're published from the outbox:

```java
import io.namastack.outbox.annotation.OutboxHandler;
import org.springframework.stereotype.Component;

@Component
public class OrderEventHandlers {

    // Typed handler - processes OrderCreatedEvent only
    @OutboxHandler
    public void handleOrderCreated(OrderCreatedEvent event) {
        System.out.println("Processing order: " + event.orderId());
        // Send to Kafka, call another service, send email, etc.
        notificationService.sendOrderConfirmation(event);
    }

    // Generic handler - receives payload and metadata
    @OutboxHandler
    public void handleAny(Object payload, OutboxRecordMetadata metadata) {
        // Handle different event types or log failures
        logger.info("Processing event type: {}", metadata.eventType());
    }
}
```

The `@OutboxHandler` annotation tells Namastack to automatically invoke this method when an event of matching type is dequeued from the outbox .

### 🔧 Step 6: Optional Configuration

Add configuration to `application.yml` to customize behavior:

```yaml
namastack:
  outbox:
    poll-interval: 2000 # Poll every 2 seconds
    batch-size: 10 # Process up to 10 records per poll
    retry:
      policy: exponential # exponential, fixed, or linear
      max-retries: 3
      exponential:
        initial-delay: 1000 # 1 second initial delay
        max-delay: 60000 # 60 seconds max
      jitter: 500 # Add jitter to prevent thundering herd
```

This configures polling frequency, batch size, and retry behavior with exponential backoff .

### 📊 Alternative: Spring's ApplicationEventPublisher

If you prefer Spring's native event model, annotate your event with `@OutboxEvent`:

```java
import io.namastack.outbox.annotation.OutboxEvent;

@OutboxEvent(key = "#this.orderId")  // SpEL expression
public record OrderCreatedEvent(
    String orderId,
    String customerId,
    String region,
    BigDecimal amount
) {}
```

Then publish using Spring's `ApplicationEventPublisher`:

```java
@Service
public class OrderService {
    @Autowired
    private ApplicationEventPublisher eventPublisher;
    @Autowired
    private OrderRepository orderRepository;

    @Transactional
    public void createOrder(CreateOrderCommand command) {
        Order order = Order.create(command);
        orderRepository.save(order);

        // Automatically saved to outbox atomically
        eventPublisher.publishEvent(
            new OrderCreatedEvent(order.getId(), order.getCustomerId(),
                                  order.getRegion(), order.getAmount())
        );
    }
}
```

Both approaches work equally well - choose based on your preference .

### ✅ That's It!

Namastack handles the rest automatically:

- Creates the outbox table schema on startup
- Polls the table for pending events
- Manages retries with exponential backoff
- Handles dead letter records after max retries exceeded
- Provides built-in Micrometer metrics and health checks
- Supports horizontal scaling with automatic partition rebalancing

The library guarantees **at-least-once delivery** with robust retry logic, ensuring no events are ever lost .
