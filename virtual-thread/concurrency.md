## Concurrency

[back](./README.md)

[Lock Free](#welcome-to-the-lock-free-revolution)

[StampedLock](#stampedlock)

This is where we move from _"what makes an object thread-safe"_ to _"how do we safely share that object between threads."_

You now know that `String` and `Record` are immutable and thread-safe. But **the variable holding them is NOT**. If Thread 1 does `shared = new Record(...)` and Thread 2 reads `shared`, Thread 2 might see `null` or an old, stale value.

This is where `volatile` and `AtomicReference` come in. They are the **messengers** that tell the JVM: _"Hey, this reference changes! Make sure all threads see the latest version!"_

---

## 1. The Problem: CPU Caches and Stale Data

Modern computers have multiple CPU cores. Each core has its own **L1/L2 cache** for speed.

**Without special instructions**, here is what happens:

```java
// Shared across Thread 1 and Thread 2
String config = "old_config";

// Thread 1 (running on Core 0):
config = "new_config";  // Writes to Core 0's cache. Does NOT immediately write to main RAM.

// Thread 2 (running on Core 1):
String local = config;  // Reads from Core 1's cache. Still sees "old_config"!
```

Thread 2 is working with **stale data**. It has no idea that Thread 1 changed the config. This leads to bugs that are nearly impossible to reproduce (they happen randomly, based on CPU scheduling).

**The Fix:** You need a mechanism that forces Thread 1 to flush its write to main RAM, and forces Thread 2 to invalidate its cache and read fresh from main RAM.

`volatile` and `AtomicReference` do exactly this.

---

## 2. `volatile` – The Simplest Visibility Guarantee

The `volatile` keyword tells the JVM: _"This variable will be accessed by multiple threads. Do not cache it locally."_

```java
public class ConfigHolder {
    // The reference itself is volatile
    private volatile Record config = new Record("default");

    public void updateConfig(String newValue) {
        this.config = new Record(newValue); // Write: Flushed immediately to main RAM
    }

    public Record getConfig() {
        return this.config; // Read: Always fetched fresh from main RAM
    }
}
```

**What `volatile` guarantees:**

1. **Visibility:** When Thread 1 writes to `config`, the JVM inserts a **memory barrier** (a special CPU instruction). This forces Thread 1 to flush its cache to main RAM.
2. **Read-Atomicity:** When Thread 2 reads `config`, the JVM forces it to invalidate its local cache and read directly from main RAM. Thread 2 is guaranteed to see the latest value.
3. **Happens-Before Relationship:** If Thread 1 writes to a `volatile` variable, and Thread 2 later reads it, then **ALL** writes Thread 1 did _before_ the volatile write are visible to Thread 2. This is a massive guarantee.

**What `volatile` does NOT guarantee:**

- **Atomicity for compound actions:** `if (config == null) { config = new Record(); }` is NOT safe with volatile. Two threads could both see `null` and both create a new object.
- **Atomicity for read-modify-write:** `config = config;` is safe, but `config = new Record(config.value() + 1)` is NOT.

---

## 3. `AtomicReference` – When You Need Atomic Compare-And-Swap (CAS)

`AtomicReference` is like `volatile` on steroids. It provides **atomic** operations for updating the reference.

```java
import java.util.concurrent.atomic.AtomicReference;

public class ConfigHolder {
    private final AtomicReference<Record> config = new AtomicReference<>(new Record("default"));

    public void updateConfig(String newValue) {
        // Atomic update: The reference is changed in one CPU instruction
        config.set(new Record(newValue));
    }

    public Record getConfig() {
        return config.get(); // Volatile read, guaranteed visibility
    }
}
```

**The Superpower: `compareAndSet()` (CAS)**

This is where `AtomicReference` shines. It lets you update the reference **only if** it hasn't changed since you last looked:

```java
public void atomicUpdate(String newValue) {
    Record oldRecord;
    Record newRecord;

    do {
        oldRecord = config.get(); // Read the current value
        if (oldRecord == null) {
            // Handle null case
            return;
        }
        // Create a new Record based on the old one
        newRecord = new Record(newValue, oldRecord.version() + 1);

        // Try to atomically swap. If someone else changed it, loop and retry.
    } while (!config.compareAndSet(oldRecord, newRecord));
}
```

**Why is this better than `synchronized`?**

- **Lock-free:** CAS is a single CPU instruction (`CMPXCHG` on x86). It doesn't block threads. If two threads try to update simultaneously, one succeeds and the other loops and retries.
- **No context switching:** `synchronized` blocks threads, causing the OS to suspend them and schedule others (costly). CAS is non-blocking and lightning fast.
- **Perfect for immutable objects:** Because `Record` is immutable, we safely create a _new_ version, then atomically swap the reference. The old Record still exists for other threads until they see the new one.

---

## 4. Practical Example: Building a Real-Time Configuration System

Let's combine everything you've learned. Imagine a microservice that reloads configuration from a database every 10 seconds:

```java
// Immutable configuration (Record)
public record AppConfig(
    int maxConnections,
    int timeoutMs,
    String databaseUrl,
    List<String> allowedIps // Defensively copied!
) {
    // Compact constructor for defensive copying
    public AppConfig {
        if (allowedIps != null) {
            allowedIps = List.copyOf(allowedIps); // Deep immutability
        }
    }
}

// Thread-safe holder
public class ConfigService {
    // Volatile guarantees visibility; AtomicReference gives us atomic updates
    private final AtomicReference<AppConfig> currentConfig = new AtomicReference<>();

    public ConfigService() {
        // Load initial config
        this.currentConfig.set(loadFromDatabase());
    }

    // Called by the background reloader thread every 10 seconds
    public void reloadConfig() {
        AppConfig newConfig = loadFromDatabase();
        // Atomic set - all readers will see the new config immediately
        currentConfig.set(newConfig);
        System.out.println("Config reloaded at: " + Instant.now());
    }

    // Called by hundreds of worker threads handling HTTP requests
    public AppConfig getConfig() {
        // Volatile read - guaranteed to see the latest configuration
        return currentConfig.get();
    }

    private AppConfig loadFromDatabase() {
        // Simulate loading from DB
        return new AppConfig(100, 5000, "jdbc:mysql://prod-db:3306",
                            List.of("192.168.1.1", "10.0.0.0/8"));
    }
}
```

**Why this design is brilliant:**

1. **Zero locking:** Hundreds of HTTP worker threads call `getConfig()` simultaneously without any `synchronized` blocks. They just do a lightning-fast volatile read.
2. **Instant updates:** The reloader thread calls `set()`, and the `AtomicReference` immediately flushes the new config to main RAM.
3. **Rollback-safe:** If the new config is corrupt, you can simply `compareAndSet()` back to the old version.
4. **Garbage-friendly:** Old configs become eligible for GC once no thread holds a reference to them.

---

## 5. The Critical Distinction: `volatile` vs. `AtomicReference`

| Feature                      | `volatile`                       | `AtomicReference`            |
| :--------------------------- | :------------------------------- | :--------------------------- |
| **Visibility Guarantee**     | Yes                              | Yes                          |
| **Atomic `set()`**           | Yes (single write)               | Yes                          |
| **Atomic `get()`**           | Yes                              | Yes                          |
| **Atomic `compareAndSet()`** | No                               | **Yes**                      |
| **Atomic `getAndSet()`**     | No                               | **Yes**                      |
| **Atomic `updateAndGet()`**  | No                               | **Yes** (functional updates) |
| **Use Case**                 | Simple flags, single assignments | Complex updates, retry loops |

**When to use which:**

- **Use `volatile`** for simple flags: `private volatile boolean shutdown = false;`
- **Use `volatile`** for immutable objects where you just `set()` and `get()` without conditions.
- **Use `AtomicReference`** when you need conditional updates: _"Only change the config if it hasn't been changed by someone else."_
- **Use `AtomicReference`** for counters or state machines: _"Increment the version, retry if conflict."_

---

## 6. The "Publish" Pattern (How to initialize safely)

There is one more hidden trap. If a thread accesses the reference **while it's being constructed**, it might see a partially built object.

**BAD (Reference escapes during construction):**

```java
public class BadPublish {
    private Record config;

    public BadPublish() {
        this.config = new Record("temp");
        // Reference 'config' is visible to other threads BEFORE construction finishes!
        // This is called "unsafe publication"
    }
}
```

**GOOD (Safe Publication via `volatile` or `AtomicReference`):**

```java
public class GoodPublish {
    private volatile Record config;

    public GoodPublish() {
        // Construct the object fully
        Record temp = new Record("temp");
        // THEN publish it atomically via volatile write
        this.config = temp;
    }
}
```

The JVM's **"final field semantics"** (which we discussed earlier) guarantee that `temp` is fully constructed before the volatile write. Threads reading `config` after construction will see the complete object.

---

## 7. The Performance Impact

You might worry: _"Doesn't flushing to main RAM slow everything down?"_

**Yes, but it's still extremely fast:**

- A normal read: **~1 nanosecond** (CPU cache hit).
- A volatile read: **~10-50 nanoseconds** (forces cache invalidation).
- A `compareAndSet()` (CAS): **~50-100 nanoseconds** (one CPU instruction + memory barrier).
- A `synchronized` lock: **~1,000-10,000 nanoseconds** (OS thread suspension, context switching).

So `volatile` and `AtomicReference` are **100-1000x faster** than locks. Use them liberally for simple state sharing.

---

## The Interview "Aha" Conclusion

When the interviewer asks _"How do you safely publish immutable objects across threads?"_, give them this:

> _"I use `volatile` for simple references where I just need visibility guarantees and only do single assignment or unconditional updates. For more complex scenarios where I need to conditionally update the reference (e.g., 'only update if it hasn't changed'), I use `AtomicReference` with `compareAndSet()`. Both force memory barriers that guarantee visibility across CPU cores without the overhead of `synchronized` locks. This aligns perfectly with immutable objects like `String` and `Record`, because I can safely create a new immutable version and atomically swap the reference, ensuring all threads eventually see the latest state without any locking."_

---

**Where to next?** We can explore:

- **`StampedLock` and `ReadWriteLock`** – When you need to protect mutable state but still want high concurrency.
- **`ThreadLocal`** – How to keep immutable objects _per-thread_ to avoid sharing altogether.
- **The `java.util.concurrent` collections** – `ConcurrentHashMap`, `CopyOnWriteArrayList`, and how they use immutability internally.

---

## Welcome to the **lock-free revolution**!

Your reaction is exactly right. Most developers (and even many senior engineers) spend years using `synchronized` and `ReentrantLock` because that's what they were taught. They don't realize that **modern CPUs can do atomic updates natively in hardware**, completely bypassing the operating system's thread scheduler.

Let me blow your mind: `compareAndSet()` (CAS) is the foundation upon which the _entire_ `java.util.concurrent` package is built. `ConcurrentHashMap`, `AtomicInteger`, `BlockingQueue`—they all use CAS under the hood.

Here is exactly how CAS works, why it destroys locks in performance, and the hidden pitfalls you _must_ know.

---

### 1. What does `compareAndSet()` actually do?

Think of `compareAndSet(expectedValue, newValue)` as a single, atomic CPU instruction that says:

> _"Look at the current value in memory. If it is exactly `expectedValue`, change it to `newValue` in this exact instant. If it is NOT `expectedValue`, do nothing. Tell me if you succeeded."_

**Crucially:** The "check" and the "set" happen as **one single, unbreakable hardware operation**. No other thread can sneak in between the check and the set.

```java
AtomicReference<Record> ref = new AtomicReference<>(new Record("A"));

// Thread 1:
boolean success = ref.compareAndSet(
    expected: new Record("A"),  // I think the current value is "A"
    newValue: new Record("B")   // If so, change it to "B"
);

// If 'success' is true, Thread 1 changed it.
// If 'success' is false, another thread changed it first.
```

---

### 2. The Magic Hardware: The `CMPXCHG` Instruction

Under the hood, `compareAndSet()` maps directly to a CPU instruction called **`CMPXCHG`** (Compare-And-Exchange) on x86 processors.

- This instruction locks the **memory bus** for exactly 1 clock cycle.
- It compares the value in the CPU register with the value in RAM.
- If they match, it writes the new value.
- **No OS involvement.** No thread suspension. No context switching.

**Vs. `synchronized` / `ReentrantLock`:**

- A lock requires the JVM to ask the OS kernel to manage a mutex.
- If a thread can't get the lock, the OS **suspends** the thread (moves it from running to waiting state). This takes about **1,000 to 10,000 nanoseconds**.
- CAS takes about **50 nanoseconds** and never suspends the thread.

---

### 3. The "Retry Loop" Pattern (Optimistic Locking)

Because CAS can fail (if another thread changed the value), we wrap it in a loop. This is called **Optimistic Locking**—we assume collisions are rare, and we just retry if we lose.

**Manual CAS Loop (What you write):**

```java
public void updateVersion(AtomicReference<Record> ref) {
    Record oldRecord;
    Record newRecord;

    do {
        oldRecord = ref.get(); // Read current
        newRecord = new Record(oldRecord.value(), oldRecord.version() + 1);
    } while (!ref.compareAndSet(oldRecord, newRecord)); // Retry if someone else won
}
```

**Functional Style (Java 8+):**

```java
ref.updateAndGet(oldRecord -> new Record(oldRecord.value(), oldRecord.version() + 1));
```

Behind the scenes, `updateAndGet()` does the exact same retry loop for you.

---

### 4. The "ABA" Problem (The Hidden Trap)

This is the #1 interview trap with CAS. Imagine this nightmare scenario:

1. Thread 1 reads value **`A`**.
2. Thread 2 changes value from `A` -> `B` -> **back to `A`**.
3. Thread 1 does `compareAndSet(A, C)` and **succeeds**!
4. Thread 1 _thinks_ nothing changed (because it sees `A`), but the state actually changed twice in between!

**Is this a problem?**

- For simple counters (e.g., `AtomicInteger`), **no**. Replacing 5 with 6, then back to 5, and then to 6 yields the same result.
- For complex objects (e.g., `Record` with a `version` field), **YES!** If you check the version, you might miss intermediate states.

**The Fix: `AtomicStampedReference`**
This tracks a `stamp` (like a version number or timestamp) alongside the reference. CAS checks BOTH the value AND the stamp.

```java
AtomicStampedReference<Record> ref = new AtomicStampedReference<>(new Record("A"), 0);

int[] stampHolder = new int[1];
Record oldRecord = ref.get(stampHolder);
int oldStamp = stampHolder[0];

// Thread 1 tries to update ONLY if the stamp hasn't changed
boolean success = ref.compareAndSet(oldRecord, newRecord, oldStamp, oldStamp + 1);
```

Now if Thread 2 changes `A` -> `B` -> `A`, the stamp goes `0` -> `1` -> `2`. Thread 1's expected stamp (`0`) no longer matches, so the CAS fails correctly.

---

### 5. The Spinning Problem (CPU Burning)

CAS loops are called **"spin-loops"** or **"busy-waiting"**.

**The Problem:** If you have extreme contention (100 threads all trying to update the same reference constantly), they will all spin in a `while` loop, failing CAS, retrying, failing again. This **burns CPU cycles** (near 100% CPU usage) without doing real work.

**When `synchronized` actually wins:**
If contention is _extremely high_, the OS's thread scheduler will suspend threads and let the CPU rest. Locking is slower _when there is no contention_, but can be more efficient _under extreme contention_ because it doesn't waste CPU spinning.

**Best Practice:**

- Use CAS for low-to-medium contention (typical web servers, config updates, counters).
- Use `synchronized` or `ReentrantLock` if you have massive contention and you expect threads to wait for a long time.
- Use **adaptive spinning** (which `ConcurrentHashMap` does internally—it spins for a bit, then falls back to locking).

---

### 6. Compare `compareAndSet()` vs. `synchronized` vs. `ReentrantLock`

Let's build a real-world counter to see the performance difference:

**Option 1: `synchronized` (Pessimistic Locking)**

```java
public class SyncCounter {
    private int count = 0;

    public synchronized void increment() {
        count++; // Lock the entire method
    }
}
```

**Option 2: `ReentrantLock`**

```java
public class LockCounter {
    private final ReentrantLock lock = new ReentrantLock();
    private int count = 0;

    public void increment() {
        lock.lock();
        try {
            count++;
        } finally {
            lock.unlock();
        }
    }
}
```

**Option 3: `AtomicInteger` (CAS)**

```java
public class AtomicCounter {
    private final AtomicInteger count = new AtomicInteger(0);

    public void increment() {
        count.incrementAndGet(); // CAS loop inside!
    }
}
```

**Performance Benchmark (100 threads, 1,000,000 increments each):**
| Approach | Time (ms) | Notes |
| :--- | :--- | :--- |
| **AtomicInteger (CAS)** | **~150 ms** | No OS involvement. |
| **ReentrantLock** | ~800 ms | OS mutex, but fair queuing. |
| **synchronized** | ~900 ms | OS mutex, biased locking. |

**CAS is ~5x faster!** However, if I bump contention to 1,000 threads, CAS starts burning CPU and might slow down, while locks keep CPU usage steady.

---

### 7. The Hidden Magic: `getAndUpdate()` and `accumulateAndGet()`

Java provides built-in functional helpers that use CAS internally, saving you from writing messy loops:

```java
// AtomicReference
ref.getAndUpdate(old -> new Record(old.value(), old.version() + 1));

// For primitive counters
AtomicInteger counter = new AtomicInteger(0);
counter.incrementAndGet(); // Thread-safe ++
counter.addAndGet(5);      // Thread-safe += 5

// For accumulating complex values
counter.accumulateAndGet(10, (old, x) -> old + x);
```

**Why this matters:** The JVM can optimize these loops using **JIT (Just-In-Time) compilation** into highly efficient machine code that spins with minimal overhead.

---

### 8. Real-World Use Case: Building a Non-Blocking Cache

Let's combine everything into a production-grade, lock-free cache:

```java
public class NonBlockingCache<K, V> {
    // We use a Record to hold cache entries with a version stamp
    private record CacheEntry<V>(V value, long version) {}

    private final ConcurrentHashMap<K, AtomicReference<CacheEntry<V>>> cache = new ConcurrentHashMap<>();

    public void put(K key, V value) {
        AtomicReference<CacheEntry<V>> ref = cache.computeIfAbsent(
            key, k -> new AtomicReference<>(new CacheEntry<>(null, 0))
        );

        // Atomic version increment using CAS
        ref.updateAndGet(old -> new CacheEntry<>(value, old.version() + 1));
    }

    public V get(K key) {
        AtomicReference<CacheEntry<V>> ref = cache.get(key);
        if (ref == null) return null;
        return ref.get().value(); // Volatile read
    }

    // Atomic compare-and-swap to only update if value matches
    public boolean replaceIfSame(K key, V oldValue, V newValue) {
        AtomicReference<CacheEntry<V>> ref = cache.get(key);
        if (ref == null) return false;

        CacheEntry<V> current = ref.get();
        if (current.value().equals(oldValue)) {
            // Only update if the version hasn't changed
            return ref.compareAndSet(
                current,
                new CacheEntry<>(newValue, current.version() + 1)
            );
        }
        return false;
    }
}
```

**Why this is beautiful:**

- **Zero locks:** 100 threads can read/write without blocking.
- **Versioning:** If a thread reads a value, another thread updates it, and the first thread tries to update, the version mismatch causes CAS to fail, preventing lost updates.
- **Memory efficient:** Old `CacheEntry` objects become garbage when replaced, but they're small and short-lived.

---

### 9. The Garbage Collection Twist (Hidden Performance Cost)

Here's a subtle issue: **CAS with immutable Records creates a lot of garbage.**

Every time you do:

```java
ref.updateAndGet(old -> new Record(old.value(), old.version() + 1));
```

You create a **new Record object**. If you do this millions of times per second, you create millions of objects for the GC to clean up.

**The Solution:** For high-frequency counters, use `AtomicInteger` or `AtomicLong` (primitives, no garbage). For complex state, accept the garbage, or use **object pooling** (which is rare because it reintroduces contention).

---

### The Interview "Aha" Conclusion

When the interviewer asks _"How does compareAndSet work, and why would you use it over synchronized?"_, give them this:

> _"`compareAndSet()` maps to the CPU's `CMPXCHG` instruction, which atomically compares a memory location to an expected value and updates it if they match—all in a single, non-blocking hardware operation. I use it with a retry loop to implement optimistic locking. This avoids OS-level thread suspension, making it ~5-10x faster than `synchronized` or `ReentrantLock` under moderate contention. However, I must guard against the ABA problem using `AtomicStampedReference` if I need version tracking, and I must be careful that under extreme contention, CAS spin-loops can burn CPU, where locks might actually be more efficient. Finally, CAS works beautifully with immutable Records because I can create a new version and atomically swap the reference without ever mutating the original object."_

---

## StampedLock

You've mastered lock-free CAS for _single references_. But what happens when you have a **large, complex mutable data structure**—like a `HashMap` with 10,000 entries, a giant `ArrayList`, or a complex object graph?

You _cannot_ use CAS on the whole structure (it's too big to compare-and-swap atomically). You _could_ use a single `synchronized` or `ReentrantLock`, but that forces **all threads to wait in line**, even if they just want to read data (which is safe to do concurrently).

**This is where `ReadWriteLock` and its faster cousin `StampedLock` save the day.** They allow **multiple readers** to access the data simultaneously, but give **exclusive access** to writers.

---

## 1. The Problem: The Readers-Writers Dilemma

Imagine a shared `Map<String, UserProfile>` that:

- **Reads** happen 10,000 times per second (HTTP requests fetching user data).
- **Writes** happen 10 times per minute (admins updating user profiles).

**Using `synchronized` (Pessimistic):**

```java
public synchronized UserProfile get(String id) { ... }  // Blocks ALL reads!
public synchronized void put(String id, UserProfile p) { ... }
```

- **Problem:** Thread 2, Thread 3, and Thread 4 all want to read different users. But they all have to wait in a single-file line because Thread 1 is holding the lock for a write.
- **Result:** Massive performance bottleneck. 99% of the time, reads don't conflict with each other, but `synchronized` treats them as if they do.

**The Solution:** Separate locks for reads and writes.

- **Read Lock:** Shared. 100 threads can hold it simultaneously.
- **Write Lock:** Exclusive. Only 1 thread can hold it, and **no readers** can hold it at the same time.

---

## 2. `ReentrantReadWriteLock` – The Classic Solution

This was introduced in Java 5 and is the workhorse for many production systems.

```java
import java.util.concurrent.locks.ReentrantReadWriteLock;

public class ThreadSafeUserCache {
    private final Map<String, UserProfile> cache = new HashMap<>();
    private final ReentrantReadWriteLock rwLock = new ReentrantReadWriteLock();
    private final Lock readLock = rwLock.readLock();
    private final Lock writeLock = rwLock.writeLock();

    // READ operation (can run concurrently)
    public UserProfile get(String userId) {
        readLock.lock();  // Acquire shared lock
        try {
            return cache.get(userId);
        } finally {
            readLock.unlock(); // Always unlock in finally!
        }
    }

    // WRITE operation (exclusive access)
    public void put(String userId, UserProfile profile) {
        writeLock.lock(); // Acquire exclusive lock
        try {
            cache.put(userId, profile);
        } finally {
            writeLock.unlock();
        }
    }

    // READ-MODIFY-WRITE (needs to upgrade)
    public void updateEmail(String userId, String newEmail) {
        // You cannot upgrade from read to write lock directly (would cause deadlock)
        writeLock.lock(); // Must acquire write lock from the start
        try {
            UserProfile profile = cache.get(userId);
            if (profile != null) {
                cache.put(userId, new UserProfile(userId, newEmail, profile.age()));
            }
        } finally {
            writeLock.unlock();
        }
    }
}
```

---

### 3. The "Upgrade" Problem with `ReentrantReadWriteLock`

**Why can't you do this?**

```java
readLock.lock();
try {
    UserProfile p = cache.get(userId);
    // I want to modify this!
    writeLock.lock(); // DEADLOCK! Two threads holding read locks both try to get write lock.
} finally { readLock.unlock(); }
```

**The Deadlock:**

- Thread 1 holds `readLock`. Thread 2 holds `readLock`.
- Thread 1 tries to acquire `writeLock` (must wait for Thread 2 to release `readLock`).
- Thread 2 tries to acquire `writeLock` (must wait for Thread 1 to release `readLock`).
- **Both wait forever.**

**The Fix:** You must release the `readLock` before acquiring the `writeLock`:

```java
readLock.unlock(); // Release read lock
writeLock.lock();  // Now acquire write lock
try {
    // Re-check if the data changed while you released the lock!
    if (cache.containsKey(userId)) {
        // ... update
    }
} finally { writeLock.unlock(); }
```

This creates a **race condition** (another writer might have changed the data in between). You must re-check.

**This is where `StampedLock` becomes revolutionary.**

---

## 4. `StampedLock` – The Super-Fast Upgrade (Java 8+)

`StampedLock` is a faster, more flexible replacement for `ReentrantReadWriteLock`. It provides:

- **Read Lock** (shared, just like before).
- **Write Lock** (exclusive).
- **Optimistic Read Lock** (A lock that doesn't block writers!).
- **Lock Upgrade/Downgrade** (without deadlocks).

**The Superpower: Optimistic Reads**
An optimistic read is **not a lock at all**. It's a "free" read that lets you check later if data was modified.

```java
import java.util.concurrent.locks.StampedLock;

public class OptimisticUserCache {
    private final Map<String, UserProfile> cache = new HashMap<>();
    private final StampedLock stampedLock = new StampedLock();

    // OPTIMISTIC READ (Lock-free, zero contention!)
    public UserProfile get(String userId) {
        // 1. Get a "stamp" (a version number) without locking
        long stamp = stampedLock.tryOptimisticRead();

        // 2. Read the data (no locks held!)
        UserProfile profile = cache.get(userId);

        // 3. Check if any write happened while we were reading
        if (!stampedLock.validate(stamp)) {
            // Oops! A write occurred. Upgrade to a full read lock.
            stamp = stampedLock.readLock();
            try {
                profile = cache.get(userId); // Re-read safely
            } finally {
                stampedLock.unlockRead(stamp);
            }
        }
        return profile;
    }

    // WRITE (Exclusive)
    public void put(String userId, UserProfile profile) {
        long stamp = stampedLock.writeLock();
        try {
            cache.put(userId, profile);
        } finally {
            stampedLock.unlockWrite(stamp);
        }
    }

    // READ -> WRITE UPGRADE (No deadlock!)
    public void updateEmail(String userId, String newEmail) {
        long stamp = stampedLock.readLock();
        try {
            UserProfile profile = cache.get(userId);
            if (profile != null) {
                // Attempt to upgrade read lock to write lock atomically
                long writeStamp = stampedLock.tryConvertToWriteLock(stamp);
                if (writeStamp != 0L) {  // Successfully upgraded!
                    stamp = writeStamp; // Important: update your stamp
                    cache.put(userId, new UserProfile(userId, newEmail, profile.age()));
                } else {
                    // Upgrade failed (another writer got there first)
                    // Release read lock, acquire write lock properly
                    stampedLock.unlockRead(stamp);
                    stamp = stampedLock.writeLock();
                    try {
                        // Re-check because data might have changed
                        profile = cache.get(userId);
                        if (profile != null) {
                            cache.put(userId, new UserProfile(userId, newEmail, profile.age()));
                        }
                    } finally {
                        // We'll unlock at the outer finally block
                    }
                }
            }
        } finally {
            stampedLock.unlock(stamp); // Unlocks whatever lock we're holding (read or write)
        }
    }
}
```

---

## 5. Why `StampedLock` is a Game Changer

| Feature                      | `synchronized` | `ReentrantReadWriteLock` | `StampedLock`                           |
| :--------------------------- | :------------- | :----------------------- | :-------------------------------------- |
| **Multiple Readers**         | No             | Yes                      | Yes                                     |
| **Exclusive Writer**         | Yes            | Yes                      | Yes                                     |
| **Optimistic Reads**         | No             | No                       | **Yes (Zero locking!)**                 |
| **Lock Upgrade**             | N/A            | Deadlock risk            | **Atomic with `tryConvertToWriteLock`** |
| **Performance (Read-heavy)** | Slowest        | Fast                     | **Fastest (near CAS speed)**            |
| **Reentrant**                | Yes            | Yes                      | **No (Not reentrant)**                  |
| **Fairness Option**          | No             | Yes                      | No                                      |

**Performance Numbers:**

- **`synchronized`:** ~100 ns (but only 1 thread at a time).
- **`ReadWriteLock` (read-heavy):** ~50-100 ns per read (low contention).
- **`StampedLock` (optimistic read):** **~10-20 ns per read** (almost as fast as a normal get, because there's zero locking!).

---

## 6. The Hidden Trap: `StampedLock` is NOT Reentrant

This catches everyone off guard. With `ReentrantReadWriteLock`, the same thread can acquire the read lock multiple times.

**This code works with `ReentrantReadWriteLock`:**

```java
readLock.lock();
try {
    // Do something
    readLock.lock(); // It's fine! Reentrant.
    try {
        // Do nested read
    } finally {
        readLock.unlock();
    }
} finally {
    readLock.unlock();
}
```

**This code DEADLOCKS with `StampedLock`:**

```java
long stamp = stampedLock.readLock();
try {
    long nestedStamp = stampedLock.readLock(); // DEADLOCK! The same thread can't acquire it again.
} finally { ... }
```

**The Fix:** Manage your locks carefully. Do not nest `StampedLock` calls. If you need reentrant behavior, stick with `ReentrantReadWriteLock`.

---

## 7. Real-World Use Case: In-Memory Database Cache

Let's build a production-grade cache that reloads from a database every minute:

```java
public class InMemoryDatabaseCache {
    private volatile Map<String, Customer> cache = new HashMap<>(); // Volatile for quick reference
    private final StampedLock lock = new StampedLock();

    // Read-heavy operation (1000 reads/sec)
    public Customer getCustomer(String id) {
        // Step 1: Optimistic read (no locking!)
        long stamp = lock.tryOptimisticRead();
        Customer result = cache.get(id);

        // Step 2: Validate
        if (!lock.validate(stamp)) {
            // A reload happened while we were reading. Use full read lock.
            stamp = lock.readLock();
            try {
                result = cache.get(id);
            } finally {
                lock.unlockRead(stamp);
            }
        }
        return result;
    }

    // Called by background thread every 60 seconds
    public void reloadCache() {
        long stamp = lock.writeLock();
        try {
            // Simulate heavy DB load (takes 2 seconds)
            Map<String, Customer> newCache = loadFromDatabase();

            // Atomic reference swap
            this.cache = newCache; // Volatile write makes this visible immediately

        } finally {
            lock.unlockWrite(stamp);
        }
    }

    // Point-in-time snapshot (thread-safe copy)
    public Map<String, Customer> snapshot() {
        long stamp = lock.readLock();
        try {
            return new HashMap<>(cache); // Copy while locked
        } finally {
            lock.unlockRead(stamp);
        }
    }

    private Map<String, Customer> loadFromDatabase() {
        // Simulate DB query
        return Map.of("1", new Customer("1", "Alice"));
    }
}
```

**Why this design is brilliant:**

- **99.9% of reads** use the optimistic path: **zero locking, zero contention, pure CPU cache speed**.
- The `volatile` reference (`cache`) ensures visibility of the new map without needing the lock for reads.
- The lock is only acquired when a reload is happening (once per minute) or when taking a snapshot.

---

## 8. The "Stamp" is Your Ticket

Always remember: **The `long stamp` is your ticket.** You must use it to unlock:

```java
long stamp = lock.readLock();
try {
    // ... work ...
} finally {
    lock.unlockRead(stamp); // Must pass the same stamp!
}
```

**Forgetting to update the stamp after upgrade is a classic bug:**

```java
long stamp = lock.readLock();
try {
    long ws = lock.tryConvertToWriteLock(stamp);
    if (ws != 0L) {
        // BUG: stamp is still the OLD read lock stamp!
        // Always reassign:
        stamp = ws; // FIX: Update to the write stamp
        // Now do write operations
    }
} finally {
    lock.unlock(stamp); // Now unlocks the correct write lock
}
```

---

## 9. When NOT to use `ReadWriteLock` / `StampedLock`

These locks are not a silver bullet:

| Scenario                                                          | Better Choice                                                                           |
| :---------------------------------------------------------------- | :-------------------------------------------------------------------------------------- |
| **You have very few reads, mostly writes**                        | Use `synchronized` or `ReentrantLock`. The overhead of read/write locks isn't worth it. |
| **Data structure is small (e.g., a single `int`)**                | Use `AtomicInteger` (CAS).                                                              |
| **You need fairness (threads should not starve)**                 | Use `ReentrantReadWriteLock(true)`. `StampedLock` doesn't support fairness.             |
| **You need reentrant locks (same thread locking multiple times)** | Use `ReentrantReadWriteLock`. `StampedLock` is not reentrant.                           |
| **Writes are extremely frequent and long**                        | Use `ConcurrentHashMap` (which uses internal CAS and segmentation).                     |

---

## The Interview "Aha" Conclusion

When the interviewer asks _"How would you protect a large mutable data structure with high read concurrency?"_, give them this:

> _"I would use `StampedLock` for maximum performance. For read-heavy workloads, I'll use `tryOptimisticRead()` which is completely lock-free and gives near-CAS performance. If a write occurred during the optimistic read, I'll validate the stamp and fall back to a full read lock. For write operations, I'll use `writeLock()` exclusively. Unlike `ReentrantReadWriteLock`, `StampedLock` also allows atomic lock upgrade via `tryConvertToWriteLock()`, which avoids the deadlock risk of upgrading read to write locks. However, I must remember that `StampedLock` is not reentrant, so I'll avoid nesting lock calls. For the 99% case where I'm just reading data that rarely changes, optimistic reads give me the best of both worlds: thread-safety without sacrificing performance."_
