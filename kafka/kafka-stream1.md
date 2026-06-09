## Kafka Stream (simple sample)

[back](./README.md)

**You can and should define Kafka Streams directly inside your Spring Boot application.**

You do not need to run a separate external command or a dedicated Kafka Streams server. Instead, Kafka Streams runs as a **client library** embedded within your application's Java process.

Here is a breakdown of how it works and how to implement it.

### Why It Runs Inside Your Application

It is crucial to understand that Kafka Streams is just a library (a set of JAR files), not a separate server like a database or a message broker.

Think of it like adding a dependency for JSON processing or an HTTP client. When you write a Spring Boot application, you simply include the `kafka-streams` dependency. At runtime, your Spring Boot application creates an instance of `KafkaStreams` internally, which then starts processing data from Kafka topics.

### How to Define It in Spring Boot

Spring Boot provides excellent support that automates the entire lifecycle for you. Here is how to set it up step-by-step:

**1. Add the Dependency**
First, ensure you have the `spring-kafka` dependency in your `pom.xml` or `build.gradle` file. It includes the Kafka Streams library.

**2. Enable Kafka Streams**
Add the `@EnableKafkaStreams` annotation to your main application class or a configuration class. This tells Spring to look for and configure your stream processing logic.

**3. Define Your Processing Logic (Topology)**
This is where the magic happens. You create a method that returns a `KStream` and accepts a `StreamsBuilder`. Spring automatically injects the builder, and your code inside this method defines the processing topology (reading from topics, transforming, writing to topics).

**Important:** Because Spring manages the lifecycle, you do **not** need to manually create a `KafkaStreams` object or call `start()` and `close()`.

### Plain Java vs. Spring Boot

To illustrate the difference, here is how the application startup code compares:

| Aspect            | Plain Java / Kafka Command                                                                                                                                                                    | Spring Boot (Managed)                                                                                                                                                                                                                                             |
| :---------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Lifecycle**     | You must manually create, start, and close the `KafkaStreams` instance.                                                                                                                       | Spring automatically starts and stops the streams when the application context refreshes or shuts down.                                                                                                                                                           |
| **Configuration** | You build a `Properties` object or `StreamsConfig` manually.                                                                                                                                  | You use `application.yml`, `@ConfigurationProperties`, or a `@Bean` for configuration.                                                                                                                                                                            |
| **Code Example**  | `java StreamsBuilder builder = new StreamsBuilder(); // ... define logic ... KafkaStreams streams = new KafkaStreams(builder.build(), props); streams.start(); // Must manage shutdown hook ` | `java @SpringBootApplication @EnableKafkaStreams public class MyApp { // Define logic in a @Bean method @Bean public KStream<String, String> process(StreamsBuilder kStreamBuilder) { kStreamBuilder.stream("input-topic").to("output-topic"); return null; } } ` |

### A Simple Code Example

Here is a complete, minimal example of a Kafka Streams processor inside a Spring Boot application:

```java
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.KStream;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.kafka.annotation.EnableKafkaStreams;

@SpringBootApplication
@EnableKafkaStreams // 1. Enable Streams support
public class MyStreamingApplication {

    public static void main(String[] args) {
        SpringApplication.run(MyStreamingApplication.class, args);
    }

    // 2. Define your processing topology
    @Bean
    public KStream<String, String> kStream(StreamsBuilder kStreamBuilder) {

        // Read from the input topic "my-input-topic"
        KStream<String, String> stream = kStreamBuilder.stream("my-input-topic");

        // Process the data: convert values to upper case
        KStream<String, String> upperCasedStream = stream
            .mapValues(value -> {
                System.out.println("Processing: " + value);
                return value.toUpperCase();
            });

        // Write the result to the output topic "my-output-topic"
        upperCasedStream.to("my-output-topic");

        // Returning the stream is optional; it's mainly defined for its side effects (reading/writing)
        return upperCasedStream;
    }
}
```

### How to Configure It

You can configure your Kafka Streams application (like the `application.id` and the broker address) directly in your `application.properties` or `application.yml` file:

```properties
# application.properties
spring.application.name=my-kafka-streams-app
spring.kafka.bootstrap-servers=localhost:9092
spring.kafka.streams.application-id=${spring.application.name}
spring.kafka.streams.properties.default.key.serde=org.apache.kafka.common.serialization.Serdes$StringSerde
spring.kafka.streams.properties.default.value.serde=org.apache.kafka.common.serialization.Serdes$StringSerde
```

### Running and Scaling

- **Running:** You run this application like any other Spring Boot app: `mvn spring-boot:run` or by executing the JAR file.
- **Scaling:** If your input topic has multiple partitions, you can simply run multiple instances of your Spring Boot application (on the same machine or different machines). Kafka Streams will automatically rebalance the work between them, using Kafka's consumer group protocol.

In summary, you integrate Kafka Streams **into your program** using Spring Boot's `@EnableKafkaStreams` annotation and `StreamsBuilder` bean. It runs right alongside your REST controllers or database access code, not as a separate command-line process.

---

## Kafka Stream (complete sample)

Here's a **complete, runnable Spring Boot Kafka Streams example** with everything you need.

## Project Structure

```
kafka-streams-demo/
├── pom.xml
├── src/main/resources/application.yml
└── src/main/java/com/example/demo/
    ├── DemoApplication.java
    ├── config/
    │   └── KafkaStreamsConfig.java
    ├── stream/
    │   └── OrderStreamProcessor.java
    ├── model/
    │   ├── Order.java
    │   └── EnrichedOrder.java
    └── controller/
        └── OrderController.java
```

## 1. Maven Dependencies (`pom.xml`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.1.5</version>
        <relativePath/>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>kafka-streams-demo</artifactId>
    <version>1.0.0</version>
    <name>Kafka Streams Demo</name>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Web (for REST API) -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Kafka with Streams support -->
        <dependency>
            <groupId>org.springframework.kafka</groupId>
            <artifactId>spring-kafka</artifactId>
        </dependency>

        <!-- Kafka Streams -->
        <dependency>
            <groupId>org.apache.kafka</groupId>
            <artifactId>kafka-streams</artifactId>
        </dependency>

        <!-- JSON Serialization -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
        </dependency>

        <!-- Lombok (optional, reduces boilerplate) -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <!-- For testing -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

