## Kafka

- [back](../README.md)

- [KSQL](./ksql.md)

### Bash Script

- start zookeeper

```bash
%KAFKA_HOME%\bin\windows\zookeeper-server-start.bat %KAFKA_HOME%\config\zookeeper.properties
```

- start kafka server (0, 1, 2)

```bash
%KAFKA_HOME%\bin\windows\kafka-server-start.bat %KAFKA_HOME%\config\server-0.properties
```

- create kafka topic

```bash
%KAFKA_HOME%\bin\windows\kafka-topics.bat --create --topic stock-ticks --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092
```

- kafka producer (done with code or sending a file or send message in command)

```bash
%KAFKA_HOME%\bin\windows\kafka-console-producer.bat --topic stock-ticks --broker-list localhost:9092  < ..\data\sample1.csv
```

- kafka consumer (1, 2)

```bash
%KAFKA_HOME%\bin\windows\kafka-console-consumer.bat --bootstrap-server localhost:9092 --topic stock-ticks --from-beginning --group my_group
```

- describe topic

```bash
%KAFKA_HOME%\bin\windows\kafka-topics.bat --describe  --zookeeper localhost:2181 --topic stock-ticks
```

### Simple Sending Message

```java
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.IntegerSerializer;
import org.apache.kafka.common.serialization.StringSerializer;

public class HelloProduce {
    public static void main(String[] args) {
        System.out.println("Creating Kafka Producer.");
        Properties props = new Properties();

        // "client.id" = "StorageDemo"
        props.put(ProducerConfig.CLIENT_ID_CONFIG, "StorageDemo");
        // "bootstrap.servers" = "localhost:9092,localhost:9093"
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092,localhost:9093");
        // "key.serializer" = IntegerSerializer
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, IntegerSerializer.class.getName());
        // "value.serializer" = StringSerializer
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        KafkaProducer<Integer, String > producer = new KafkaProducer<>(props);

        System.out.println("Start Sending Message.");
        for(int i= 0; i< 1000000; i++){
            producer.send(new ProducerRecord<Integer, String>("stock-ticks", i, "third Message-"+ i));
        }
        System.out.println("Finished Sending Message.");
        producer.close();
    }
}
```

### Transactional Sending Message

--config min.insync.replicas>=2 and --replication-factor>=3 and "transactional.id"=uuid

```bash
%KAFKA_HOME%\bin\windows\kafka-topics.bat --create --bootstrap-server localhost:9092 --topic invoice3 --partitions 5 --replication-factor 3 --config segment.bytes=1000000 --config min.insync.replicas=2
```

```bash
%KAFKA_HOME%\bin\windows\kafka-topics.bat --create --bootstrap-server localhost:9092 --topic invoice4 --partitions 5 --replication-factor 3 --config segment.bytes=1000000 --config min.insync.replicas=2
```

- producer.initTransactions();
- producer.beginTransaction();
- producer.commitTransaction();
- producer.abortTransaction();

```java
public static void main(String[] args) {
        System.out.println("Creating Kafka Producer.");
        Properties props = new Properties();
        // "transactional.id"=uuid
        props.put(ProducerConfig.TRANSACTIONAL_ID_CONFIG, UUID.randomUUID().toString());
        // "client.id" = "StorageDemo"
        props.put(ProducerConfig.CLIENT_ID_CONFIG, "StorageDemo");
        // "bootstrap.servers" = "localhost:9092,localhost:9093"
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092,localhost:9093");
        // "key.serializer" = IntegerSerializer
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, IntegerSerializer.class.getName());
        // "value.serializer" = StringSerializer
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        KafkaProducer<Integer, String > producer = new KafkaProducer<>(props);
        producer.initTransactions();
        try {
            producer.beginTransaction();
            System.out.println("first try...");
            for(int i= 3; i<= 4; i++){
                producer.send(new ProducerRecord<Integer, String>("invoice"+i, i, "first message to invoice1->"+ i));
            }
            producer.commitTransaction();
        }catch (RuntimeException e) {
            System.out.println("Rolling back transaction.");
            producer.abortTransaction();
        }

        try {
            producer.beginTransaction();
            System.out.println("second try...");
            for(int i= 3; i<= 4; i++){
                producer.send(new ProducerRecord<Integer, String>("invoice"+i, i, "second message to invoice->"+ i));
            }
            throw new RuntimeException("Rolling back transaction.");

        }catch (RuntimeException e) {
            System.out.println("Rolling back transaction.");
            producer.abortTransaction();
        }

        System.out.println("Finished Sending Message.");
        producer.close();
    }
```
