### StructuredTaskScope

[back](./README.md)

Parallel Approach with CompletableFuture or ExecutorService

```java
public void generateReport(String stockSymbol)
        throws ExecutionException, InterruptedException {
    CompletableFuture<StockHolding> stockHoldingFuture =
            CompletableFuture.supplyAsync(() -> stockRepository.getStockHolding(stockSymbol));
    CompletableFuture<Double> marketPriceFuture =
            CompletableFuture.supplyAsync(() -> stockAPIClient.getStockPrice(stockSymbol));
    CompletableFuture<String> companyNameFuture =
            CompletableFuture.supplyAsync(() -> stockAPIClient.getCompanyName(stockSymbol));

    StockHolding stock = stockHoldingFuture.get();
    double marketPrice = marketPriceFuture.get();
    String companyName = companyNameFuture.get();

    StockReportData stockReport = new StockReportData(
        stock.symbol(),
        companyName,
        stock.price(),
        stock.quantity(),
        marketPrice,
        stock.quantity() * marketPrice
    );
    printReport(stockReport);
}
```

Basic Usage

```java
public void generateReport(String stockSymbol)
        throws InterruptedException {
    try (var scope = StructuredTaskScope.open()) {
        var stockTask = scope.fork(() -> stockRepository.getStockHolding(stockSymbol));
        var marketPriceTask = scope.fork(() -> stockAPIClient.getStockPrice(stockSymbol));
        var companyNameTask = scope.fork(() -> stockAPIClient.getCompanyName(stockSymbol));

        scope.join();

        StockHolding stock = stockTask.get();
        double marketPrice = marketPriceTask.get();
        String companyName = companyNameTask.get();

        StockReportData stockReport = new StockReportData(
            stock.symbol(),
            companyName,
            stock.price(),
            stock.quantity(),
            marketPrice,
            stock.quantity() * marketPrice
        );
        printReport(stockReport);
    }
}

```

Basic Usage

```java
// Example using ShutdownOnFailure
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    var user = scope.fork(() -> fetchUser(userId));   // Task 1
    var orders = scope.fork(() -> fetchOrders(userId)); // Task 2
    var recommendations = scope.fork(() -> fetchRecs(userId)); // Task 3

    scope.join();            // Waits for all tasks
    scope.throwIfFailed();   // Cancels all if any failed

    // All tasks succeeded, combine the results
    return new Dashboard(user.resultNow(), orders.resultNow(), recommendations.resultNow());
}
// All tasks are guaranteed to be done or canceled when scope is closed
```

Default Joiner

```java
try (var scope = StructuredTaskScope.open()) {
    var stockTask = scope.fork(() -> stockRepository.getStockHolding(stockSymbol));
    var marketPriceTask = scope.fork(() -> stockAPIClient.getStockPrice(stockSymbol));
    var companyNameTask = scope.fork(() -> stockAPIClient.getCompanyName(stockSymbol));

    scope.join(); // Throws exception if any task fails

    // Extract results from individual subtasks
    StockHolding stock = stockTask.get();
    double marketPrice = marketPriceTask.get();
    String companyName = companyNameTask.get();
}

```

All Successful or Throw Joiner

```java
public List<StockPrice> getMultipleStockPrices(List<String> symbols)
        throws InterruptedException {
    try (var scope = StructuredTaskScope.open(
            Joiner.<StockPrice>allSuccessfulOrThrow()
    )) {
        for (String symbol : symbols) {
            scope.fork(() -> stockAPIClient.getStockPrice(symbol));
        }

        return scope.join()
                .map(Subtask::get)
                .toList();
    }
}

```

Any Successful Result or Throw Joiner

```java
public double getStockPrice(String stockSymbol) throws InterruptedException {
    try (var scope = StructuredTaskScope.open(
            Joiner.<Double>anySuccessfulResultOrThrow()
    )) {
        scope.fork(() -> stockAPIClient.getStockPrice(stockSymbol));
        scope.fork(() -> stockAPIClient.getStockPriceSecondServer(stockSymbol));
        scope.fork(() -> stockAPIClient.getStockPriceThirdServer(stockSymbol));

        return scope.join(); // Returns the first successful result
    }
}

```

Await All Joiner

```java

public Map<String, Object> getStockDataWithFallbacks(String stockSymbol)
        throws InterruptedException {
    try (var scope = StructuredTaskScope.open(Joiner.awaitAll())) {
        var priceTask = scope.fork(() -> stockAPIClient.getStockPrice(stockSymbol));
        var companyTask = scope.fork(() -> stockAPIClient.getCompanyName(stockSymbol));
        var newsTask = scope.fork(() -> newsAPIClient.getLatestNews(stockSymbol));

        scope.join(); // No exception thrown

        Map<String, Object> result = new HashMap<>();

        // Check each task individually
        if (priceTask.state() == Subtask.State.SUCCESS) {
            result.put("price", priceTask.get());
        } else {
            result.put("price", "N/A");
        }

        if (companyTask.state() == Subtask.State.SUCCESS) {
            result.put("company", companyTask.get());
        } else {
            result.put("company", "Unknown");
        }

        if (newsTask.state() == Subtask.State.SUCCESS) {
            result.put("news", newsTask.get());
        } else {
            result.put("news", Collections.emptyList());
        }

        return result;
    }
}

```

Inheritance of scoped value bindings

```java
    private static final ScopedValue<String> USERNAME = ScopedValue.newInstance();

    MyResult result = ScopedValue.where(USERNAME, "duke").call(() -> {

        try (var scope = StructuredTaskScope.open()) {

            Subtask<String> subtask1 = scope.fork( .. );    // inherits binding
            Subtask<Integer> subtask2 = scope.fork( .. );   // inherits binding

            scope.join();
            return new MyResult(subtask1.get(), subtask2.get());
        }

    });

```

