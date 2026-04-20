## 🎯 Quick‑Start: Enabling Caching in a Spring Boot App

[back](../README.md)

| Step | Action                                                                                 | Why                                                                                                  |
| ---- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| 1    | Add the cache starter (`spring-boot-starter-cache`) to **pom.xml** or **build.gradle** | Pulls in Spring’s cache abstraction and the default in‑memory provider (ConcurrentMap)               |
| 2    | Enable the cache subsystem                                                             | `@EnableCaching` tells Spring to create the AOP proxies that intercept your annotated methods        |
| 3    | Pick an underlying **CacheProvider** (optional)                                        | Caffeine, EhCache, Redis, Hazelcast, Infinispan… each brings persistence, eviction, clustering, etc. |
| 4    | Annotate your beans                                                                    | `@Cacheable`, `@CachePut`, `@CacheEvict`, `@Caching`                                                 |
| 5    | Configure (if needed)                                                                  | TTL, maxSize, serialization, etc. via `application.yml` or Java config                               |

---

## 📦 Dependency

**Maven**

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cache</artifactId>
</dependency>

<!-- Optional: pick a provider -->
<dependency>
    <groupId>com.github.ben-manes.caffeine</groupId>
    <artifactId>caffeine</artifactId>
</dependency>
```

**Gradle**

```groovy
implementation 'org.springframework.boot:spring-boot-starter-cache'
implementation 'com.github.ben-manes.caffeine:caffeine'
```

> **Tip:** Spring Boot auto‑configures a `ConcurrentMapCacheManager` if no other provider is on the classpath. For a real‑world app, choose Caffeine (fast & simple) or Redis/Hazelcast for distributed caching.

---

## 📜 Enabling the Cache Layer

```java
@SpringBootApplication
@EnableCaching
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
```

> **Why `@EnableCaching`?**  
> It registers a `CacheInterceptor` and a `CacheAspect` that weave around your annotated methods.

---

## 🔑 Annotation Cheat‑Sheet

| Annotation     | Purpose                                                        | Example                                        |
| -------------- | -------------------------------------------------------------- | ---------------------------------------------- |
| `@Cacheable`   | Cache _return value_ of method call. Skip method if cache hit. | `@Cacheable(value = "users", key = "#id")`     |
| `@CachePut`    | Update cache _after_ method execution (no skip).               | `@CachePut(value = "users", key = "#user.id")` |
| `@CacheEvict`  | Remove one or more entries from cache.                         | `@CacheEvict(value = "users", key = "#id")`    |
| `@Caching`     | Composite: combine multiple caching ops on one method.         |                                                |
| `@CacheConfig` | Set default cacheName/key prefix for a class.                  |                                                |

### Key Generation

| Feature                 | How to use                                                           |
| ----------------------- | -------------------------------------------------------------------- |
| SpEL                    | `key = "#user.id"`                                                   |
| CacheKeyGenerator       | Implement `org.springframework.cache.interceptor.KeyGenerator`       |
| `Cacheable` default key | Concatenation of method arguments (`SimpleKey` or `SimpleKey.EMPTY`) |

> **Pro Tip:** Use meaningful keys (`#id`) rather than default `SimpleKey`. It keeps your cache tidy and readable.

---

## 💡 Common Cache Strategies

| Pattern                        | When to use                                             | Example                                                          |
| ------------------------------ | ------------------------------------------------------- | ---------------------------------------------------------------- |
| **Cache‑aside (Read‑through)** | Store data only on cache miss; fetch from DB if absent. | `@Cacheable` on a service method that loads from a repository.   |
| **Write‑through**              | Update underlying store _and_ cache simultaneously.     | `@CachePut` after a `save` operation.                            |
| **Cache‑eviction**             | When data changes or stale.                             | `@CacheEvict` on `delete`, or schedule cache purge.              |
| **Read‑repair**                | Evict on read failure; re‑fetch on next call.           | Not directly supported, but you can manually remove and re‑load. |

---