## 2. Application Configuration (`application.yml`)

```yaml
spring:
  application:
    name: order-processor

  kafka:
    bootstrap-servers: localhost:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
    consumer:
      group-id: order-consumer-group
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: "*"
        spring.json.type.mapping: order:com.example.demo.model.Order
    streams:
      application-id: ${spring.application.name}
      bootstrap-servers: localhost:9092
      properties:
        default:
          key:
            serde: org.apache.kafka.common.serialization.Serdes$StringSerde
          value:
            serde: org.springframework.kafka.support.serializer.JsonSerde
        # Performance settings
        processing:
          guarantee: exactly_once_v2
        commit:
          interval:
            ms: 1000
        num:
          stream:
            threads: 4
        cache:
          max:
            bytes:
              buffering: 10485760

# Custom application properties
app:
  kafka:
    topics:
      raw-orders: raw-orders
      validated-orders: validated-orders
      high-value-orders: high-value-orders
      order-stats: order-stats
```

## 3. Model Classes

### Order.java

```java
package com.example.demo.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Order {
    private String orderId;
    private String customerId;
    private String productId;
    private Integer quantity;
    private BigDecimal price;
    private String status;
    private LocalDateTime orderDate;

    public BigDecimal getTotalValue() {
        return price.multiply(BigDecimal.valueOf(quantity));
    }
}
```

### EnrichedOrder.java

```java
package com.example.demo.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class EnrichedOrder {
    private String orderId;
    private String customerId;
    private String productId;
    private Integer quantity;
    private BigDecimal price;
    private BigDecimal totalValue;
    private String category;  // e.g., "HIGH_VALUE", "NORMAL", "LOW_VALUE"
    private String status;
    private LocalDateTime processedAt;

    public static EnrichedOrder fromOrder(Order order, String category) {
        return new EnrichedOrder(
            order.getOrderId(),
            order.getCustomerId(),
            order.getProductId(),
            order.getQuantity(),
            order.getPrice(),
            order.getTotalValue(),
            category,
            order.getStatus(),
            LocalDateTime.now()
        );
    }
}
```

### OrderStats.java

```java
package com.example.demo.model;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderStats {
    private String windowStart;
    private String windowEnd;
    private Long totalOrders;
    private BigDecimal totalRevenue;
    private BigDecimal averageOrderValue;
    private String customerId;
}
```

## 4. Kafka Streams Processor

### OrderStreamProcessor.java

```java
package com.example.demo.stream;

import com.example.demo.model.EnrichedOrder;
import com.example.demo.model.Order;
import com.example.demo.model.OrderStats;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.*;
import org.apache.kafka.streams.state.KeyValueStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.support.serializer.JsonSerde;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Duration;

@Component
public class OrderStreamProcessor {

    @Value("${app.kafka.topics.raw-orders}")
    private String rawOrdersTopic;

    @Value("${app.kafka.topics.validated-orders}")
    private String validatedOrdersTopic;

    @Value("${app.kafka.topics.high-value-orders}")
    private String highValueOrdersTopic;

    @Value("${app.kafka.topics.order-stats}")
    private String orderStatsTopic;

    @Autowired
    public void buildPipeline(StreamsBuilder streamsBuilder) {

        // Configure Serdes for JSON
        JsonSerde<Order> orderSerde = new JsonSerde<>(Order.class);
        JsonSerde<EnrichedOrder> enrichedOrderSerde = new JsonSerde<>(EnrichedOrder.class);
        JsonSerde<OrderStats> orderStatsSerde = new JsonSerde<>(OrderStats.class);

        // 1. Read raw orders from input topic
        KStream<String, Order> rawOrders = streamsBuilder.stream(
            rawOrdersTopic,
            Consumed.with(Serdes.String(), orderSerde)
        );

        // 2. Filter invalid orders (example: orders with null orderId or quantity <= 0)
        KStream<String, Order> validOrders = rawOrders
            .filter((key, order) -> {
                if (order.getOrderId() == null || order.getQuantity() <= 0) {
                    System.out.println("Invalid order rejected: " + order);
                    return false;
                }
                return true;
            })
            .peek((key, order) -> System.out.println("Processing order: " + order.getOrderId()));

        // 3. Send valid orders to validated orders topic
        validOrders.to(validatedOrdersTopic, Produced.with(Serdes.String(), orderSerde));

        // 4. Categorize and enrich orders
        KStream<String, EnrichedOrder> enrichedOrders = validOrders
            .mapValues(order -> {
                String category;
                BigDecimal totalValue = order.getTotalValue();

                if (totalValue.compareTo(BigDecimal.valueOf(1000)) > 0) {
                    category = "HIGH_VALUE";
                } else if (totalValue.compareTo(BigDecimal.valueOf(100)) > 0) {
                    category = "MEDIUM_VALUE";
                } else {
                    category = "LOW_VALUE";
                }

                return EnrichedOrder.fromOrder(order, category);
            });

        // 5. Branch to separate streams
        KStream<String, EnrichedOrder>[] branches = enrichedOrders
            .branch(
                (key, order) -> "HIGH_VALUE".equals(order.getCategory()),
                (key, order) -> true  // all others
            );

        // 6. Send high-value orders to special topic for immediate attention
        branches[0].to(highValueOrdersTopic, Produced.with(Serdes.String(), enrichedOrderSerde));

        // 7. Aggregation: Calculate stats per customer using tumbling window (5 minutes)
        TimeWindows timeWindow = TimeWindows.ofSizeWithGrace(Duration.ofMinutes(5), Duration.ofMinutes(1));

        KTable<Windowed<String>, OrderStats> statsTable = validOrders
            .groupBy((key, order) -> order.getCustomerId(), Grouped.with(Serdes.String(), orderSerde))
            .windowedBy(timeWindow)
            .aggregate(
                () -> new OrderStats(null, null, 0L, BigDecimal.ZERO, BigDecimal.ZERO, null),
                (customerId, order, stats) -> {
                    long orderCount = stats.getTotalOrders() + 1;
                    BigDecimal revenue = stats.getTotalRevenue().add(order.getTotalValue());
                    BigDecimal avgValue = revenue.divide(BigDecimal.valueOf(orderCount), 2, BigDecimal.ROUND_HALF_UP);

                    return new OrderStats(
                        null, null, orderCount, revenue, avgValue, customerId
                    );
                },
                Materialized.<String, OrderStats, KeyValueStore<Bytes, byte[]>>as("order-stats-store")
                    .withKeySerde(Serdes.String())
                    .withValueSerde(orderStatsSerde)
            );

        // 8. Convert windowed table to stream and add window timestamps
        KStream<String, OrderStats> statsStream = statsTable
            .toStream()
            .map((windowedKey, stats) -> {
                stats.setWindowStart(windowedKey.window().startTime().toString());
                stats.setWindowEnd(windowedKey.window().endTime().toString());
                return KeyValue.pair(windowedKey.key(), stats);
            });

        // 9. Send stats to output topic
        statsStream.to(orderStatsTopic, Produced.with(Serdes.String(), orderStatsSerde));

        // 10. Print to console for monitoring
        validOrders.foreach((key, order) ->
            System.out.printf("Processed order %s for customer %s, total: $%.2f%n",
                order.getOrderId(), order.getCustomerId(), order.getTotalValue())
        );

        enrichedOrders.foreach((key, order) ->
            System.out.printf("Enriched order %s as %s%n", order.getOrderId(), order.getCategory())
        );
    }
}
```

