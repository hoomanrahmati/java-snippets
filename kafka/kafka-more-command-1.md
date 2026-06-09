## **more essential Kafka commands** and **Spring Boot specific configurations** for a Java developer:

[back](./README.md)

## 🔧 **Additional Kafka CLI Commands**

### **Topic Management**

```bash
# Delete a topic (requires delete.topic.enable=true)
./bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic stock-ticks

```

after deleting a topic something wrong happend because windows didn't let kafka remove the topic! so I had to do this:

```bash
# Stop Kafka
./bin/kafka-server-stop.sh

# Delete the actual data directory contents
rm -rf /tmp/kafka-logs-0/*

# OR if using D:\tmp path
rm -rf D:/tmp/kafka-logs-0/*

# Delete ZooKeeper broker registration (if using ZooKeeper)
# Connect to ZooKeeper and remove broker info:
./bin/zookeeper-shell.sh localhost:2181
> deleteall /brokers/topics/stock-ticks
> quit

# Now restart Kafka
./bin/kafka-server-start.sh ./config/server-0.properties
```

```bash
# describe a topic
./bin/kafka-topics.sh --describe --bootstrap-server localhost:9092 --topic producer-created-event

# Describe all topics
./bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe

# Alter topic partitions (increase only)
./bin/kafka-topics.sh --bootstrap-server localhost:9092 --alter --topic stock-ticks --partitions 6

# Add/modify topic config
./bin/kafka-configs.sh --bootstrap-server localhost:9092 --alter --entity-type topics --entity-name stock-ticks --add-config retention.ms=86400000

# List topics with details
./bin/kafka-topics.sh --bootstrap-server localhost:9092 --list --exclude-internal
```

### **Consumer Group Management**

```bash
# List all consumer groups
./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list

# Describe specific group (see lag)
./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group my-group --describe

# Reset consumer offset
./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group my-group --topic stock-ticks --reset-offsets --to-earliest --execute

# Delete consumer group
./bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group my-group --delete
```

### **Producer/Consumer Advanced**

```bash
# Producer with key and headers
./bin/kafka-console-producer.sh --topic stock-ticks --bootstrap-server localhost:9092 --property parse.key=true --property key.separator=,

kafka-console-producer.sh --bootstrap-server localhost:9092 \
  --topic user-ages \
  --property parse.key=true \
  --property key.separator=":"

# Then type:
# john:22
# jane:21
# jack:24

# Consumer from specific offset
./bin/kafka-console-consumer.sh --topic stock-ticks --bootstrap-server localhost:9092 --offset 100 --partition 0

# Consumer with key deserializer
./bin/kafka-console-consumer.sh --topic stock-ticks --bootstrap-server localhost:9092 --property print.key=true --property key.separator=" - "

# Consume with key deserializer (and show the type)
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic word-count-output5 \
  --from-beginning \
  --property print.key=true \
  --property print.value=true \
  --property key.separator=" : " \
  --property key.deserializer=org.apache.kafka.common.serialization.StringDeserializer \
  --property value.deserializer=org.apache.kafka.common.serialization.LongDeserializer

# Get last 10 messages (using kafka-dump-log)
./bin/kafka-dump-log.sh --files /tmp/kafka-logs/stock-ticks-0/00000000000000000000.log --print-data-log | tail -10
```

### **Monitoring & Diagnostics**

```bash
# Get broker info (list of brokers)
./bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
# ./bin/zookeeper-shell.sh localhost:2181 ls /brokers/ids


# Check broker disk usage
./bin/kafka-log-dirs.sh --bootstrap-server localhost:9092 --describe --broker 0

# Reassign partitions (generate plan)
./bin/kafka-reassign-partitions.sh --bootstrap-server localhost:9092 --generate --topics-to-move-json-file topics.json

# Preferred leader election
./bin/kafka-leader-election.sh --bootstrap-server localhost:9092 --topic stock-ticks --election-type PREFERRED --all-topic-partitions
```

## 🚀 **Spring Boot Kafka Configuration**

### **application.yml (Complete Example)**

```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9092,localhost:9093,localhost:9094
    # Producer config
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      properties:
        spring.json.type.mapping: stock:com.example.StockTick
        retries: 3
        acks: all
        compression.type: snappy
        batch.size: 16384
        linger.ms: 10
        request.timeout.ms: 30000
    # Consumer config
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: "*"
        spring.json.type.mapping: stock:com.example.StockTick
        group-id: stock-processor-group
        auto-offset-reset: earliest
        enable-auto-commit: false
        max-poll-records: 500
        fetch.min.bytes: 1024
    # Listener config
    listener:
      ack-mode: manual_immediate
      concurrency: 3
      missing-topics-fatal: false
    # Admin config
    admin:
      auto-create: false # Recommended for production
      properties:
        create.topic.default.partitions: 6
        create.topic.default.replication.factor: 2
```