## 🗄️ Cache Providers

| Provider                   | Best Use‑Case                                     | Configuration Snippet                                                                                                                                                                                                                                                                                                                                              |
| -------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Caffeine**               | Fast, in‑memory with TTL, maxSize.                | `@Bean CacheManager caffeineCacheManager() { CaffeineCacheManager manager = new CaffeineCacheManager("users"); manager.setCaffeine(Caffeine.newBuilder().expireAfterWrite(10, TimeUnit.MINUTES).maximumSize(10_000)); return manager; }`                                                                                                                           |
| **EhCache**                | Durable, persistence, complex eviction policies.  | Include `ehcache.xml` and `@Bean CacheManager ehCacheCacheManager()`.                                                                                                                                                                                                                                                                                              |
| **Redis**                  | Distributed cache, cross‑node, persistence.       | `@Bean LettuceConnectionFactory redisConnectionFactory() { return new LettuceConnectionFactory(); }` then `@Bean CacheManager redisCacheManager(LettuceConnectionFactory cf) { RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig().entryTtl(Duration.ofHours(1)); return RedisCacheManager.builder(cf).cacheDefaults(config).build(); }` |
| **Hazelcast / Infinispan** | Scalable, near‑line cache with SQL‑like querying. | Use Spring Data `HazelcastCacheManager` etc.                                                                                                                                                                                                                                                                                                                       |

> **Choosing a provider**  
> _Caffeine_ for single‑instance, fast workloads.  
> _Redis_ when you need shared cache between multiple services.  
> _EhCache_ for fine‑grained eviction + persistence in one JVM.

---

## 📊 Real‑World Example

```java
@Service
@CacheConfig(cacheNames = "userCache") // default cache name
public class UserService {

    @Autowired private UserRepository repo;

    // Cache read – default key is all args; we override
    @Cacheable(key = "#id")
    public User findById(Long id) {
        return repo.findById(id).orElseThrow(() -> new NotFoundException(id));
    }

    // Cache update – put into cache after saving
    @CachePut(key = "#result.id") // result of the method
    public User update(User user) {
        return repo.save(user);
    }

    // Invalidate on delete
    @CacheEvict(key = "#id")
    public void delete(Long id) {
        repo.deleteById(id);
    }

    // Composite – update *and* evict
    @Caching(put = @CachePut(key = "#user.id"), evict = @CacheEvict(key = "#user.id", condition = "#user.email == null"))
    public User modify(User user) {
        return repo.save(user);
    }
}
```

**Key take‑aways**

- `@CacheConfig` DRYs up the cache name.
- `@CachePut` uses the _method result_ as the value.
- Condition on `@CacheEvict` – very handy for partial invalidation.

---

## ⚙️ Configuration with `application.yml`

```yaml
spring:
  cache:
    type: caffeine # or redis, ehcache, hazelcast, infinispan
    caffeine:
      spec: maximumSize=5000,expireAfterWrite=5m
    redis:
      time-to-live: 60m # default TTL for all caches
    ehcache:
      config: classpath:ehcache.xml
```

> Spring Boot’s auto‑config picks the right `CacheManager` based on the `spring.cache.type` property.

---

## 📡 HTTP/Controller Caching (Optional)

While Spring’s cache abstraction is meant for _method results_, you can also cache entire HTTP responses:

| Technique                               | Where to use                                            | Notes                                                              |
| --------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------ |
| **`@Cacheable` on controller**          | For expensive REST endpoints that return the same data. | Use `key = "#root.methodName + #id"`; ensure idempotent endpoints. |
| **Spring’s `CacheControl` header**      | For browsers & CDNs.                                    | `CacheControl.noCache().cachePrivate().mustRevalidate()`           |
| **Spring Cloud Gateway caching filter** | Edge service caching.                                   | Use `CacheRequestFilter`, `CacheResponseFilter`                    |

> **Tip:** For APIs, consider _content negotiation_ – cache different media types separately.

---

## 🚀 Performance & Monitoring