## 5. REST Controller (to produce test data)

### OrderController.java

```java
package com.example.demo.controller;

import com.example.demo.model.Order;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    @Autowired
    private KafkaTemplate<String, Order> kafkaTemplate;

    @Value("${app.kafka.topics.raw-orders}")
    private String rawOrdersTopic;

    @PostMapping
    public String createOrder(@RequestBody Order order) {
        if (order.getOrderId() == null) {
            order.setOrderId(UUID.randomUUID().toString());
        }
        if (order.getOrderDate() == null) {
            order.setOrderDate(LocalDateTime.now());
        }
        if (order.getStatus() == null) {
            order.setStatus("PENDING");
        }

        kafkaTemplate.send(rawOrdersTopic, order.getCustomerId(), order);
        return "Order submitted: " + order.getOrderId();
    }

    @PostMapping("/test-data")
    public String generateTestData() {
        // Generate sample orders for testing
        String[] customers = {"CUST001", "CUST002", "CUST003", "CUST004"};
        String[] products = {"LAPTOP", "MOUSE", "KEYBOARD", "MONITOR", "PHONE"};

        for (int i = 0; i < 20; i++) {
            Order order = new Order();
            order.setOrderId(UUID.randomUUID().toString());
            order.setCustomerId(customers[i % customers.length]);
            order.setProductId(products[i % products.length]);
            order.setQuantity((i % 5) + 1);
            order.setPrice(BigDecimal.valueOf(100 + (i * 50)));
            order.setStatus("PENDING");
            order.setOrderDate(LocalDateTime.now());

            kafkaTemplate.send(rawOrdersTopic, order.getCustomerId(), order);
        }

        return "Generated 20 test orders";
    }
}
```

## 6. Main Application Class

### DemoApplication.java

```java
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.EnableKafkaStreams;

@SpringBootApplication
@EnableKafkaStreams
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
        System.out.println("Kafka Streams Application Started!");
        System.out.println("Listening for orders...");
    }
}
```

## 7. Running the Application

### Prerequisites

1. Start Kafka and Zookeeper:

```bash
# Start Zookeeper
bin/zookeeper-server-start.sh config/zookeeper.properties

# Start Kafka broker
bin/kafka-server-start.sh config/server.properties
```

2. Create the required topics (optional - Kafka will auto-create if configured):

```bash
bin/kafka-topics.sh --create --topic raw-orders --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
bin/kafka-topics.sh --create --topic validated-orders --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
bin/kafka-topics.sh --create --topic high-value-orders --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
bin/kafka-topics.sh --create --topic order-stats --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
```

### Run the Application

```bash
mvn spring-boot:run
```

### Test the Application

1. **Generate test data:**

```bash
curl -X POST http://localhost:8080/api/orders/test-data
```

2. **Submit a single order:**

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "CUST999",
    "productId": "LAPTOP",
    "quantity": 2,
    "price": 1200.00,
    "status": "PENDING"
  }'
```

3. **Monitor the output topics:**

```bash
# Watch validated orders
bin/kafka-console-consumer.sh --topic validated-orders --bootstrap-server localhost:9092 --from-beginning

# Watch high-value orders
bin/kafka-console-consumer.sh --topic high-value-orders --bootstrap-server localhost:9092 --from-beginning

# Watch order statistics
bin/kafka-console-consumer.sh --topic order-stats --bootstrap-server localhost:9092 --from-beginning
```

## Key Features Demonstrated

This complete example shows:

1. **Filtering**: Rejects invalid orders
2. **Transformation**: Enriches orders with categories
3. **Branching**: Splits high-value orders to a separate stream
4. **Aggregation**: Calculates per-customer statistics with time windows
5. **State management**: Uses state stores for aggregation
6. **JSON Serdes**: Proper serialization/deserialization of complex objects
7. **Peek and ForEach**: Debugging and logging operations
8. **REST API**: Producing data into Kafka
9. **Exactly-once semantics**: Configured for data consistency

The application runs as a single Spring Boot process that both:

- Accepts HTTP requests and produces to Kafka
- Runs Kafka Streams processors that consume and transform data

No external process or command needed for the stream processing itself!

---

# Complete Guide to KStream & KTable Chaining Operators

## Overview of the Streams DSL Operators

Kafka Streams provides a rich set of operators that can be chained together to build complex stream processing pipelines. Here's a comprehensive guide organized by category.

## 1. **Stateless Transformation Operators**

These operators don't maintain state and process each record independently.

### `map()` & `mapValues()`

Transform each record's key and/or value.

```java
// Change both key and value
KStream<String, Order> orderStream = builder.stream("orders");

KStream<String, EnrichedOrder> enriched = orderStream
    .map((key, order) -> {
        // Create new key (customer ID)
        String newKey = order.getCustomerId();
        // Create new value
        EnrichedOrder enriched = new EnrichedOrder(order, "PROCESSED");
        return KeyValue.pair(newKey, enriched);
    });

// Change only value
KStream<String, String> orderIds = orderStream
    .mapValues(order -> order.getOrderId());