Basic Configuration

```java
ThreadFactory customFactory = Thread.ofVirtual()
    .name("stock-worker-", 0)
    .factory();
try (var scope = StructuredTaskScope.open(
        Joiner.<StockPrice>allSuccessfulOrThrow(),
        cf -> cf
            .withName("stock-report-generation")
            .withThreadFactory(customFactory)
            .withTimeout(Duration.ofSeconds(5))
)) {
    var stockTask = scope.fork(() -> stockRepository.getStockHolding(stockSymbol));
    var marketPriceTask = scope.fork(() -> stockAPIClient.getStockPrice(stockSymbol));
    var companyNameTask = scope.fork(() -> stockAPIClient.getCompanyName(stockSymbol));

    scope.join();
    // Process results...
}

```

Custom Joiner Implementation

```java
public class FirstSuccessfulJoiner<T> implements Joiner<T> {
    private volatile T result;
    private volatile boolean hasResult = false;

    @Override
    public void onSuccess(Subtask<? extends T> subtask) {
        if (!hasResult) {
            synchronized (this) {
                if (!hasResult) {
                    result = subtask.get();
                    hasResult = true;
                }
            }
        }
    }

    @Override
    public void onFailure(Subtask<?> subtask) {
        // Ignore failures, wait for success
    }

    @Override
    public boolean shouldCancel() {
        return hasResult; // Cancel remaining tasks once we have a result
    }

    @Override
    public T result() {
        return hasResult ? result : null;
    }
}

// Usage
try (var scope = StructuredTaskScope.open(new FirstSuccessfulJoiner<>())) {
    scope.fork(() -> stockAPIClient.getStockPrice(symbol));
    scope.fork(() -> stockAPIClient.getStockPriceSecondServer(symbol));

    return scope.join();
}

```

---

Based on the official Java documentation, `StructuredTaskScope` is still a **preview API** as of Java 21. This means it's fully functional and stable for testing and development, but it's **not yet finalized** for production use without explicit opt-in.

It has been through multiple preview rounds (JDK 19-24) without major changes, indicating the core design is solid and likely to be permanent.

> **Crucial Note**: To use it, you **must enable preview features** using the JVM flag `--enable-preview` during compilation and runtime.

Here are practical examples beyond the basic "all must succeed".

### 🏁 The "Racing" Pattern (First Successful Result)

`ShutdownOnSuccess` is perfect when you only need the fastest successful result, like querying multiple replicas or cache sources.

```java
try (var scope = new StructuredTaskScope.ShutdownOnSuccess<String>()) {
    // Race to fetch from multiple sources
    scope.fork(() -> fetchFromCache(userId));
    scope.fork(() -> fetchFromReplica1(userId));
    scope.fork(() -> fetchFromReplica2(userId));

    scope.join(); // Wait for the first to finish or all to fail

    // Returns the first successful result, throws if all fail
    return scope.result();
}
```

**Behavior**: The first successful subtask wins. The scope automatically cancels other pending tasks.

### 📋 The "All Complete" Pattern (All Must Succeed)

`ShutdownOnFailure` is the standard choice for parallel fetches where you need all results, similar to `CompletableFuture.allOf().

```java
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    Subtask<User> user = scope.fork(() -> fetchUser(userId));
    Subtask<Orders> orders = scope.fork(() -> fetchOrders(userId));
    Subtask<Recommendations> recs = scope.fork(() -> fetchRecs(userId));

    scope.join();
    scope.throwIfFailed(); // Throws if *any* subtask failed

    // All succeeded: combine results
    return new Dashboard(user.get(), orders.get(), recs.get());
}
```

**Behavior**: Waits for all tasks. If any fail, the scope shuts down and `throwIfFailed()` throws an exception.

### 🛠️ The "Ignore Failures" Pattern (Use What Succeeds)

For collecting best-effort data where partial results are acceptable, use the base `StructuredTaskScope` and manually filter results.

```java
try (var scope = new StructuredTaskScope<Object>()) {
    List<Subtask<String>> subtasks = List.of(
        scope.fork(() -> fetchUser(userId)),
        scope.fork(() -> fetchOrders(userId)),
        scope.fork(() -> fetchRecs(userId))
    );

    scope.join(); // Waits for all, regardless of success/failure

    // Filter only successful results
    List<String> successfulResults = subtasks.stream()
        .filter(st -> st.state() == Subtask.State.SUCCESS)
        .map(Subtask::get)
        .collect(Collectors.toList());

    return successfulResults;
}
```

### ✨ The "Custom Policy" Pattern (e.g., First Non-Null)

The built-in policies might not cover all logic (e.g., ignoring `null` returns). You can extend `StructuredTaskScope` to create custom policies like `ShutdownOnNonNullSuccess`.

```java
public class ShutdownOnNonNullSuccess<T> extends StructuredTaskScope<T> {
    private volatile T result;

    @Override
    protected void handleComplete(Subtask<? extends T> subtask) {
        if (subtask.state() == Subtask.State.SUCCESS) {
            T res = subtask.get();
            if (res != null) {
                this.result = res;
                shutdown(); // Stop all other tasks
            }
        }
    }

    public T result() { return result; } // Returns first non-null result
}
```

**Behavior**: This custom scope ignores successful tasks that return `null` and only shuts down when a valid non-null result appears.

### 💡 Key Takeaway

`StructuredTaskScope` is a robust tool for structured concurrency, even in its preview state. If you're comfortable enabling `--enable-preview`, it's highly effective for managing complex concurrent operations in Spring Boot applications. For a full integration example with Spring Boot, you can look at community demos.

For specific use cases within Spring Boot, feel free to ask!