| Tool                                                                                  | How to integrate              | What to watch                                                          |
| ------------------------------------------------------------------------------------- | ----------------------------- | ---------------------------------------------------------------------- |
| **Spring Boot Actuator** (`management.endpoints.web.exposure.include=health,metrics`) | `management.metrics.tags.*`   | `caffeine.eviction.count`, `caffeine.cache.hit`, `caffeine.cache.miss` |
| **Micrometer**                                                                        | Already bundled with Actuator | Custom timers for cache hit ratio                                      |
| **JCache (JSR‑107) Metrics**                                                          | Use `JCacheCacheManager`      | `jcache.statistics`                                                    |

> **Cache‑Hit Ratio** = `cacheHits / (cacheHits + cacheMisses)`  
> Aim for >90% for heavy workloads; if lower, evaluate eviction policies or key design.

---

## ⚠️ Common Pitfalls & How to Avoid Them

| Pitfall                                                             | Why it hurts                                      | Mitigation                                                                     |
| ------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Caching void or non‑deterministic methods**                       | Cache stores nothing → wasted memory              | Annotate only pure, read‑only methods                                          |
| **Using `@Cacheable` on `@Transactional` methods that modify data** | Cache may become stale until transaction commits  | Use `@CachePut`/`@CacheEvict` in same transaction or `CacheEvict` after commit |
| **Wrong key generation (e.g., `SimpleKey.EMPTY`)**                  | All entries share the same key → cache collisions | Use SpEL: `key = "#id"`, `key = "#root.methodName + #id"`                      |
| **Cache invalidation gaps**                                         | Stale data served                                 | Combine `@CacheEvict` and `@CachePut` appropriately; consider `@Caching`       |
| **Serialization errors in Redis**                                   | Data never cached                                 | Ensure objects are `Serializable` or provide custom serializers                |
| **Memory leaks in ConcurrentMapCache**                              | Unlimited growth                                  | Prefer a provider with size/TTL limits (Caffeine, EhCache)                     |
| **Thread‑unsafe cache updates**                                     | Race conditions                                   | Most providers handle it; avoid manual manipulation of cache entries           |

---

## 📚 Further Reading & Resources

| Topic                        | Link                                                                       |
| ---------------------------- | -------------------------------------------------------------------------- |
| Spring Cache Documentation   | https://docs.spring.io/spring-framework/reference/integration/caching.html |
| Caffeine Cache               | https://github.com/ben-manes/caffeine                                      |
| Redis Spring Cache           | https://spring.io/guides/gs/redis-cache/                                   |
| EhCache 3                    | https://www.ehcache.org/documentation/3.10/                                |
| Hazelcast Spring Integration | https://hazelcast.org/spring/                                              |
| Micrometer Cache Metrics     | https://micrometer.io/docs/metrics/cache                                   |

---

## 🎯 Bottom Line

1. **Add the starter** → get the abstraction.
2. **Enable caching** → `@EnableCaching`.
3. **Pick a provider** → Caffeine for speed, Redis for shared cluster, etc.
4. **Annotate** → `@Cacheable` for reads, `@CachePut` for updates, `@CacheEvict` for deletes.
5. **Configure** → TTL, maxSize, serialization, monitoring.
6. **Validate** → Use Actuator to see hit/miss stats and adjust.

With these building blocks you can add caching to almost any part of your Spring Boot application—service methods, repository queries, or even entire controller responses—while keeping the logic declarative, testable, and fully supported by Spring’s ecosystem. Happy caching! 🚀

---

## 📦 Using Redis as Spring Boot’s Cache Provider

> The **annotations stay the same** (`@Cacheable`, `@CachePut`, `@CacheEvict`, …).  
> What changes is _where_ the cache lives, how it’s configured, and a few Redis‑specific knobs.

---

## 1️⃣ Add the Dependencies