```

### `flatMap()` & `flatMapValues()`

One-to-many transformation (1 input → multiple outputs).

```java
// Split order into multiple items
KStream<String, Order> orderStream = builder.stream("orders");

KStream<String, OrderItem> items = orderStream
    .flatMap((key, order) -> {
        List<KeyValue<String, OrderItem>> results = new ArrayList<>();
        for (OrderItem item : order.getItems()) {
            results.add(KeyValue.pair(item.getProductId(), item));
        }
        return results;
    });

// Flat map values only
KStream<String, String> words = textStream
    .flatMapValues(text -> Arrays.asList(text.toLowerCase().split("\\W+")));
```

### `filter()` & `filterNot()`

Selectively pass or block records.

```java
KStream<String, Order> orderStream = builder.stream("orders");

// Keep only high-value orders
KStream<String, Order> highValueOrders = orderStream
    .filter((key, order) -> order.getTotalValue() > 1000);

// Filter out cancelled orders
KStream<String, Order> activeOrders = orderStream
    .filterNot((key, order) -> "CANCELLED".equals(order.getStatus()));
```

### `branch()`

Split stream into multiple streams based on predicates.

```java
KStream<String, Order> orderStream = builder.stream("orders");

KStream<String, Order>[] branches = orderStream.branch(
    (key, order) -> order.getTotalValue() > 1000,  // branch 0: high value
    (key, order) -> order.getTotalValue() > 100,   // branch 1: medium value
    (key, order) -> true                           // branch 2: low value
);

KStream<String, Order> highValue = branches[0];
KStream<String, Order> mediumValue = branches[1];
KStream<String, Order> lowValue = branches[2];
```

### `selectKey()`

Change the key of each record.

```java
KStream<String, Order> orderStream = builder.stream("orders");

// Re-key by customer ID
KStream<String, Order> rekeyed = orderStream
    .selectKey((oldKey, order) -> order.getCustomerId());
```

### `peek()`

Perform side effects without changing the stream (debugging/logging).

```java
KStream<String, Order> orderStream = builder.stream("orders");

KStream<String, Order> logged = orderStream
    .peek((key, order) -> System.out.println("Processing: " + key + " -> " + order))
    .filter((key, order) -> order.getTotalValue() > 100)
    .peek((key, order) -> System.out.println("After filter: " + order));
```

### `through()` / `repartition()`

Materialize stream to an intermediate topic.

```java
KStream<String, Order> orderStream = builder.stream("orders");

// Write to topic and continue processing (useful for re-keying)
KStream<String, Order> repartitioned = orderStream
    .selectKey((key, order) -> order.getCustomerId())
    .through("orders-rekeyed");  // Materialized to topic

// Or using repartition (auto-generates topic name)
KStream<String, Order> repartitioned2 = orderStream
    .selectKey((key, order) -> order.getCustomerId())
    .repartition();
```

## 2. **Stateful Transformation Operators**

These operators maintain state and perform aggregations.

### `groupByKey()` & `groupBy()`

Group records for aggregation.

```java
KStream<String, Order> orderStream = builder.stream("orders");

// Group by existing key
KGroupedStream<String, Order> groupedByKey = orderStream.groupByKey();

// Group by new key
KGroupedStream<String, Order> groupedByCustomer = orderStream
    .groupBy((key, order) -> order.getCustomerId(),
             Grouped.with(Serdes.String(), orderSerde));
```

### `count()` - Count records

```java
KStream<String, Order> orderStream = builder.stream("orders");

// Count orders per customer
KTable<String, Long> orderCounts = orderStream
    .groupBy((key, order) -> order.getCustomerId())
    .count();

// Count with time window (5-minute tumbling windows)
KTable<Windowed<String>, Long> windowedCounts = orderStream
    .groupBy((key, order) -> order.getCustomerId())
    .windowedBy(TimeWindows.ofSizeWithGrace(Duration.ofMinutes(5), Duration.ofSeconds(30)))
    .count();
```

### `reduce()` - Combine values

```java
// Sum order totals per customer
KTable<String, BigDecimal> totalPerCustomer = orderStream
    .groupBy((key, order) -> order.getCustomerId())
    .reduce(
        (order1, order2) -> {
            BigDecimal sum = order1.getTotalValue().add(order2.getTotalValue());
            return new Order(order1.getOrderId(), order1.getCustomerId(),
                           order1.getProductId(), order1.getQuantity(),
                           order1.getPrice(), sum, order1.getStatus());
        }
    );

// Keep highest value order per customer
KTable<String, Order> highestOrder = orderStream
    .groupBy((key, order) -> order.getCustomerId())
    .reduce(
        (order1, order2) ->
            order1.getTotalValue().compareTo(order2.getTotalValue()) > 0 ? order1 : order2
    );
```

### `aggregate()` - Custom aggregation

```java
// Custom aggregate that tracks both count and sum
class OrderStats {
    long count;
    BigDecimal sum;
}

KTable<String, OrderStats> customerStats = orderStream
    .groupBy((key, order) -> order.getCustomerId())
    .aggregate(
        () -> new OrderStats(0, BigDecimal.ZERO),
        (customerId, order, stats) -> {
            stats.count++;
            stats.sum = stats.sum.add(order.getTotalValue());
            return stats;
        },
        Materialized.<String, OrderStats, KeyValueStore<Bytes, byte[]>>as("customer-stats-store")
            .withKeySerde(Serdes.String())
            .withValueSerde(customStatsSerde)
    );
```

## 3. **Windowing Operators**

### Types of Windows

```java
// Tumbling Window (fixed size, non-overlapping)
KStream<String, Order> orders = builder.stream("orders");

KTable<Windowed<String>, Long> tumblingCount = orders
    .groupBy((key, order) -> order.getCustomerId())
    .windowedBy(TimeWindows.ofSizeWithGrace(Duration.ofMinutes(5), Duration.ofSeconds(30)))
    .count();

// Hopping Window (fixed size, overlapping)
KTable<Windowed<String>, Long> hoppingCount = orders
    .groupBy((key, order) -> order.getCustomerId())
    .windowedBy(TimeWindows.ofSizeAndGrace(
        Duration.ofMinutes(5),      // window size
        Duration.ofSeconds(30)      // grace period
    ).advanceBy(Duration.ofMinutes(1)))  // hop size
    .count();

