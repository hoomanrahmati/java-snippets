[back](./README.md)

## Stateless transformations

### Global Table (input topic -> GlobalKTable)

```java
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.GlobalKTable;

StreamsBuilder builder = new StreamsBuilder();

GlobalKTable<String, Long> wordCounts = builder.globalTable(
    "word-counts-input-topic",
    Materialized.<String, Long, KeyValueStore<Bytes, byte[]>>as(
      "word-counts-global-store" /* table/store name */)
      .withKeySerde(Serdes.String()) /* key serde */
      .withValueSerde(Serdes.Long()) /* value serde */
    );
```

### Branch (KStream -> BranchedKStream)

```java
KStream<String, Long> stream = ...;
Map<String, KStream<String, Long>> branches =
    stream.split(Named.as("Branch-"))
        .branch((key, value) -> key.startsWith("A"),  /* first predicate  */
             Branched.as("A"))
        .branch((key, value) -> key.startsWith("B"),  /* second predicate */
             Branched.as("B"))
        .defaultBranch(Branched.as("C"))              /* default branch */
);

// KStream branches.get("Branch-A") contains all records whose keys start with "A"
// KStream branches.get("Branch-B") contains all records whose keys start with "B"
// KStream branches.get("Branch-C") contains all other records
```

### GroupBy (KStream -> KGroupedStream, KTable -> KGroupedTable)

```java
KStream<byte[], String> stream = ...;
KTable<byte[], String> table = ...;

// Group the stream by a new key and key type
KGroupedStream<String, String> groupedStream = stream.groupBy(
    (key, value) -> value,
    Grouped.with(
      Serdes.String(), /* key (note: type was modified) */
      Serdes.String())  /* value */
  );

// Group the table by a new key and key type, and also modify the value and value type.
KGroupedTable<String, Integer> groupedTable = table.groupBy(
    (key, value) -> KeyValue.pair(value, value.length()),
    Grouped.with(
      Serdes.String(), /* key (note: type was modified) */
      Serdes.Integer()) /* value (note: type was modified) */
  );
```

### Merge (KStream -> KStream)

```java
KStream<byte[], String> stream1 = ...;

KStream<byte[], String> stream2 = ...;

KStream<byte[], String> merged = stream1.merge(stream2);
```

### Stream to Table (KStream -> KTable)

```java
KStream<byte[], String> stream = ...;

KTable<byte[], String> table = stream.toTable();
``
```

### Repartition (KStream -> KStream)

```java
KStream<byte[], String> stream = ... ;
KStream<byte[], String> repartitionedStream = stream.repartition(Repartitioned.numberOfPartitions(10));
```

## Stateful transformations

### Aggregate (KGroupedStream -> KTable, KGroupedTable -> KTable)

```java
KGroupedStream<byte[], String> groupedStream = ...;
KGroupedTable<byte[], String> groupedTable = ...;

// Aggregating a KGroupedStream (note how the value type changes from String to Long)
KTable<byte[], Long> aggregatedStream = groupedStream.aggregate(
    () -> 0L, /* initializer */
    (aggKey, newValue, aggValue) -> aggValue + newValue.length(), /* adder */
    Materialized.<String, Long, KeyValueStore<Bytes, byte[]>>as("aggregated-stream-store") /* state store name */
        .withValueSerde(Serdes.Long()); /* serde for aggregate value */

// Aggregating a KGroupedTable (note how the value type changes from String to Long)
KTable<byte[], Long> aggregatedTable = groupedTable.aggregate(
    () -> 0L, /* initializer */
    (aggKey, newValue, aggValue) -> aggValue + newValue.length(), /* adder */
    (aggKey, oldValue, aggValue) -> aggValue - oldValue.length(), /* subtractor */
    Materialized.<String, Long, KeyValueStore<Bytes, byte[]>>as("aggregated-table-store") /* state store name */
	.withValueSerde(Serdes.Long()) /* serde for aggregate value */
```

### Aggregate (windowed) (KGroupedStream -> KTable)

```java
import java.time.Duration;
KGroupedStream<String, Long> groupedStream = ...;

// Aggregating with time-based windowing (here: with 5-minute tumbling windows)
KTable<Windowed<String>, Long> timeWindowedAggregatedStream = groupedStream.windowedBy(Duration.ofMinutes(5))
    .aggregate(
        () -> 0L, /* initializer */
        (aggKey, newValue, aggValue) -> aggValue + newValue, /* adder */
        Materialized.<String, Long, WindowStore<Bytes, byte[]>>as("time-windowed-aggregated-stream-store") /* state store name */
        .withValueSerde(Serdes.Long())); /* serde for aggregate value */

// Aggregating with time-based windowing (here: with 5-minute sliding windows and 30-minute grace period)
KTable<Windowed<String>, Long> timeWindowedAggregatedStream = groupedStream.windowedBy(SlidingWindows.ofTimeDifferenceAndGrace(Duration.ofMinutes(5), Duration.ofMinutes(30)))
    .aggregate(
        () -> 0L, /* initializer */
        (aggKey, newValue, aggValue) -> aggValue + newValue, /* adder */
        Materialized.<String, Long, WindowStore<Bytes, byte[]>>as("time-windowed-aggregated-stream-store") /* state store name */
        .withValueSerde(Serdes.Long())); /* serde for aggregate value */

// Aggregating with session-based windowing (here: with an inactivity gap of 5 minutes)
KTable<Windowed<String>, Long> sessionizedAggregatedStream = groupedStream.windowedBy(SessionWindows.ofInactivityGapWithNoGrace(Duration.ofMinutes(5)).
    aggregate(
    	() -> 0L, /* initializer */
    	(aggKey, newValue, aggValue) -> aggValue + newValue, /* adder */
        (aggKey, leftAggValue, rightAggValue) -> leftAggValue + rightAggValue, /* session merger */
        Materialized.<String, Long, SessionStore<Bytes, byte[]>>as("sessionized-aggregated-stream-store") /* state store name */
        .withValueSerde(Serdes.Long())); /* serde for aggregate value */
```