### **Spring Boot Producer Examples**

```java
@Service
public class KafkaProducerService {

    @Autowired
    private KafkaTemplate<String, StockTick> kafkaTemplate;

    // Async send with callback
    public void sendStockTick(StockTick tick) {
        CompletableFuture<SendResult<String, StockTick>> future =
            kafkaTemplate.send("stock-ticks", tick.getSymbol(), tick);

        future.whenComplete((result, ex) -> {
            if (ex == null) {
                System.out.println("Sent to partition: " +
                    result.getRecordMetadata().partition() +
                    " offset: " + result.getRecordMetadata().offset());
            } else {
                System.err.println("Failed: " + ex.getMessage());
            }
        });
    }

    // With headers and custom routing
    public void sendWithHeaders(StockTick tick) {
        Message<StockTick> message = MessageBuilder
            .withPayload(tick)
            .setHeader(KafkaHeaders.TOPIC, "stock-ticks")
            .setHeader("source", "webapp")
            .setHeader("timestamp", System.currentTimeMillis())
            .build();

        kafkaTemplate.send(message);
    }

    // Transactional send
    @Transactional
    public void sendTransactional(StockTick tick) {
        kafkaTemplate.executeInTransaction(tx -> {
            tx.send("stock-ticks", tick);
            // Database operations here
            return true;
        });
    }
}
```

### **Spring Boot Consumer Examples**

```java
@Component
public class KafkaConsumerService {

    // Manual acknowledgment
    @KafkaListener(topics = "stock-ticks", groupId = "stock-processor")
    public void listen(StockTick tick, Acknowledgment ack) {
        try {
            processTick(tick);
            ack.acknowledge(); // Manual commit
        } catch (Exception e) {
            // Handle error - will retry based on config
        }
    }

    // Batch listener
    @KafkaListener(topics = "stock-ticks", containerFactory = "batchFactory")
    public void listenBatch(List<StockTick> ticks) {
        System.out.println("Received batch of " + ticks.size() + " messages");
        ticks.forEach(this::processTick);
    }

    // With error handler
    @KafkaListener(topics = "stock-ticks", errorHandler = "myErrorHandler")
    public void listenWithErrorHandler(StockTick tick) {
        // Auto error handling with dead letter topic
    }
}
```

### **Error Handling Configuration**

```java
@Configuration
public class KafkaErrorConfig {

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, StockTick> kafkaListenerContainerFactory() {
        var factory = new ConcurrentKafkaListenerContainerFactory<String, StockTick>();
        factory.setConsumerFactory(consumerFactory());
        factory.setCommonErrorHandler(new DefaultErrorHandler(
            new DeadLetterPublishingRecoverer(kafkaTemplate()),
            new FixedBackOff(1000L, 3) // retry 3 times with 1s delay
        ));
        return factory;
    }

    // Dead Letter Topic consumer
    @KafkaListener(topics = "stock-ticks.DLT", groupId = "dlt-processor")
    public void processDlt(StockTick tick) {
        // Handle failed messages
    }
}
```

### **Testing with Embedded Kafka**

```xml
<!-- Test dependency -->
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka-test</artifactId>
    <scope>test</scope>
</dependency>
```

```java
@SpringBootTest
@EmbeddedKafka(partitions = 1, topics = {"stock-ticks"})
class KafkaIntegrationTest {

    @Test
    void testKafkaProducerConsumer() throws Exception {
        // Embedded Kafka runs automatically
    }
}
```

## 📊 **Monitoring Endpoints (Actuator)**

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,metrics,kafka
  metrics:
    export:
      prometheus:
        enabled: true
```

```java
// Custom Kafka metrics
@Bean
public KafkaListenerEndpointRegistry kafkaListenerEndpointRegistry() {
    return new KafkaListenerEndpointRegistry();
}

// Use Micrometer for custom metrics
@Autowired
private MeterRegistry meterRegistry;

public void recordMetric() {
    meterRegistry.counter("kafka.messages.processed", "topic", "stock-ticks").increment();
}
```

These commands and configurations will give you **production-ready Kafka setup** with proper error handling, monitoring, and testing capabilities!