// Sliding Window (based on record timestamps)
KTable<Windowed<String>, Long> slidingCount = orders
    .groupBy((key, order) -> order.getCustomerId())
    .windowedBy(SlidingWindows.ofTimeDifferenceWithGrace(Duration.ofMinutes(5), Duration.ofSeconds(30)))
    .count();

// Session Window (dynamic based on gaps)
KTable<Windowed<String>, Long> sessionCount = orders
    .groupBy((key, order) -> order.getCustomerId())
    .windowedBy(SessionWindows.ofInactivityGapWithGrace(Duration.ofMinutes(5), Duration.ofSeconds(30)))
    .count();
```

## 4. **Join Operators**

### KStream-KStream Joins

```java
KStream<String, Order> orders = builder.stream("orders");
KStream<String, Payment> payments = builder.stream("payments");

// Inner Join
KStream<String, OrderPayment> innerJoin = orders.join(
    payments,
    (order, payment) -> new OrderPayment(order, payment),
    JoinWindows.ofTimeDifferenceWithGrace(Duration.ofMinutes(5), Duration.ofSeconds(30)),
    StreamJoined.with(Serdes.String(), orderSerde, paymentSerde)
);

// Left Join (keep order even without payment)
KStream<String, OrderPayment> leftJoin = orders.leftJoin(
    payments,
    (order, payment) -> new OrderPayment(order, payment != null ? payment : null),
    JoinWindows.ofTimeDifferenceWithGrace(Duration.ofMinutes(5), Duration.ofSeconds(30)),
    StreamJoined.with(Serdes.String(), orderSerde, paymentSerde)
);
```

### KStream-KTable Joins (Enrichment)

```java
KStream<String, Order> orders = builder.stream("orders");
KTable<String, CustomerInfo> customers = builder.table("customers");

// Enrich order with customer info
KStream<String, EnrichedOrder> enrichedOrders = orders.leftJoin(
    customers,
    (order, customerInfo) -> new EnrichedOrder(order, customerInfo)
);

// Foreign key join (for KTable to KTable)
KTable<String, OrderWithCustomer> joined = ordersTable.join(
    customers,
    order -> order.getCustomerId(),  // foreign key extractor
    (order, customer) -> new OrderWithCustomer(order, customer)
);
```

### KTable-KTable Joins

```java
KTable<String, Order> ordersTable = builder.table("orders");
KTable<String, Shipment> shipmentsTable = builder.table("shipments");

// Join orders with shipments
KTable<String, OrderShipment> joined = ordersTable.join(
    shipmentsTable,
    (order, shipment) -> new OrderShipment(order, shipment)
);

// Outer join (keep both sides even if no match)
KTable<String, OrderShipment> outerJoin = ordersTable.outerJoin(
    shipmentsTable,
    (order, shipment) -> new OrderShipment(order, shipment)
);
```

## 5. **KTable Operations**

### Merging KTables

```java
KTable<String, Order> table1 = builder.table("orders-1");
KTable<String, Order> table2 = builder.table("orders-2");

// Merge two tables
KTable<String, Order> merged = table1.merge(table2, (order1, order2) -> {
    // Resolve conflicts: take the latest or combine
    return order1.getTimestamp().isAfter(order2.getTimestamp()) ? order1 : order2;
});
```

### Transforming KTable to KStream

```java
KTable<String, Order> orderTable = builder.table("orders");

// Convert to stream
KStream<String, Order> orderStream = orderTable.toStream();

// Convert to stream with timestamp
KStream<String, Order> orderStreamWithTime = orderTable.toStream(
    (key, value) -> value.getTimestamp().toEpochMilli()
);

// Filter table and convert to stream
KStream<String, Order> highValueOrders = orderTable
    .filter((key, order) -> order.getTotalValue() > 1000)
    .toStream();
```

## 6. **Advanced Chaining Patterns**

### Complex Pipeline Example

```java
@Autowired
public void buildComplexPipeline(StreamsBuilder builder) {

    // 1. Read stream
    KStream<String, Order> orders = builder.stream("raw-orders");

    // 2. Clean and validate
    KStream<String, Order> validOrders = orders
        .filter((key, order) -> order.getOrderId() != null)
        .filterNot((key, order) -> "CANCELLED".equals(order.getStatus()))
        .peek((key, order) -> log.info("Processing order: {}", order.getOrderId()));

    // 3. Re-key and repartition
    KStream<String, Order> rekeyedOrders = validOrders
        .selectKey((key, order) -> order.getCustomerId())
        .through("orders-by-customer");

    // 4. Join with customer info
    KTable<String, CustomerInfo> customers = builder.table("customers");
    KStream<String, EnrichedOrder> enriched = rekeyedOrders
        .leftJoin(customers,
            (order, customer) -> new EnrichedOrder(order, customer));

    // 5. Branch based on value
    KStream<String, EnrichedOrder>[] branches = enriched.branch(
        (key, order) -> order.getTotalValue() > 10000,  // platinum
        (key, order) -> order.getTotalValue() > 1000,   // gold
        (key, order) -> true                            // regular
    );

    // 6. Aggregate platinum orders per hour
    KTable<Windowed<String>, OrderAggregate> platinumAgg = branches[0]
        .groupByKey()
        .windowedBy(TimeWindows.ofSizeWithGrace(Duration.ofHours(1), Duration.ofMinutes(5)))
        .aggregate(
            OrderAggregate::new,
            (key, order, agg) -> agg.addOrder(order),
            Materialized.as("platinum-aggregates")
        );

    // 7. Send to different output topics
    branches[0].to("platinum-orders");
    branches[1].to("gold-orders");
    branches[2].to("regular-orders");

    // 8. Suppress duplicates for final output
    platinumAgg
        .suppress(Suppressed.untilWindowCloses(Suppressed.BufferConfig.unbounded()))
        .toStream()
        .to("platinum-stats");
}
```

### Materialized Views with Interactive Queries

```java
// Create materialized store
KTable<String, Long> orderCounts = orderStream
    .groupBy((key, order) -> order.getCustomerId())
    .count(Materialized.<String, Long, KeyValueStore<Bytes, byte[]>>as("order-counts")
        .withKeySerde(Serdes.String())
        .withValueSerde(Serdes.Long()));

// Query from REST endpoint
@RestController
class QueryController {

    @Autowired
    private InteractiveQueryService queryService;