### Count (KGroupedStream -> KTable, KGroupedTable -> KTable)

```java
KGroupedStream<String, Long> groupedStream = ...;
KGroupedTable<String, Long> groupedTable = ...;

// Counting a KGroupedStream
KTable<String, Long> aggregatedStream = groupedStream.count();

// Counting a KGroupedTable
KTable<String, Long> aggregatedTable = groupedTable.count();
```

### Count (windowed) (KGroupedStream -> KTable)

```java
import java.time.Duration;
KGroupedStream<String, Long> groupedStream = ...;

// Counting a KGroupedStream with time-based windowing (here: with 5-minute tumbling windows)
KTable<Windowed<String>, Long> aggregatedStream = groupedStream.windowedBy(
    TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5))) /* time-based window */
    .count();

// Counting a KGroupedStream with time-based windowing (here: with 5-minute sliding windows and 30-minute grace period)
KTable<Windowed<String>, Long> aggregatedStream = groupedStream.windowedBy(
    SlidingWindows.ofTimeDifferenceAndGrace(Duration.ofMinutes(5), Duration.ofMinutes(30))) /* time-based window */
    .count();

// Counting a KGroupedStream with session-based windowing (here: with 5-minute inactivity gaps)
KTable<Windowed<String>, Long> aggregatedStream = groupedStream.windowedBy(
    SessionWindows.ofInactivityGapWithNoGrace(Duration.ofMinutes(5))) /* session window */
    .count();
```

### Reduce (KGroupedStream -> KTable, KGroupedTable -> KTable)

```java
KGroupedStream<String, Long> groupedStream = ...;
KGroupedTable<String, Long> groupedTable = ...;

// Reducing a KGroupedStream
KTable<String, Long> aggregatedStream = groupedStream.reduce(
    (aggValue, newValue) -> aggValue + newValue /* adder */);

// Reducing a KGroupedTable
KTable<String, Long> aggregatedTable = groupedTable.reduce(
    (aggValue, newValue) -> aggValue + newValue, /* adder */
    (aggValue, oldValue) -> aggValue - oldValue /* subtractor */);
```

### Reduce (windowed) (KGroupedStream -> KTable)

```java
import java.time.Duration;
KGroupedStream<String, Long> groupedStream = ...;

// Aggregating with time-based windowing (here: with 5-minute tumbling windows)
KTable<Windowed<String>, Long> timeWindowedAggregatedStream = groupedStream.windowedBy(
  TimeWindows.ofSizeWithNoGrace(Duration.ofMinutes(5)) /* time-based window */)
  .reduce(
    (aggValue, newValue) -> aggValue + newValue /* adder */
  );

// Aggregating with time-based windowing (here: with 5-minute sliding windows and 30-minute grace)
KTable<Windowed<String>, Long> timeWindowedAggregatedStream = groupedStream.windowedBy(
  SlidingWindows.ofTimeDifferenceAndGrace(Duration.ofMinutes(5), Duration.ofMinutes(30))) /* time-based window */)
  .reduce(
    (aggValue, newValue) -> aggValue + newValue /* adder */
  );

// Aggregating with session-based windowing (here: with an inactivity gap of 5 minutes)
KTable<Windowed<String>, Long> sessionzedAggregatedStream = groupedStream.windowedBy(
  SessionWindows.ofInactivityGapWithNoGrace(Duration.ofMinutes(5))) /* session window */
  .reduce(
    (aggValue, newValue) -> aggValue + newValue /* adder */
  );
```

### Example of semantics for stream aggregations (KGroupedStream -> KTable)

```java
// Key: word, value: count
KStream<String, Integer> wordCounts = ...;

KGroupedStream<String, Integer> groupedStream = wordCounts
    .groupByKey(Grouped.with(Serdes.String(), Serdes.Integer()));

KTable<String, Integer> aggregated = groupedStream.aggregate(
    () -> 0, /* initializer */
    (aggKey, newValue, aggValue) -> aggValue + newValue, /* adder */
    Materialized.<String, Long, KeyValueStore<Bytes, byte[]>as("aggregated-stream-store" /* state store name */)
      .withKeySerde(Serdes.String()) /* key serde */
      .withValueSerde(Serdes.Integer()); /* serde for aggregate value */
```