```xml
<!-- Spring Boot Cache (abstraction) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-cache</artifactId>
</dependency>

<!-- Redis client – Lettuce (recommended) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

> **Why Lettuce?** It’s non‑blocking, supports cluster mode, and works out‑of‑the‑box with Spring Boot’s auto‑config.

---

## 2️⃣ Enable Caching

```java
@SpringBootApplication
@EnableCaching
public class DemoApplication { … }
```

---

## 3️⃣ Configure Redis (YAML)

```yaml
spring:
  cache:
    type: redis # tells Boot to use RedisCacheManager
  redis:
    host: localhost
    port: 6379
    password: ""
    database: 0
    lettuce:
      pool:
        max-active: 8
        max-idle: 8
        min-idle: 0
      shutdown-timeout: 100ms

# Optional: default TTL for all caches
cache:
  redis:
    time-to-live: 60m
```

> **`time-to-live`** is a _default_ that applies to every cache entry.  
> You can override it per‑cache later (see §5).

---

## 4️⃣ Bean‑level Override (Optional)

If you need more control (e.g., custom serializers, separate TTLs, or a different key prefix):

```java
@Configuration
@EnableCaching
public class RedisCacheConfig {

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory cf) {
        // Default config: 60 min TTL
        RedisCacheConfiguration defaultCacheConfig =
                RedisCacheConfiguration.defaultCacheConfig()
                        .entryTtl(Duration.ofMinutes(60))
                        .serializeValuesWith(
                            RedisSerializationContext.SerializationPair.fromSerializer(
                                new GenericJackson2JsonRedisSerializer()));

        // Per‑cache custom config
        Map<String, RedisCacheConfiguration> cacheConfigurations = new HashMap<>();
        cacheConfigurations.put("users", defaultCacheConfig.entryTtl(Duration.ofHours(1)));
        cacheConfigurations.put("orders", defaultCacheConfig.entryTtl(Duration.ofMinutes(30)));

        return RedisCacheManager.builder(cf)
                .cacheDefaults(defaultCacheConfig)
                .withInitialCacheConfigurations(cacheConfigurations)
                .build();
    }
}
```

### What this does

| Feature                           | Effect                                                           |
| --------------------------------- | ---------------------------------------------------------------- |
| `serializeValuesWith`             | Store objects as JSON instead of the default JDK `Serializable`. |
| `.withInitialCacheConfigurations` | Per‑cache TTL (or other) overrides.                              |
| `keyPrefix`                       | You can prepend a common string to all keys (e.g., `myapp::`).   |

> **Tip:** `GenericJackson2JsonRedisSerializer` works for most POJOs and avoids the “not serializable” errors you’d hit with the default Java serializer.

---

## 5️⃣ Using the Annotations (Same as Default)

```java
@Service
@CacheConfig(cacheNames = "users") // defaults to "users" cache
public class UserService {

    @Cacheable(key = "#id")               // ✅ cache hit/miss
    public User findById(Long id) {
        return userRepository.findById(id).orElseThrow();
    }

    @CachePut(key = "#user.id")           // always runs, then updates cache
    public User update(User user) {
        return userRepository.save(user);
    }