    @GetMapping("/orders/count/{customerId}")
    public Long getOrderCount(@PathVariable String customerId) {
        ReadOnlyKeyValueStore<String, Long> store =
            queryService.getQueryableStore("order-counts", QueryableStoreTypes.keyValueStore());
        return store.get(customerId);
    }
}
```

## 7. **Error Handling and Recovery**

```java
KStream<String, Order> orders = builder.stream("orders");

// Skip bad records
KStream<String, Order> safeStream = orders
    .mapValues((readOnlyKey, order) -> {
        try {
            return processOrder(order);
        } catch (Exception e) {
            log.error("Failed to process order: {}", order, e);
            return null;  // Skip this record
        }
    })
    .filter((key, value) -> value != null);

// Or send errors to DLQ
KStream<String, Order> streamWithDLQ = orders
    .mapValues((key, order) -> {
        try {
            return transformOrder(order);
        } catch (Exception e) {
            // Send to error topic
            context.forward(key, order, "errors-topic");
            return null;
        }
    })
    .filter((key, value) -> value != null);
```

## Best Practices for Chaining

1. **Use `through()` after re-keying** to materialize and avoid recomputation
2. **Chain `peek()` for debugging** at different stages
3. **Prefer `mapValues()` over `map()`** when key doesn't change (more efficient)
4. **Use `filter()` early** to reduce data volume downstream
5. **Name state stores explicitly** with `Materialized.as()`
6. **Consider operator ordering** for performance (filter before map, etc.)

These operators give you a complete toolkit for building sophisticated stream processing pipelines with Kafka Streams!

---

Below you'll find a complete implementation of the previous Kafka Streams (Java) samples recreated as a fully runnable **ksqlDB** application.

All streaming logic (filtering, enrichment, branching, windows, joins, materialized views) is handled declaratively inside **ksqlDB**, removing the need for custom Java processors.

You can run the entire example using the ksqlDB CLI, a REST API, or embedded in your Spring Boot application via the ksqlDB Java Client.

---

## 1. Setup and Data Model

First, create the underlying Kafka topics and define the required serialization formats (JSON).

```sql
-- Set the default format for all streams/tables
SET 'ksql.schema.registry.url' = 'http://localhost:8081';
SET 'ksql.persistence.default.format.key' = 'KAFKA';
SET 'ksql.persistence.default.format.value' = 'JSON';

-- Create a stream over the raw orders topic (existing Kafka topic)
CREATE STREAM raw_orders (
    orderId VARCHAR,
    customerId VARCHAR,
    productId VARCHAR,
    quantity INTEGER,
    price DECIMAL(10,2),
    status VARCHAR,
    orderDate VARCHAR
) WITH (
    KAFKA_TOPIC = 'raw-orders',
    PARTITIONS = 3,
    VALUE_FORMAT = 'JSON',
    TIMESTAMP = 'orderDate',
    TIMESTAMP_FORMAT = 'yyyy-MM-dd HH:mm:ss.SSS'
);

-- Create a table over the customers topic (changelog topic)
CREATE TABLE customers (
    customerId VARCHAR PRIMARY KEY,
    name VARCHAR,
    tier VARCHAR,
    region VARCHAR
) WITH (
    KAFKA_TOPIC = 'customers',
    VALUE_FORMAT = 'JSON',
    KEY_FORMAT = 'KAFKA'
);

-- (Optional) Create a table over the shipments topic
CREATE TABLE shipments (
    orderId VARCHAR PRIMARY KEY,
    shipmentDate VARCHAR,
    carrier VARCHAR
) WITH (
    KAFKA_TOPIC = 'shipments',
    VALUE_FORMAT = 'JSON',
    KEY_FORMAT = 'KAFKA'
);
```

---

## 2. Stateless Transformations

_(Filtering, mapping, branching, flatMap, peek)_

```sql
-- 2.1 Filter: keep only valid orders (quantity > 0)
CREATE STREAM valid_orders AS
SELECT *
FROM raw_orders
WHERE quantity > 0
EMIT CHANGES;

-- 2.2 Map: select only specific fields
CREATE STREAM order_ids AS
SELECT orderId, customerId
FROM raw_orders
EMIT CHANGES;

-- 2.3 MapValues: derive totalValue = price * quantity
CREATE STREAM orders_with_total AS
SELECT *,
       (price * quantity) AS totalValue
FROM raw_orders
EMIT CHANGES;

-- 2.4 FlatMap: explode order items into individual records
-- (Assume orders have a nested array 'items')
CREATE STREAM exploded_items AS
SELECT orderId,
       EXPLODE(items) AS item
FROM raw_orders
EMIT CHANGES;

-- 2.5 Branch: split into separate streams (high/medium/low value)
CREATE STREAM high_value_orders AS
SELECT *,
       CASE WHEN (price * quantity) > 1000 THEN 'HIGH_VALUE'
            WHEN (price * quantity) > 100  THEN 'MEDIUM_VALUE'
            ELSE 'LOW_VALUE'
       END AS category
FROM raw_orders
EMIT CHANGES;

CREATE STREAM high_value_only AS
SELECT *
FROM high_value_orders
WHERE category = 'HIGH_VALUE'
EMIT CHANGES;

-- 2.6 Peek / Debug (via PRINT or INSERT INTO a debug topic)
-- In ksqlDB you can PRINT a stream to the console:
PRINT raw_orders FROM BEGINNING;
-- Or send the stream to a debug topic:
CREATE STREAM debug_orders
WITH (KAFKA_TOPIC='debug-orders', VALUE_FORMAT='JSON')
AS SELECT * FROM raw_orders
EMIT CHANGES;

-- 2.7 Repartition / Rekey
-- Rekey by customerId and materialize into a new repartitioned stream
CREATE STREAM orders_rekeyed
WITH (KAFKA_TOPIC='orders-by-customer', VALUE_FORMAT='JSON')
AS SELECT * FROM raw_orders
PARTITION BY customerId
EMIT CHANGES;
```

---

## 3. Stateful Aggregations and Windowing

### 3.1 Count, Sum, Reduce

```sql
-- Count orders per customer (KTable)
CREATE TABLE order_counts AS
SELECT customerId,
       COUNT(*) AS order_count
FROM raw_orders
GROUP BY customerId
EMIT CHANGES;

