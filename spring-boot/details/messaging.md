## 🎯 Messaging – Annotation‑Based Samples

[back](../annotation-cheat-sheet.md)

[Kafka](#kafka-more-sample)

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

> All snippets target **Spring Boot 3.x / Spring Framework 6** and use **Java 17+**.  
> Add the corresponding starter (`spring-boot-starter-amqp`, `spring-boot-starter-kafka`, `spring-boot-starter-artemis` / `spring-boot-starter-activemq`, `spring-boot-starter-pulsar`) to your `pom.xml` or `build.gradle`.

> The focus is on _how_ each annotation is used, not on wiring every dependency that would appear in a real project.

---

### 1️⃣ `@EnableRabbit`

```java
@Configuration
@EnableRabbit          // ← Activates RabbitMQ listener infrastructure
public class RabbitConfig {

    @Bean
    public Queue fooQueue() {
        return QueueBuilder.durable("foo").build();
    }

    @Bean
    public SimpleMessageListenerContainer container(ConnectionFactory cf,
                                                     MessageListenerAdapter listener) {
        SimpleMessageListenerContainer c = new SimpleMessageListenerContainer();
        c.setConnectionFactory(cf);
        c.setQueueNames("foo");
        c.setMessageListener(listener);
        return c;
    }

    @Bean
    public MessageListenerAdapter listener(MyRabbitConsumer consumer) {
        return new MessageListenerAdapter(consumer, "handleMessage");
    }
}
```

> `@EnableRabbit` must be present **once** per application context.  
> It registers the core Rabbit components (`ConnectionFactory`, `CachingConnectionFactory`, etc.) that let the framework hook into the AMQP life‑cycle.

---

### 2️⃣ `@RabbitListener(queues = "foo")`

```java
@Component
public class MyRabbitConsumer {

    @RabbitListener(queues = "foo")     // ← This method will be invoked for every msg on “foo”
    public void handleMessage(String payload,
                               @Headers Map<String, Object> headers) {
        System.out.printf("Rabbit → %s (headers=%s)%n", payload, headers);
    }
}
```

> **Why it matters**  
> The method is _not_ required to be `public` and may return any type (`void`, `String`, `Message`, `AckReplyMessage`, …).  
> The annotation automatically creates a listener container for you; you only need the method signature.

---

### 3️⃣ `@EnableKafka`

```java
@Configuration
@EnableKafka          // ← Turns on Kafka listener support
public class KafkaConfig {

    @Bean
    public ConsumerFactory<String, String> consumerFactory() {
        Map<String, Object> props = new HashMap<>();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "demo-group");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
        return new DefaultKafkaConsumerFactory<>(props);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, String> kafkaFactory() {
        ConcurrentKafkaListenerContainerFactory<String, String> f = new ConcurrentKafkaListenerContainerFactory<>();
        f.setConsumerFactory(consumerFactory());
        return f;
    }
}
```

> The configuration above is optional if you simply add `spring-boot-starter-kafka`; the starter already registers a `ConcurrentKafkaListenerContainerFactory` for you.  
> `@EnableKafka` is kept for explicit, programmatic control.

---

### 4️⃣ `@KafkaListener(topics = "foo")`

```java
@Component
public class MyKafkaConsumer {

    @KafkaListener(topics = "foo", groupId = "demo-group")
    public void consume(@Payload String message,
                        @Header(KafkaHeaders.RECEIVED_PARTITION_ID) int partition,
                        @Header(KafkaHeaders.RECEIVED_MESSAGE_KEY) String key) {
        System.out.printf("Kafka → %s [key=%s, part=%d]%n", message, key, partition);
    }
}
```

> **Key points**

| Feature    | Example                                                                             |
| ---------- | ----------------------------------------------------------------------------------- |
| `groupId`  | Determines the consumer group; multiple instances with the same group share work.   |
| `@Payload` | Extracts the message body (you can omit it – Spring will bind the first parameter). |
| `@Header`  | Pulls specific message headers (e.g. partition, offset).                            |

---

### 5️⃣ `@EnableJms`

```java
@Configuration
@EnableJms          // ← Turns on JMS listener support (Artemis, ActiveMQ, etc.)
public class JmsConfig {

    @Bean
    public Queue fooDestination() {
        return new ActiveMQQueue("foo");
    }

    // The starter already registers a DefaultJmsListenerContainerFactory
}
```

> **Tip** – When using the _Artemis_ or _ActiveMQ_ starters you usually don't need a custom factory; the auto‑configuration already provides `DefaultJmsListenerContainerFactory`.

---

### 6️⃣ `@JmsListener(destination = "foo")`

```java
@Component
public class MyJmsConsumer {

    @JmsListener(destination = "foo")
    public void onMessage(String body, @Headers Map<String, Object> headers) {
        System.out.printf("JMS → %s (headers=%s)%n", body, headers);
    }
}
```

> **Why `@JmsListener` is handy**

- Works with any JMS provider that Spring supports (`ActiveMQ`, `HornetQ`, `Artemis`, `IBM MQ`, …).
- The method can return an acknowledgment message (e.g., `Message` or `ResponseMessage`), which is then sent back to the broker if you enable **reply**.

---

### 7️⃣ `@EnablePulsar` _(Spring Boot 3.2+)_

```java
@Configuration
@EnablePulsar           // ← Adds Pulsar listener/producer support
public class PulsarConfig {

    @Bean
    public PulsarClient pulsarClient() {
        return PulsarClient.builder()
                .serviceUrl("pulsar://localhost:6650")
                .build();
    }

    @Bean
    public PulsarAdmin pulsarAdmin(PulsarClient client) {
        return PulsarAdmin.builder()
                .serviceHttpUrl("http://localhost:8080")
                .pulsarClient(client)
                .build();
    }
}
```

> The starter automatically configures a `PulsarClient` bean, but showing it here clarifies that `@EnablePulsar` must be present before you can use `@PulsarListener` or `@PulsarClient`.

---

### 8️⃣ `@PulsarClient` / `@PulsarListener`

```java
@Component
public class MyPulsarConsumer {

    @PulsarListener(topic = "persistent://public/default/foo", subscriptionName = "demo-sub")
    public void consume(String msg,
                        @MessageMetadata PulsarMetadata metadata) {
        System.out.printf("Pulsar → %s (ts=%d)%n", msg, metadata.getMessage().getPublishTime());
    }
}

@Service
public class PulsarProducer {

    @PulsarClient
    private PulsarClient client;

    public void send(String msg) throws PulsarClientException {
        Producer<String> producer = client.newProducer(Schema.STRING)
                                          .topic("persistent://public/default/foo")
                                          .create();
        producer.send(msg);
        producer.close();
    }
}
```

> **Highlights**

- `@PulsarListener` works exactly like `@KafkaListener` / `@RabbitListener`; you can also pass a `consumerFactory`.
- The `subscriptionName` is required; the first call creates a durable subscription automatically.
- `PulsarMetadata` lets you access the raw `Message` (sequence number, publish time, etc.).

---

### 9️⃣ `@Transactional`

```java
@Component
public class TransactionalRabbitConsumer {

    @RabbitListener(queues = "order")
    @Transactional          // ← Entire method runs inside a Rabbit “transacted” session
    public void process(String payload) {
        // 1. Persist order → DB
        // 2. Publish another Rabbit message
        // If any exception occurs, the AMQP transaction rolls back
        // (message will be re‑queued by the broker)
        System.out.println("Processing order: " + payload);
    }
}
```

> **Why it matters**

| Situation                               | Why `@Transactional` is useful                                                                                                              |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **AMQP “transacted” mode**              | Guarantees that the consumer acknowledges the message _only after_ the DB transaction commits.                                              |
| **JPA/DB operations inside a listener** | Prevents “stale data” bugs by ensuring the listener’s work is atomic.                                                                       |
| **Kafka**                               | Use with `AckMode.RECORD` and the `KafkaTransactionManager` (requires `@EnableTransactionManagement` and `@Transactional` on the consumer). |

> _Note:_ For Kafka you usually use the **`AckMode.BATCH`** or **`AckMode.RECORD`** modes together with `@Transactional`; the broker will only commit the offset if the transaction commits.

---

## 🚀 Quick Reference

| Feature      | Typical Use‑Case                                                |
| ------------ | --------------------------------------------------------------- |
| **RabbitMQ** | Order‑processing, command/query buses, delayed jobs.            |
| **Kafka**    | Event streaming, log aggregation, stateful services.            |
| **JMS**      | Legacy enterprise integration, transactional messaging.         |
| **Pulsar**   | Low‑latency, high‑throughput event streams with schema support. |

> The annotations above let you _quickly_ spin up listeners or producers without writing boilerplate container code.  
> Combine them with Spring’s `@ConfigurationProperties` or `@Value` for externalised config, and `@Transactional` for atomicity whenever the underlying broker supports it.

---

# Kafka (more sample)

## 🔎 Kafka 101 – Why Spring Boot Loves It

| What               | Why it matters in a Spring Boot app                         |
| ------------------ | ----------------------------------------------------------- |
| **Topic**          | Logical stream of messages – the “bucket” you publish into. |
| **Partition**      | Physical slice of a topic – allows parallelism.             |
| **Consumer Group** | Set of consumers that _share_ the load on a topic.          |
| **Offset**         | Position of a consumer inside a partition.                  |
| **Commit**         | Persists the offset so the consumer can resume later.       |
| **Serialization**  | Converting POJOs ↔︎ bytes (JSON, Avro, Protobuf, etc.).      |
| **Transactions**   | Atomic “read‑then‑write” in Kafka + DB, if you need it.     |

> Spring’s `spring‑boot‑starter‑kafka` already wires a `KafkaTemplate` (producer) **and** a `ConcurrentKafkaListenerContainerFactory` (consumer).  
> The magic comes from a few annotations – the rest is just Spring DI.

---

## 📦 Build file (Maven)

```xml
<dependencies>
    <!-- Core Spring Boot -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter</artifactId>
    </dependency>

    <!-- Kafka Starter (auto‑configures everything) -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-kafka</artifactId>
    </dependency>

    <!-- JSON serialization (Jackson) – optional, but handy -->
    <dependency>
        <groupId>org.springframework.kafka</groupId>
        <artifactId>spring-kafka</artifactId>
        <exclusions>
            <exclusion>
                <groupId>org.apache.kafka</groupId>
                <artifactId>kafka-clients</artifactId>
            </exclusion>
        </exclusions>
    </dependency>

    <!-- Test -->
    <dependency>
        <groupId>org.springframework.kafka</groupId>
        <artifactId>spring-kafka-test</artifactId>
        <scope>test</scope>
    </dependency>
</dependencies>
```

> **Tip:** If you want Avro or Protobuf, just add the respective serializer/deserializer JARs and tweak the properties below.

---

## ⚙️ `application.yml` – The “Hello‑world” config

```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9092
    consumer:
      group-id: demo-group
      auto-offset-reset: earliest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: com.example.demo.model
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
    listener:
      type: simple # <‑ optional, keeps default
      ack-mode: manual_immediate # <‑ allows @Transactional commits
```

> _What this does:_
>
> - `auto-offset-reset: earliest` – first time you run the app it will read the topic from the start.
> - `ack-mode: manual_immediate` – container will _only_ commit the offset once the listener method finishes **and** the transaction commits (if you enable it).
> - `spring.json.trusted.packages` – protects you from deserialisation attacks.

---

## 📁 Project Layout

```
src/
 └─ main/
     ├─ java/
     │   └─ com.example.demo/
     │       ├─ DemoApplication.java
     │       ├─ config/
     │       │   └─ KafkaConfig.java
     │       ├─ model/
     │       │   └─ Order.java
     │       ├─ producer/
     │       │   └─ OrderProducer.java
     │       └─ consumer/
     │           └─ OrderConsumer.java
     └─ resources/
         └─ application.yml
```

---

## 🚀 The Code

### 1️⃣ Domain – `Order`

```java
package com.example.demo.model;

import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Order {
    private String id          = UUID.randomUUID().toString();
    private String customerId;
    private double amount;
    private Instant createdAt = Instant.now();
}
```

> Using Lombok for brevity – remove it if you prefer explicit getters/setters.

---

### 2️⃣ Producer – `OrderProducer`

```java
package com.example.demo.producer;

import com.example.demo.model.Order;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class OrderProducer {

    private static final String TOPIC = "orders";

    private final KafkaTemplate<String, Order> kafkaTemplate;

    public OrderProducer(KafkaTemplate<String, Order> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void sendOrder(Order order) {
        // Key can be anything – here we use the order id
        kafkaTemplate.send(TOPIC, order.getId(), order);
    }
}
```

> **Why `KafkaTemplate<String, Order>`?**  
> The key is a `String` (topic‑key).  
> The value is our POJO; Spring will use `JsonSerializer` because of the config.

---

### 3️⃣ Consumer – `OrderConsumer`

```java
package com.example.demo.consumer;

import com.example.demo.model.Order;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

@Component
public class OrderConsumer {

    /**
     * 1️⃣  The method is invoked for each Order message on the "orders" topic
     * 2️⃣  It runs in the "demo-group" consumer group.
     * 3️⃣  @Transactional (if you enable the transactional container) guarantees
     *      that the offset is committed only when the DB transaction commits.
     */
    @KafkaListener(topics = "orders", groupId = "demo-group")
    public void handleOrder(Order order, ConsumerRecord<String, Order> record, Acknowledgment ack) {
        // Business logic – pretend we persist to a DB
        System.out.printf("💬 Received order %s (customer=%s, amount=%.2f)%n",
                          order.getId(), order.getCustomerId(), order.getAmount());

        // 4️⃣  Manual ack – offset will be committed *after* this method returns
        ack.acknowledge();
    }
}
```

> **Notes**
>
> - `Acknowledgment` lets you control the commit manually – useful for **transactional** consumers.
> - If you omit `acknowledge()`, the container will auto‑commit (the mode you set in `application.yml` determines _when_).

---

### 4️⃣ Configuration – `KafkaConfig`

```java
package com.example.demo.config;

import com.example.demo.model.Order;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.config.KafkaListenerContainerFactory;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.listener.ContainerProperties.AckMode;
import org.springframework.kafka.transaction.KafkaTransactionManager;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.beans.factory.annotation.Value;

@Configuration
public class KafkaConfig {

    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;

    /* ------------------------------------------------- *
     *  Producer – a tiny bit of “hand‑written” config   *
     * ------------------------------------------------- */
    @Bean
    public KafkaTemplate<String, Order> kafkaTemplate() {
        var props = Map.of(
                ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers,
                ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class,
                ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, org.springframework.kafka.support.serializer.JsonSerializer.class
        );
        return new KafkaTemplate<>(new DefaultKafkaProducerFactory<>(props));
    }

    /* ------------------------------------------------- *
     *  Consumer – enable transactions (optional)      *
     * ------------------------------------------------- */
    @Bean
    public KafkaListenerContainerFactory<?> kafkaListenerContainerFactory(
            DefaultKafkaConsumerFactory<String, Order> consumerFactory) {

        var factory = new ConcurrentKafkaListenerContainerFactory<String, Order>();
        factory.setConsumerFactory(consumerFactory);

        // 1️⃣  Transaction support – requires a tx‑manager bean
        factory.getContainerProperties().setAckMode(AckMode.MANUAL_IMMEDIATE);

        return factory;
    }

    /* ------------------------------------------------- *
     *  Transaction Manager – links Kafka + DB          *
     * ------------------------------------------------- */
    @Bean
    public PlatformTransactionManager kafkaTransactionManager(
            org.springframework.kafka.core.KafkaTemplate<String, Order> template) {
        return new KafkaTransactionManager<>(template);
    }
}
```

> **What the above does**
>
> - `kafkaListenerContainerFactory` = `CONCURRENT` consumer container.
> - `setAckMode(MANUAL_IMMEDIATE)` = “commit the offset _after_ the listener returns”.
> - `KafkaTransactionManager` = lets you annotate the consumer method with `@Transactional` and keep the commit atomic with any DB operation you wire in.

---

### 5️⃣ Application – `DemoApplication`

```java
package com.example.demo;

import com.example.demo.model.Order;
import com.example.demo.producer.OrderProducer;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DemoApplication implements CommandLineRunner {

    private final OrderProducer producer;

    public DemoApplication(OrderProducer producer) {
        this.producer = producer;
    }

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    @Override
    public void run(String... args) {
        // Send 3 demo orders on startup
        producer.sendOrder(new Order(null, "cust-123", 99.99, null));
        producer.sendOrder(new Order(null, "cust-456", 250.00, null));
        producer.sendOrder(new Order(null, "cust-789", 17.50,  null));

        System.out.println("✅  Demo app sent 3 orders → topic \"orders\"");
    }
}
```

> Run the app (`./mvnw spring-boot:run`).  
> You’ll see _producer_ output in the console and _consumer_ output on the next line.

---

## 📈 Production‑grade extras

| Feature                         | Where it fits in the sample                                                                                                                                                                                |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Error handling**              | `@KafkaListener` → `SeekToCurrentErrorHandler` (auto‑retry).                                                                                                                                               |
| **Multi‑payload**               | `@KafkaHandler` + `@KafkaListener` for a single method that handles several POJO types.                                                                                                                    |
| **Batch consumption**           | `@KafkaListener(id = "batchListener", topics = "orders", batch = true)` – you’ll get a `List<Order>` instead of one by one.                                                                                |
| **Message headers**             | `ConsumerRecord<String, Order>` gives you the raw record; you can read headers, partition, offset.                                                                                                         |
| **Transactional consumer + DB** | 1️⃣ Wrap the method in `@Transactional` 2️⃣ Enable `KafkaTransactionManager` 3️⃣ Set `ack-mode: manual_immediate`. When the DB commit rolls back, the offset is _not_ committed, so the message is re‑queued. |

### Quick‑start: **Transactional consumer + DB**

```java
@Configuration
@EnableTransactionManagement
public class TransactionalKafkaConfig {

    @Bean
    public KafkaTransactionManager<String, Order> kafkaTransactionManager(
            KafkaTemplate<String, Order> template) {
        return new KafkaTransactionManager<>(template);
    }

    @Bean
    public KafkaListenerContainerFactory<?> kafkaListenerContainerFactory(
            DefaultKafkaConsumerFactory<String, Order> consumerFactory,
            KafkaTransactionManager<String, Order> txManager) {

        var factory = new ConcurrentKafkaListenerContainerFactory<String, Order>();
        factory.setConsumerFactory(consumerFactory);
        factory.setTransactionManager(txManager);
        factory.getContainerProperties().setAckMode(AckMode.MANUAL_IMMEDIATE);
        return factory;
    }
}
```

> Then simply annotate your consumer method with `@Transactional` – the offset commit will only happen if the surrounding transaction (DB + Kafka) succeeds.

---

## 📬 TL;DR – The “Hello‑World” Flow

| Step       | Code                                                                      | What happens in Kafka                                                                          |
| ---------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 1️⃣ Publish | `OrderProducer.sendOrder(...)` → `KafkaTemplate.send(...)`                | Message is encoded (JSON) and written to _partition_ 0 (or the one you own).                   |
| 2️⃣ Consume | `@KafkaListener(topics = "orders")` → `OrderConsumer.handleOrder(...)`    | Spring creates a consumer in the _demo‑group_, reads the record, deserialises it into `Order`. |
| 3️⃣ Commit  | `Acknowledgment.acknowledge()` (or `manual_immediate` + `@Transactional`) | Offset is written back to Kafka, guaranteeing “at‑least‑once” delivery.                        |
| 4️⃣ Repeat  | New consumers → load‑balance, rebalance, or new partitions                | Kafka will keep the offsets per group, so a consumer can _restart_ safely.                     |

---

## 🧪 Quick unit test (optional)

```java
@SpringBootTest
class DemoApplicationTests {

    @Autowired OrderProducer producer;
    @Autowired OrderConsumer consumer;

    @Test
    void contextLoads() {
        assertThat(producer).isNotNull();
        assertThat(consumer).isNotNull();
    }

    @Test
    void roundTrip() throws InterruptedException {
        Order order = new Order(null, "cust-555", 42.42, null);
        producer.sendOrder(order);
        // wait a bit for the consumer thread to pick it up
        Thread.sleep(300);
        // you can assert on logs, or inject a spy consumer and verify invocation
    }
}
```

> Use `spring‑kafka‑test`’s `EmbeddedKafkaBroker` if you want a full integration test that spins up a local broker.

---

## 📌 Checklist – “Ready to deploy”

1. **Kafka broker** – make sure `localhost:9092` (or the cluster address) is reachable.
2. **Topic** – create it (`kafka-topics.sh --create --topic orders --partitions 3 --replication-factor 1`).
3. **Security** – if you use SASL/SSL, add the corresponding properties under `kafka.consumer/producer`.
4. **Monitoring** – enable the **JMX metrics** (`spring.kafka.jmx.enabled: true`).
5. **Schema** – if you go Avro/Protobuf, configure the serializer/deserializer and trust‑packages accordingly.

---

### 🎉 Voilà!

You now have a **fully‑working Spring Boot** application that:

| Feature                       | Code snippet                                 |
| ----------------------------- | -------------------------------------------- |
| Publish `Order`               | `OrderProducer.sendOrder(...)`               |
| Consume single                | `@KafkaListener` + `handleOrder(Order)`      |
| Commit offset                 | `ack.acknowledge()` or `@Transactional`      |
| Transactional + DB (optional) | `KafkaTransactionManager` + `@Transactional` |

Run it, watch the console, and you’re already delivering _real_ messages. Happy coding! 🚀