    @CacheEvict(key = "#id")              // removes from cache
    public void delete(Long id) {
        userRepository.deleteById(id);
    }
}
```

> **Redis‑specific nuance**: All of the above still works exactly the same. The only difference is that the cache lives in Redis, so the data is shared across _all_ instances of your application.

---

## 6️⃣ Advanced Redis‑Cache Features

| Feature                            | How to Enable                                     | Use‑case                                            |
| ---------------------------------- | ------------------------------------------------- | --------------------------------------------------- |
| **Key Expiration (TTL)**           | `entryTtl(Duration)`                              | Automatic eviction after X time.                    |
| **Redis Eviction Policy**          | In `redis.conf`: `maxmemory-policy allkeys-lru`   | Control what Redis removes when memory is full.     |
| **Redis Cluster**                  | `spring.redis.cluster.nodes`                      | Scale horizontally.                                 |
| **Pub/Sub for Cache Invalidation** | `RedisCacheManager` supports `CacheEventListener` | Custom listeners for external invalidation signals. |
| **Spring Session with Redis**      | `spring.session.store-type=redis`                 | Session data backed by the same Redis instance.     |
| **RedisJSON**                      | Use `org.redisson:redisson` or `redis-json` libs  | Store complex JSON directly in Redis keys.          |

> **Note:** When you’re using a Redis cluster, **key names** must be _hash tags_ (e.g., `myapp:{user:123}`) if you want related keys to land on the same shard. Spring’s `RedisCacheManager` automatically adds a `{}` hash tag around the cache name.

---

## 7️⃣ Common Pitfalls & How to Fix Them

| Pitfall                                         | What Happens                                                                | Fix                                                                                                                                                                                                                   |
| ----------------------------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Wrong serializer → “ClassNotFoundException”** | Redis stores bytes but your app can’t read them.                            | Explicitly set `serializeValuesWith(GenericJackson2JsonRedisSerializer)` as shown above.                                                                                                                              |
| **Cache entries grow indefinitely**             | Using the default `JdkSerializationRedisSerializer` and never setting a TTL | Use JSON serializer _and_ set TTL or a Redis eviction policy.                                                                                                                                                         |
| **Stale data after a write**                    | Updating DB _without_ clearing the Redis entry                              | Use `@CachePut` (or `@CacheEvict` + `@CachePut` in the same transaction).                                                                                                                                             |
| **Key prefix clash**                            | Two caches with same key prefix in the same DB                              | Use unique cache names or enable a custom prefix (`myapp::`).                                                                                                                                                         |
| **Memory‑limited Redis**                        | Redis runs out of memory → keys evicted silently                            | Configure `maxmemory-policy` in `redis.conf` and monitor `redis INFO memory`.                                                                                                                                         |
| **Serialization errors**                        | Trying to cache non‑serializable objects                                    | Use JSON serializer or implement `Serializable`.                                                                                                                                                                      |
| **Distributed consistency issues**              | Assuming a local cache is _coherent_                                        | Remember: Redis is _eventual_ – if you update a cache entry in one instance, all others see the new value instantly. No coherence bugs, but you _must_ keep the TTL/eviction policy in sync with your business logic. |

---

## 8️⃣ Quick “Did‑You‑Know” Checklist

- ✅ **Annotations** – identical to any cache provider.
- ✅ **Cache name** – `@CacheConfig(cacheNames="X")` or `@Cacheable(cacheNames="X")`.
- ✅ **TTL** – `cache.redis.time-to-live` in properties or per‑cache `entryTtl`.
- ✅ **Serialization** – default Java → JSON via `GenericJackson2JsonRedisSerializer`.
- ✅ **Eviction** – Redis handles it; set the policy in `redis.conf`.
- ✅ **Cluster** – configure `spring.redis.cluster.*` and use `{}` hash tags if needed.

---

## 🎯 Bottom‑line Summary

| What Changes        | How it Changes                                                                                     |
| ------------------- | -------------------------------------------------------------------------------------------------- |
| **Provider**        | From in‑memory `ConcurrentMapCache` to distributed Redis.                                          |
| **Configuration**   | Add `spring-boot-starter-data-redis`, set `spring.cache.type=redis`, and tune host/port/TTL.       |
| **Annotations**     | **No change at all** – `@Cacheable`, `@CachePut`, `@CacheEvict`, `@Caching` work exactly the same. |
| **Behavior**        | Cache entries live in Redis → shared across all nodes, subject to Redis’ own eviction policies.    |
| **Advanced tuning** | TTL, serialization, cluster mode, memory policies, Pub/Sub listeners, etc.                         |

So, if you already have Redis running (local, Docker, cluster, etc.), you can drop the extra configuration above, let Spring Boot auto‑configure the `RedisCacheManager`, and start annotating _any_ service method. The only real differences are the properties you tweak and the fact that the cache is now a distributed data store you can inspect, monitor, and scale independently. Happy caching! 🚀