-- Sum of total value per customer
CREATE TABLE revenue_per_customer AS
SELECT customerId,
       SUM(price * quantity) AS total_revenue
FROM raw_orders
GROUP BY customerId
EMIT CHANGES;

-- Custom reduce: keep highest value order per customer
CREATE TABLE highest_order_per_customer AS
SELECT customerId,
       LATEST_BY_OFFSET(orderId) AS orderId,
       MAX(price * quantity) AS highest_total
FROM raw_orders
GROUP BY customerId
EMIT CHANGES;
```

### 3.2 Windowing

```sql
-- Tumbling window (5 minutes) – count orders per customer
CREATE TABLE tumbling_window_counts AS
SELECT customerId,
       WINDOWSTART AS window_start,
       WINDOWEND AS window_end,
       COUNT(*) AS order_count
FROM raw_orders
WINDOW TUMBLING (SIZE 5 MINUTES, RETENTION 7 DAYS, GRACE PERIOD 1 MINUTES)
GROUP BY customerId
EMIT CHANGES;

-- Hopping window (5 min size, 1 min hop)
CREATE TABLE hopping_window_revenue AS
SELECT customerId,
       SUM(price * quantity) AS revenue,
       WINDOWSTART AS window_start
FROM raw_orders
WINDOW HOPPING (SIZE 5 MINUTES, ADVANCE BY 1 MINUTE, RETENTION 7 DAYS)
GROUP BY customerId
EMIT CHANGES;

-- Session window (inactivity gap = 5 minutes)
CREATE TABLE session_window_orders AS
SELECT customerId,
       COUNT(*) AS orders,
       WINDOWSTART AS session_start
FROM raw_orders
WINDOW SESSION (5 MINUTES, RETENTION 7 DAYS, GRACE PERIOD 1 MINUTES)
GROUP BY customerId
EMIT CHANGES;
```

---

## 4. Joins

### 4.1 KStream-KStream Join (inner/left)

```sql
-- Orders and payments streams joined within a 5-minute window
CREATE STREAM orders_payments AS
SELECT o.orderId,
       o.customerId,
       o.totalValue,
       p.paymentId,
       p.amount
FROM orders_with_total o
INNER JOIN payments p
WITHIN 5 MINUTES
ON o.orderId = p.orderId
EMIT CHANGES;

-- Left join (keep order even without payment)
CREATE STREAM orders_left_payments AS
SELECT o.orderId,
       o.customerId,
       o.totalValue,
       p.paymentId,
       p.amount
FROM orders_with_total o
LEFT JOIN payments p
WITHIN 5 MINUTES
ON o.orderId = p.orderId
EMIT CHANGES;
```

### 4.2 KStream-KTable Join (Enrichment)

```sql
-- Enrich orders with customer info from the customers table
CREATE STREAM enriched_orders AS
SELECT o.orderId,
       o.customerId,
       c.name AS customer_name,
       c.tier AS customer_tier,
       o.productId,
       o.quantity * o.price AS totalValue
FROM raw_orders o
LEFT JOIN customers c
ON o.customerId = c.customerId
EMIT CHANGES;
```

### 4.3 KTable-KTable Join

```sql
-- Create tables from the streams (if needed)
CREATE TABLE orders_table AS
SELECT orderId,
       LATEST_BY_OFFSET(customerId) AS customerId,
       LATEST_BY_OFFSET(productId) AS productId,
       LATEST_BY_OFFSET(quantity * price) AS totalValue
FROM raw_orders
GROUP BY orderId
EMIT CHANGES;

-- Join orders with shipments (both tables)
CREATE TABLE orders_with_shipment AS
SELECT o.orderId,
       o.customerId,
       o.totalValue,
       s.carrier,
       s.shipmentDate
FROM orders_table o
INNER JOIN shipments s
ON o.orderId = s.orderId
EMIT CHANGES;
```

---

## 5. Advanced Patterns

### 5.1 Merge Streams

```sql
-- If you have two order streams (e.g., web and mobile) with same schema
CREATE STREAM all_orders AS
SELECT * FROM web_orders
UNION
SELECT * FROM mobile_orders
EMIT CHANGES;
```

### 5.2 Interactive Queries (Materialized Views)

```sql
-- Create a materialized table (by default, ksqlDB makes all aggregations queryable)
CREATE TABLE revenue_by_region AS
SELECT c.region,
       SUM(o.price * o.quantity) AS total_revenue
FROM raw_orders o
LEFT JOIN customers c ON o.customerId = c.customerId
GROUP BY c.region
EMIT CHANGES;

-- Query it directly from ksqlDB CLI or via REST API
SELECT * FROM revenue_by_region WHERE region = 'EUROPE';
```

### 5.3 Suppressing Duplicates (e.g., final results per window)

```sql
-- Using EMIT FINAL to output only after the window closes (suppression)
CREATE TABLE final_window_stats AS
SELECT customerId,
       SUM(price * quantity) AS total,
       COUNT(*) AS cnt
FROM raw_orders
WINDOW TUMBLING (SIZE 5 MINUTES)
GROUP BY customerId
EMIT FINAL;
```

### 5.4 Error Handling / Dead Letter Queue (DLQ)

ksqlDB does not have a built-in DLQ, but you can route errors manually:

```sql
-- Create a stream for valid orders
CREATE STREAM valid_orders AS
SELECT * FROM raw_orders
WHERE quantity > 0 AND orderId IS NOT NULL
EMIT CHANGES;

-- Create a stream for invalid orders (DLQ)
CREATE STREAM invalid_orders
WITH (KAFKA_TOPIC='invalid-orders', VALUE_FORMAT='JSON')
AS SELECT * FROM raw_orders
WHERE NOT (quantity > 0 AND orderId IS NOT NULL)
EMIT CHANGES;
```

---

## 6. Testing and Debugging

### 6.1 Print Stream

```sql
PRINT raw_orders FROM BEGINNING LIMIT 100;
```

### 6.2 Describe and Explain

```sql
DESCRIBE raw_orders EXTENDED;
EXPLAIN raw_orders;
EXPLAIN query_id;
```

### 6.3 Run End-to-End Tests with ksqlDB Testing Tool

```sql
-- In a test file (e.g., test.sql)
CREATE STREAM raw_orders (orderId VARCHAR, customerId VARCHAR, quantity INT, price DECIMAL(10,2)) WITH (kafka_topic='raw-orders', value_format='JSON');
CREATE STREAM valid_orders AS SELECT * FROM raw_orders WHERE quantity > 0 EMIT CHANGES;
ASSERT VALUES valid_orders (orderId, customerId, quantity) VALUES ('ORD1', 'CUST1', 10);
ASSERT VALUES valid_orders (orderId, customerId, quantity) VALUES ('ORD2', 'CUST2', 5);

