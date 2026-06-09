### **transaction-aware Kafka acknowledgment** — ensuring you only acknowledge the message to Kafka **after** your database transaction has been successfully committed.

For inbox pattern: first of all we get data from consumer, then we need to save it with transaction in the **inbox** table, then after inbox commited then we can acknowledge broker. And then do process for incoming data.

[back](./outbox-pattern.md)

---

## Step 1: Configuration (`application.yml`)

Disable auto-commit and set manual acknowledgment mode:

```yaml
spring:
  kafka:
    consumer:
      enable-auto-commit: false
      # Optional: Set isolation level if you need to read only committed data
      properties:
        isolation.level: read_committed
    listener:
      # Manual immediate acknowledgment mode
      ack-mode: manual_immediate
```

---

## Step 2: Kafka Consumer with Transactional Logic

Here's how to consume a message, save it to the database, and **only acknowledge after the DB transaction commits**:

```java
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class MessageConsumer {

    private final MessageRepository messageRepository;

    public MessageConsumer(MessageRepository messageRepository) {
        this.messageRepository = messageRepository;
    }

    @KafkaListener(topics = "my-topic", groupId = "my-group")
    @Transactional  // 👈 Spring will manage the DB transaction
    public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {

        try {
            // 1. Save/process message in database
            MessageEntity entity = new MessageEntity();
            entity.setKey(record.key());
            entity.setValue(record.value());
            entity.setPartition(record.partition());
            entity.setOffset(record.offset());

            messageRepository.save(entity);

            // 2. 👇 This acknowledgment is NOT sent immediately!
            // Spring will commit DB transaction FIRST, then call this.
            // After transaction commits, Kafka offset is committed.
            ack.acknowledge();

        } catch (Exception e) {
            // If DB operation fails, transaction rolls back
            // acknowledgment is NOT sent (since exception propagates)
            throw new RuntimeException("Failed to save message", e);
        }
    }
}
```

---

## Step 3: How It Works

The magic happens because of how Spring Kafka integrates with `@Transactional`:

1. **When `ack.acknowledge()` is called** → Spring doesn't send the acknowledgment immediately.
2. **Instead**, it stores a pending acknowledgment.
3. **After the `@Transactional` method completes successfully** → Spring commits the database transaction.
4. **Only then** → Spring sends the acknowledgment to Kafka (commits the offset).

If the database transaction fails (exception thrown):

- Database rolls back
- Acknowledgment is **never sent**
- Kafka will redeliver the message (depending on your `auto.offset.reset` and retry configuration)

---

## Step 4: Alternative - Using TransactionalTemplate (More Explicit)

If you need more control or have multiple transactional resources, you can use `KafkaTransactionManager`:

```java
@Component
public class MessageConsumer {

    private final MessageRepository messageRepository;
    private final KafkaTemplate<String, String> kafkaTemplate;

    public MessageConsumer(MessageRepository messageRepository,
                           KafkaTemplate<String, String> kafkaTemplate) {
        this.messageRepository = messageRepository;
        this.kafkaTemplate = kafkaTemplate;
    }

    @KafkaListener(topics = "my-topic", groupId = "my-group")
    public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {

        // Start a Kafka + DB transaction
        kafkaTemplate.executeInTransaction(operations -> {
            // 1. Save to database
            messageRepository.save(convertToEntity(record));

            // 2. Acknowledge (still deferred until transaction commits)
            ack.acknowledge();

            return null; // commit transaction
        });
    }
}
```

---

## Step 5: Configuration for Idempotency (Recommended)

Even with transaction-aware acknowledgments, messages **can be reprocessed** (e.g., consumer crash after DB commit but before offset commit). Make your consumer **idempotent**:

```sql
-- Add unique constraint to prevent duplicate processing
ALTER TABLE messages ADD CONSTRAINT unique_kafka_offset UNIQUE (topic, partition, offset);
```

Or use a `processed_messages` table:

```java
@Transactional
public void consume(ConsumerRecord<String, String> record, Acknowledgment ack) {
    // Check if already processed
    if (processedMessageRepository.existsByTopicAndPartitionAndOffset(
            record.topic(), record.partition(), record.offset())) {
        ack.acknowledge(); // Already processed, just acknowledge
        return;
    }

    // Save business data AND record in processed_messages table
    processedMessageRepository.save(processedRecord);
    messageRepository.save(businessEntity);

    ack.acknowledge(); // Will commit only if everything succeeds
}
```

---

## Summary

| What happens               | When                            |
| -------------------------- | ------------------------------- |
| `ack.acknowledge()` called | Inside `@Transactional` method  |
| DB transaction commits     | After method exits successfully |
| Kafka offset committed     | **After** DB commit             |

**Key takeaway:** By using `@Transactional` + `manual_immediate` ack-mode, Spring guarantees that the Kafka acknowledgment is sent **only after** your database transaction successfully commits. If the DB transaction rolls back, no acknowledgment is sent, and Kafka will redeliver the message.

Let me know if you'd like me to clarify any part!