-- Insert test data
INSERT INTO raw_orders VALUES ('ORD1', 'CUST1', 10, 100.00);
INSERT INTO raw_orders VALUES ('ORD2', 'CUST2', -1, 50.00);  -- should be filtered
```

Run the test:

```bash
ksql-test-runner -i test.sql -o output.json
```

---

## 7. Running as a Spring Boot Application

To embed ksqlDB inside Spring Boot (instead of using Java Kafka Streams):

Add dependency:

```xml
<dependency>
    <groupId>io.confluent.ksql</groupId>
    <artifactId>ksqldb-api-client</artifactId>
    <version>7.5.0</version>
</dependency>
```

Then in your Spring Boot app:

```java
import io.confluent.ksql.api.client.Client;
import io.confluent.ksql.api.client.ClientOptions;
import io.confluent.ksql.api.client.ExecuteStatementResult;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class KsqlDbSpringApp {

    public static void main(String[] args) {
        SpringApplication.run(KsqlDbSpringApp.class, args);
    }

    @Bean
    public Client ksqlClient() {
        return Client.create(
            ClientOptions.create()
                .setHost("localhost")
                .setPort(8088)
        );
    }

    @Bean
    public CommandLineRunner initQueries(Client client) {
        return args -> {
            String createStream = """
                CREATE STREAM IF NOT EXISTS raw_orders (
                    orderId VARCHAR,
                    customerId VARCHAR,
                    quantity INT,
                    price DECIMAL(10,2)
                ) WITH (
                    KAFKA_TOPIC='raw-orders',
                    VALUE_FORMAT='JSON'
                );
                """;
            client.executeStatement(createStream).get();

            String createValidOrders = """
                CREATE STREAM valid_orders AS
                SELECT * FROM raw_orders
                WHERE quantity > 0
                EMIT CHANGES;
                """;
            ExecuteStatementResult result = client.executeStatement(createValidOrders).get();
            System.out.println("Query started: " + result.queryId().orElse("N/A"));
        };
    }
}
```

---

## 8. Complete Pipeline Example

_(This replicates the entire Java sample from the previous answer)_

```sql
-- 1. Read raw orders
CREATE STREAM raw_orders (
    orderId VARCHAR,
    customerId VARCHAR,
    productId VARCHAR,
    quantity INT,
    price DECIMAL(10,2),
    status VARCHAR,
    orderDate VARCHAR
) WITH (KAFKA_TOPIC='raw-orders', VALUE_FORMAT='JSON');

-- 2. Filter invalid orders
CREATE STREAM valid_orders AS
SELECT * FROM raw_orders
WHERE orderId IS NOT NULL AND quantity > 0
EMIT CHANGES;

-- 3. Enrich and categorize
CREATE STREAM enriched_orders AS
SELECT orderId,
       customerId,
       productId,
       quantity,
       price,
       (price * quantity) AS totalValue,
       CASE WHEN (price * quantity) > 1000 THEN 'HIGH_VALUE'
            WHEN (price * quantity) > 100  THEN 'MEDIUM_VALUE'
            ELSE 'LOW_VALUE'
       END AS category,
       status,
       orderDate
FROM valid_orders
EMIT CHANGES;

-- 4. Branch: high value orders
CREATE STREAM high_value_orders AS
SELECT * FROM enriched_orders
WHERE category = 'HIGH_VALUE'
EMIT CHANGES;

-- 5. Aggregation: per-customer stats using tumbling window (5 min)
CREATE TABLE customer_stats AS
SELECT customerId,
       WINDOWSTART as windowStart,
       WINDOWEND as windowEnd,
       COUNT(*) AS totalOrders,
       SUM(price * quantity) AS totalRevenue,
       AVG(price * quantity) AS avgOrderValue
FROM valid_orders
WINDOW TUMBLING (SIZE 5 MINUTES, RETENTION 7 DAYS)
GROUP BY customerId
EMIT FINAL;  -- only emit when window closes

-- 6. Print to console for debugging (optional)
PRINT high_value_orders;
```

---

## Summary: Java Kafka Streams ↔ ksqlDB Mapping

| Java DSL Operator                    | ksqlDB Equivalent                                       |
| ------------------------------------ | ------------------------------------------------------- |
| `filter()`                           | `WHERE` clause                                          |
| `map()`                              | `SELECT` with expressions                               |
| `mapValues()`                        | `SELECT` derived column                                 |
| `flatMap()`                          | `EXPLODE`                                               |
| `branch()`                           | `CASE` + separate `CREATE STREAM`                       |
| `selectKey()`                        | `PARTITION BY`                                          |
| `through()` / `repartition()`        | `CREATE STREAM ... WITH (KAFKA_TOPIC=...) PARTITION BY` |
| `groupByKey()` / `groupBy()`         | `GROUP BY`                                              |
| `count()`, `sum()`, `reduce()`       | `COUNT()`, `SUM()`, `MAX()` / `MIN()` / custom UDAF     |
| `aggregate()`                        | `CREATE TABLE ... AS SELECT ... GROUP BY`               |
| Windows (tumbling, hopping, session) | `WINDOW TUMBLING/HOPPING/SESSION`                       |
| `join()` (KStream-KStream)           | `JOIN ... WITHIN`                                       |
| `join()` (KStream-KTable)            | `JOIN` (no window)                                      |
| `join()` (KTable-KTable)             | `JOIN` on `PRIMARY KEY`                                 |
| `merge()`                            | `UNION`                                                 |
| `suppress()`                         | `EMIT FINAL`                                            |
| Interactive Queries                  | Direct `SELECT` on `TABLE`                              |

With **ksqlDB**, you eliminate all the Java boilerplate and achieve the same functionality using **declarative SQL**. The entire pipeline can be version‑controlled, tested, and deployed as a **single SQL script** – no compilation, no packaging, no custom processors.
