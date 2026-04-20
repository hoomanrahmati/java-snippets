## JDBC

[back](../README.md)

Below is a **complete, minimal, and ready‑to‑run example** that shows how to build a CRUD (Create‑Read‑Update‑Delete) layer with _plain JDBC_ (`spring-boot-starter-jdbc`) and make every operation transactional.

> **Why transactional with plain JDBC?**  
> Spring’s `JdbcTemplate` is just a helper – the real transaction support comes from `org.springframework.transaction`.  
> In a Spring‑Boot application this is auto‑configured (via `DataSourceTransactionManagerAutoConfiguration`) as long as you have a `DataSource` bean, so you can simply annotate your service layer with `@Transactional` and everything works.

---

## 1. Project setup

```xml
<!-- pom.xml (Spring Boot 3.x, Java 21) -->
<project xmlns="http://maven.apache.org/POM/4.0.0" …>
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.example</groupId>
  <artifactId>jdbc-crud-demo</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <packaging>jar</packaging>

  <properties>
    <java.version>21</java.version>
    <spring-boot.version>3.3.0</spring-boot.version>
  </properties>

  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-dependencies</artifactId>
        <version>${spring-boot.version}</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>

  <dependencies>
    <!-- Spring Boot JDBC starter (adds spring-tx, jdbcTemplate, HikariCP) -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-jdbc</artifactId>
    </dependency>

    <!-- H2 DB for quick demo -->
    <dependency>
      <groupId>com.h2database</groupId>
      <artifactId>h2</artifactId>
      <scope>runtime</scope>
    </dependency>

    <!-- Web (REST) starter -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>

    <!-- Lombok (optional – makes DTOs concise) -->
    <dependency>
      <groupId>org.projectlombok</groupId>
      <artifactId>lombok</artifactId>
      <optional>true</optional>
    </dependency>

    <!-- Testing -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
</project>
```

> **Tip** – if you prefer Gradle, the same dependencies apply.

---

## 2. `application.yml`

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;MODE=PostgreSQL
    username: sa
    password:
    driver-class-name: org.h2.Driver

  h2:
    console:
      enabled: true
      path: /h2-console
```

> _We use an in‑memory H2 database. The `MODE=PostgreSQL` flag makes the syntax close to PostgreSQL, which is handy if you later switch to a real DB._

---

## 3. Domain object

```java
// Person.java
package com.example.jdbccruddemo.model;

import lombok.*;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class Person {
    private Long id;
    private String name;
    private String email;
}
```

> _If you don’t want Lombok, just write a POJO with getters/setters._

---

## 4. Repository – JDBC‑centric

```java
// PersonRepository.java
package com.example.jdbccruddemo.repository;

import com.example.jdbccruddemo.model.Person;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.*;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;

@Repository
public class PersonRepository {

    private final NamedParameterJdbcTemplate jdbcTemplate;
    private final RowMapper<Person> rowMapper = new PersonRowMapper();

    public PersonRepository(NamedParameterJdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /* ---------- CRUD ---------- */

    public Person save(Person person) {
        if (person.getId() == null) {
            // INSERT
            String sql = "INSERT INTO person (name, email) VALUES (:name, :email)";
            MapSqlParameterSource params = new MapSqlParameterSource()
                    .addValue("name", person.getName())
                    .addValue("email", person.getEmail());

            jdbcTemplate.update(sql, params);
            // retrieve generated key
            Long id = jdbcTemplate.queryForObject(
                    "SELECT LAST_INSERT_ID()", Long.class); // works for H2
            person.setId(id);
            return person;
        } else {
            // UPDATE
            String sql = "UPDATE person SET name = :name, email = :email WHERE id = :id";
            MapSqlParameterSource params = new MapSqlParameterSource()
                    .addValue("id", person.getId())
                    .addValue("name", person.getName())
                    .addValue("email", person.getEmail());
            jdbcTemplate.update(sql, params);
            return person;
        }
    }

    public Optional<Person> findById(Long id) {
        String sql = "SELECT * FROM person WHERE id = :id";
        try {
            Person p = jdbcTemplate.queryForObject(sql, Map.of("id", id), rowMapper);
            return Optional.of(p);
        } catch (EmptyResultDataAccessException e) {
            return Optional.empty();
        }
    }

    public List<Person> findAll() {
        String sql = "SELECT * FROM person";
        return jdbcTemplate.query(sql, rowMapper);
    }

    public void deleteById(Long id) {
        String sql = "DELETE FROM person WHERE id = :id";
        jdbcTemplate.update(sql, Map.of("id", id));
    }

    /* ---------- RowMapper ---------- */
    private static class PersonRowMapper implements RowMapper<Person> {
        @Override
        public Person mapRow(ResultSet rs, int rowNum) throws SQLException {
            return new Person(
                    rs.getLong("id"),
                    rs.getString("name"),
                    rs.getString("email")
            );
        }
    }
}
```

> **Why `NamedParameterJdbcTemplate`?**  
> It lets you use named parameters (`:name`) which makes SQL more readable and easier to maintain.

---

## 5. Service – transactional façade

```java
// PersonService.java
package com.example.jdbccruddemo.service;

import com.example.jdbccruddemo.model.Person;
import com.example.jdbccruddemo.repository.PersonRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
public class PersonService {

    private final PersonRepository repo;

    public PersonService(PersonRepository repo) {
        this.repo = repo;
    }

    /* ---------- CRUD with @Transactional ---------- */

    @Transactional // defaults: propagation REQUIRED, readOnly = false
    public Person create(Person person) {
        return repo.save(person);
    }

    @Transactional(readOnly = true)
    public Optional<Person> read(Long id) {
        return repo.findById(id);
    }

    @Transactional(readOnly = true)
    public List<Person> list() {
        return repo.findAll();
    }

    @Transactional
    public Person update(Person person) {
        return repo.save(person); // same method handles update
    }

    @Transactional
    public void delete(Long id) {
        repo.deleteById(id);
    }

    /* ---------- Example of a multi‑step transaction ---------- */

    @Transactional
    public void createAndSendWelcomeEmail(Person person, String emailBody) {
        // 1. Insert person
        Person saved = repo.save(person);

        // 2. (Imagine we send an email here – omitted)
        // If the email sending throws an unchecked exception,
        // the insert will be rolled back automatically.
    }
}
```

**Key points**

- `@Transactional` is applied on the _service_ layer – that’s the conventional pattern because the service represents a business operation that may touch many DAOs or other collaborators.
- The default propagation is `REQUIRED` (start a new transaction if none exists, otherwise join the current one).  
  `readOnly = true` is a hint to the underlying database that no data will be modified – useful for `SELECT`‑heavy services.
- If an unchecked exception (`RuntimeException` or subclass) is thrown from a transactional method, Spring automatically rolls back the transaction.  
  Checked exceptions are **not** rolled back unless you configure `@Transactional(rollbackFor = ...)`.

---

## 6. REST Controller (optional but handy for manual testing)

```java
// PersonController.java
package com.example.jdbccruddemo.controller;

import com.example.jdbccruddemo.model.Person;
import com.example.jdbccruddemo.service.PersonService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/persons")
public class PersonController {

    private final PersonService service;

    public PersonController(PersonService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<Person> create(@RequestBody Person person) {
        Person created = service.create(person);
        return ResponseEntity.ok(created);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Person> read(@PathVariable Long id) {
        return service.read(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping
    public List<Person> list() {
        return service.list();
    }

    @PutMapping("/{id}")
    public ResponseEntity<Person> update(@PathVariable Long id, @RequestBody Person person) {
        person.setId(id);
        return ResponseEntity.ok(service.update(person));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
```

> With the controller you can test the CRUD endpoints via `curl` or Postman.

---

## 7. Database schema

Spring Boot will create the table for you via an `schema.sql` file located on the classpath (or you can use a JPA schema generator).

Create `src/main/resources/schema.sql`:

```sql
CREATE TABLE person (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(200) NOT NULL
);
```

> H2 interprets `AUTO_INCREMENT` as an identity column, which is perfect for our demo.

---

## 8. Running the demo

```bash
./mvnw spring-boot:run
```

_You should see something like:_

```
2026-04-14 12:34:56.789  INFO 12345 --- [           main] c.e.jd.PersonApplication          : Starting PersonApplication using Java 21.0.3 …
...
2026-04-14 12:35:01.234  INFO 12345 --- [  restartedMain] o.s.b.c.e.PropertySourceLoader   : Loaded PropertySource 'classpath:/application.yml'
...
```

Open a browser to `http://localhost:8080/h2-console` – connect with URL `jdbc:h2:mem:testdb`, username `sa`, no password.  
You can run queries directly against the `PERSON` table to verify inserts/updates/deletes.

---

## 9. Quick sanity test (JUnit + @SpringBootTest)

```java
// PersonServiceIntegrationTest.java
package com.example.jdbccruddemo;

import com.example.jdbccruddemo.model.Person;
import com.example.jdbccruddemo.service.PersonService;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public class PersonServiceIntegrationTest {

    @Autowired PersonService service;

    private static Long createdId;

    @Test @Order(1)
    void create() {
        Person p = service.create(new Person(null, "John Doe", "john@example.com"));
        assertNotNull(p.getId());
        createdId = p.getId();
    }

    @Test @Order(2)
    void read() {
        Optional<Person> opt = service.read(createdId);
        assertTrue(opt.isPresent());
        assertEquals("John Doe", opt.get().getName());
    }

    @Test @Order(3)
    void update() {
        Person updated = new Person(createdId, "Jane Doe", "jane@example.com");
        Person result = service.update(updated);
        assertEquals("Jane Doe", result.getName());
    }

    @Test @Order(4)
    void list() {
        List<Person> list = service.list();
        assertEquals(1, list.size());
    }

    @Test @Order(5)
    void delete() {
        service.delete(createdId);
        assertTrue(service.read(createdId).isEmpty());
    }
}
```

Run `./mvnw test` – all tests should pass, demonstrating that the CRUD operations are indeed transactional (if you add a `RuntimeException` inside a service method, the changes will be rolled back).

---

## 10. Recap

| Feature              | How it’s done                                                                                                      |
| -------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Spring Boot JDBC** | `spring-boot-starter-jdbc` (includes `JdbcTemplate`, `NamedParameterJdbcTemplate`, `DataSourceTransactionManager`) |
| **Schema**           | `schema.sql` (auto‑executed)                                                                                       |
| **DAO**              | `PersonRepository` with `NamedParameterJdbcTemplate`                                                               |
| **Transactional**    | `@Transactional` on service layer (`@Service`)                                                                     |
| **Read‑only**        | `@Transactional(readOnly = true)` for `SELECT` operations                                                          |
| **Propagation**      | Default `REQUIRED` (new tx if none)                                                                                |
| **Rollback**         | Unchecked exceptions → rollback automatically                                                                      |
| **Testing**          | `@SpringBootTest` + JUnit to verify transactions                                                                   |

With this scaffold you can:

1. **Add more tables** – create a new repository/service pair.
2. **Move to a real DB** – just change the datasource URL/credentials in `application.yml`.
3. **Scale** – no ORM overhead, direct SQL gives you the flexibility you need.

Happy coding! 🚀

---

Below is a **step‑by‑step recipe** that turns the “plain‑JDBC CRUD” demo into

1. **Asynchronous service methods** (`@Async`) – useful for long‑running queries or for off‑loading work from a request thread.
2. **Paginated `findAll`** – you can now ask for “page 5, size 20” and get a `Page<Person>` object.

> **TL;DR**  
> _Enable `@Async`, return a `CompletableFuture`, add a `PageRequest` helper, and rewrite the repository’s `findAll` to use `LIMIT/OFFSET`._

---

## 1. Enable Spring Async

```java
// PersonApplication.java
package com.example.jdbccruddemo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync          // <<< activates @Async processing
public class PersonApplication {
    public static void main(String[] args) {
        SpringApplication.run(PersonApplication.class, args);
    }
}
```

### Custom thread pool (optional but recommended)

Spring comes with a `SimpleAsyncTaskExecutor` that creates **one thread per task** – not what you want in production.

```java
// AsyncConfig.java
package com.example.jdbccruddemo.config;

import org.springframework.context.annotation.*;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

@Configuration
public class AsyncConfig {

    @Bean("asyncExecutor")
    public Executor asyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);   // tweak as needed
        executor.setMaxPoolSize(8);
        executor.setQueueCapacity(500);
        executor.setThreadNamePrefix("async-");
        executor.initialize();
        return executor;
    }
}
```

> **Tip** – If you don’t declare a bean, Spring will fall back to a _single‑thread_ executor, which defeats the purpose of async.

---

## 2. Repository – add a paginated `findAll`

We’ll expose two repository methods:

| Name                | SQL                                               | Purpose                |
| ------------------- | ------------------------------------------------- | ---------------------- |
| `count()`           | `SELECT COUNT(*) FROM PERSON`                     | Total number of rows   |
| `findAll(Pageable)` | `SELECT … ORDER BY id LIMIT :size OFFSET :offset` | The page you requested |

### Pageable / PageRequest helpers

Spring Data already ships with `org.springframework.data.domain.Pageable` and `PageRequest`, but we’ll keep it minimal to avoid pulling the whole _Spring Data_ stack.

```java
// Pageable.java
package com.example.jdbccruddemo.util;

public interface Pageable {
    int getPageNumber();   // 0‑based
    int getPageSize();     // items per page
}
```

```java
// PageRequest.java
package com.example.jdbccruddemo.util;

public final class PageRequest implements Pageable {
    private final int page;   // 0‑based
    private final int size;   // items per page

    private PageRequest(int page, int size) {
        this.page = page;
        this.size = size;
    }

    public static PageRequest of(int page, int size) {
        if (page < 0) throw new IllegalArgumentException("page must be >= 0");
        if (size <= 0) throw new IllegalArgumentException("size must be > 0");
        return new PageRequest(page, size);
    }

    @Override public int getPageNumber() { return page; }

    @Override public int getPageSize()   { return size; }

    public int getOffset() { return page * size; }
}
```

### Repository changes

```java
// PersonRepository.java
package com.example.jdbccruddemo.repository;

import com.example.jdbccruddemo.model.Person;
import com.example.jdbccruddemo.util.Pageable;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.*;

@Repository
public class PersonRepository {

    private final NamedParameterJdbcTemplate jdbc;
    private final PersonRowMapper mapper = new PersonRowMapper();

    public PersonRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /* ------------------------------------------------------------------- */
    /* 1️⃣  count() – used by the service to build the Page metadata */
    /* ------------------------------------------------------------------- */
    public long count() {
        String sql = "SELECT COUNT(*) FROM person";
        return jdbc.queryForObject(sql, Collections.emptyMap(), Long.class);
    }

    /* ------------------------------------------------------------------- */
    /* 2️⃣  findAll(Pageable) – returns the sliced list */
    /* ------------------------------------------------------------------- */
    public List<Person> findAll(Pageable pageable) {
        String sql = """
            SELECT id, name, email
            FROM person
            ORDER BY id
            LIMIT :limit OFFSET :offset
            """;

        Map<String, Object> params = new HashMap<>();
        params.put("limit", pageable.getPageSize());
        params.put("offset", pageable.getOffset());

        return jdbc.query(sql, params, mapper);
    }
}
```

> **Why `LIMIT/OFFSET`?**  
> H2 (and the most common RDBMSes – MySQL, PostgreSQL, SQL Server, Oracle 12c+) support `LIMIT` + `OFFSET`.  
> If you prefer `TOP` n + ROW_NUMBER, you can adapt the SQL accordingly – the idea is the same.

---

## 2. Service – add async & pagination

```java
// PersonService.java
package com.example.jdbccruddemo.service;

import com.example.jdbccruddemo.model.Person;
import com.example.jdbccruddemo.repository.PersonRepository;
import com.example.jdbccruddemo.util.PageRequest;
import com.example.jdbccruddemo.util.Pageable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.*;

import java.util.List;
import java.util.concurrent.CompletableFuture;

public interface PersonService {
    CompletableFuture<Person> create(Person person);

    CompletableFuture<Optional<Person>> read(Long id);

    CompletableFuture<Person> update(Person person);

    CompletableFuture<Void> delete(Long id);

    /* async + paginated findAll */
    CompletableFuture<Page<Person>> findAll(Pageable pageable);
}
```

### Implementation

```java
// PersonServiceImpl.java
package com.example.jdbccruddemo.service.impl;

import com.example.jdbccruddemo.model.Person;
import com.example.jdbccruddemo.repository.PersonRepository;
import com.example.jdbccruddemo.service.PersonService;
import com.example.jdbccruddemo.util.Pageable;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;

@Service
public class PersonServiceImpl implements PersonService {

    private final PersonRepository repo;

    public PersonServiceImpl(PersonRepository repo) {
        this.repo = repo;
    }

    /* ------------------------------------------------------------------- */
    /* CRUD – async + transactional */
    /* ------------------------------------------------------------------- */

    @Async("asyncExecutor")          // <<< runs in a thread pool
    @Transactional                 // <<< a new TX is created in that thread
    @Override public CompletableFuture<Person> create(Person person) {
        Person created = repo.create(person);
        return CompletableFuture.completedFuture(created);
    }

    @Async("asyncExecutor")
    @Transactional(readOnly = true)
    @Override public CompletableFuture<Optional<Person>> read(Long id) {
        return CompletableFuture.completedFuture(repo.read(id));
    }

    @Async("asyncExecutor")
    @Transactional
    @Override public CompletableFuture<Person> update(Person person) {
        Person updated = repo.update(person);
        return CompletableFuture.completedFuture(updated);
    }

    @Async("asyncExecutor")
    @Transactional
    @Override public CompletableFuture<Void> delete(Long id) {
        repo.delete(id);
        return CompletableFuture.completedFuture(null);
    }

    /* ------------------------------------------------------------------- */
    /* 3️⃣  async + paginated findAll */
    /* ------------------------------------------------------------------- */
    @Async("asyncExecutor")
    @Transactional(readOnly = true)
    @Override public CompletableFuture<Page<Person>> findAll(Pageable pageable) {
        long total = repo.count();                            // total rows
        List<Person> content = repo.findAll(pageable);        // sliced list

        Page<Person> page = new PageImpl<>(content,
                                           PageRequest.of(pageable.getPageNumber(),
                                                          pageable.getPageSize()),
                                           total);
        return CompletableFuture.completedFuture(page);
    }
}
```

### Repository changes for pagination

```java
// PersonRepository.java (add the following methods)

public long count() {
    String sql = "SELECT COUNT(*) FROM person";
    return jdbc.queryForObject(sql, Collections.emptyMap(), Long.class);
}

public List<Person> findAll(Pageable pageable) {
    String sql = """
        SELECT id, name, email
        FROM person
        ORDER BY id
        LIMIT :limit OFFSET :offset
        """;

    Map<String, Object> params = new HashMap<>();
    params.put("limit", pageable.getPageSize());
    params.put("offset", pageable.getOffset());

    return jdbc.query(sql, params, mapper);
}
```

> **Why `Page<Person>`?**  
> Spring Data’s `Page` already contains:
>
> - the list (`content`)
> - pagination metadata (`totalElements`, `totalPages`, `size`, `number`)
> - sorting information (`hasPrevious`, `hasNext`)  
>   It’s just a plain POJO, so no extra dependency is required.

---

## 2. Controller – no change needed

The controller can stay synchronous:

```java
// PersonController.java
@RequestMapping("/api/persons")
@RestController
public class PersonController {

    private final PersonService service;

    public PersonController(PersonService service) {
        this.service = service;
    }

    @GetMapping
    public CompletableFuture<Page<Person>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Pageable pageable = PageRequest.of(page, size);
        return service.findAll(pageable);
    }

    /* other endpoints … */
}
```

> **Client‑side note** – The HTTP response is produced _after_ the async thread completes.  
> With `WebFlux` you could stream the `CompletableFuture` directly, but with the classic servlet stack it just blocks until the async task is finished (which is fine because the work is done in a background thread).

---

## 3. A word about **transactional boundaries** and async

- A method annotated with both `@Async` **and** `@Transactional` is executed inside a **separate transaction** (because the actual method runs in a different thread).
- If you need to **share** the transaction between the async thread and the caller thread (e.g. you want the caller to see uncommitted changes), you’ll need a more sophisticated strategy (e.g. `@TransactionalEventListener`, or using _Open‑Session‑In‑View_ patterns).
- In most use‑cases, the async TX is _independent_ of the caller’s TX – which is what we have here.

---

## 4. Summary checklist

| ✅  | Item                                                             |
| --- | ---------------------------------------------------------------- |
| 1️⃣  | `@Async` + `Executor` bean (thread pool)                         |
| 2️⃣  | `@Transactional` on async methods (new TX in background thread)  |
| 3️⃣  | Repository `count()` + paginated `findAll(Pageable)`             |
| 4️⃣  | Service `findAll(Pageable)` returns `CompletableFuture<Page<…>>` |
| 5️⃣  | Controller passes `Pageable` from request params                 |

---

## 5. Common pitfalls & debugging

| Issue                                                | Fix                                                                                |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **No result** – `EmptyResultDataAccessException`     | Wrap `jdbc.queryForObject` in try/catch and return 0 or throw a custom exception.  |
| **SQL syntax** – `LIMIT` not supported on some RDBMS | Adapt to `FETCH NEXT … ROWS ONLY` (PostgreSQL/SQL Server) or `ROW_NUMBER` + `TOP`. |
| **Thread leakage** – No `Executor` bean              | Declare a `ThreadPoolTaskExecutor` (see `AsyncConfig`).                            |
| **Serialization** – `Page` not serializing           | Add `@JsonIgnore` to getters you don’t want, or add Jackson annotations if needed. |
| **Large offsets** – Poor performance                 | Add an index on the column used in `ORDER BY` (`id` here).                         |

---

## 6. Final Thoughts

- **Async** + **Pagination** → _Better scalability_ for read operations (large data sets).
- **Transactional boundaries** → _Isolation_ of write operations.
- **Page** → _Convenient client‑side metadata_ without pulling in heavy frameworks.

Feel free to tweak the pool sizes, query structure, or even replace the `NamedParameterJdbcTemplate` with `JdbcTemplate` – the core ideas stay the same. Happy coding!

---

### Short answer

**Yes – if you want to show the user “Page 5 of 23” or “Total = 456” you have to know the _total number of rows_.**  
That means executing `SELECT COUNT(*) …` on every request _unless_ you cache the result or switch to a “no‑count” paging strategy (keyset, “infinite scroll”, etc.).

Below is a quick cheat‑sheet of the trade‑offs and alternatives so you can decide what to do in your app.

---

## 1. Why `repo.count()` is normally called every time

| Reason                                                                                       | What happens if you skip it                                                |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| **Page navigation UI** – “Page 5 of 23”                                                      | Users can’t see the total or whether there are more pages.                 |
| **Client‑side logic** – “Show ‘Next’ only if more pages exist”                               | You’ll have to send an extra request or pre‑fetch the next page to decide. |
| **Data‑integrity** – You want to guarantee that the pagination UI matches the data snapshot. | The UI may show stale page numbers if the data changes between requests.   |

If you _don’t_ care about showing the total, you can skip the count. That is especially useful for “infinite scroll” or keyset pagination where you simply fetch the next batch until the dataset is exhausted.

---

## 2. When it _does_ make sense to keep calling `COUNT(*)`

| Scenario                            | Typical cost                                                     | Typical optimization                                                                  |
| ----------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Small tables (≤ 10 k rows)**      | Negligible                                                       | No optimization needed.                                                               |
| **Medium tables (10 k – 1 M rows)** | Fast when there is an index on the ordering column (e.g., `id`). | Use the index; avoid full table scans.                                                |
| **Very large tables (> 1 M rows)**  | Can be a few 100 ms on a busy DB.                                | Cache the count in application memory or in a Redis key; invalidate on insert/delete. |

### Caching example (simple, in‑memory)

```java
@Component
public class PersonServiceImpl implements PersonService {

    private final PersonRepository repo;
    private volatile long cachedTotal = -1;      // -1 = unknown
    private final ReentrantReadWriteLock lock = new ReentrantReadWriteLock();

    @Override
    public CompletableFuture<Page<Person>> findAll(Pageable pageable) {
        long total = getCachedTotal();            // reads the lock
        List<Person> content = repo.findAll(pageable);
        return CompletableFuture.completedFuture(
                new PageImpl<>(content,
                               PageRequest.of(pageable.getPageNumber(),
                                              pageable.getPageSize()),
                               total));
    }

    @Async
    @Transactional
    public void onInsert(Person p) {
        repo.create(p);
        invalidateCache(); // called after successful insert
    }

    @Async
    @Transactional
    public void onDelete(Long id) {
        repo.delete(id);
        invalidateCache();
    }

    /* ----- helpers ----- */
    private long getCachedTotal() {
        lock.readLock().lock();
        try { return cachedTotal; }
        finally { lock.readLock().unlock(); }
    }

    private void invalidateCache() {
        lock.writeLock().lock();
        try { cachedTotal = repo.count(); }   // refreshes the count
        finally { lock.writeLock().unlock(); }
    }
}
```

> **Note** – In a distributed environment you’d normally store the count in a shared cache (Redis, Hazelcast, etc.) and use an optimistic locking strategy.

---

## 3. Alternative pagination strategies that avoid a count

| Strategy                       | How it works                                                                                                      | When to use it                                                                                  |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **Keyset (cursor) pagination** | `SELECT … WHERE id > lastSeenId ORDER BY id LIMIT 50`                                                             | When you need “infinite scroll” or the dataset is _always_ growing/shrinking in the same order. |
| **Infinite scroll**            | Load the next batch via AJAX without a “total” page number.                                                       | Very user‑friendly; great for feeds, timelines, etc.                                            |
| **Hybrid**                     | Show page numbers only for the first few pages; once the user scrolls past the cached range, fall back to keyset. | Mix best of both worlds.                                                                        |

### Quick keyset example

```sql
-- Fetch next 50 rows after id 12345
SELECT id, name, email
FROM person
WHERE id > :lastSeenId
ORDER BY id
LIMIT 50
```

No `COUNT(*)` is ever required, but you lose the “Page X of Y” UI.

---

## 4. Bottom line – what you should do in your code

| Question                                                                      | Recommended answer                                                                            |
| ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| **Do I need the “Page x of y” UI?**                                           | Keep the `COUNT(*)` (or a cached version).                                                    |
| **Is the table < 1 M rows or does the DB have an index on the order column?** | Calling `COUNT(*)` each time is fine.                                                         |
| **Is the table huge and the count query a bottleneck?**                       | Cache it (in‑memory, Redis, etc.) or switch to keyset pagination.                             |
| **Do inserts/deletes happen frequently?**                                     | Invalidate the cache on those events or use a _materialized view_ that updates automatically. |

---

## 4. Quick checklist for implementation

| ✅                                                                 | Checklist item                                       | Why it matters |
| ------------------------------------------------------------------ | ---------------------------------------------------- | -------------- |
| `repo.count()` on each page request                                | Guarantees correct page numbers for the user.        |
| Cache the count when the dataset is large                          | Saves DB resources and speeds up response.           |
| Use an index on the ordering column (`id`)                         | Makes the `COUNT(*)` fast (often a tiny index seek). |
| Invalidate the cache on writes (insert/delete)                     | Keeps the cached total in sync.                      |
| Optionally skip the count if you’re building an infinite‑scroll UI | Avoids the extra round‑trip.                         |

---

### TL;DR

- **If you need total pages / “Page 5 of 23”** – you need a `COUNT(*)`.
- **If that cost becomes noticeable** – cache the count or use keyset pagination.
- **If you’re okay with “no total”** – just return a slice of data (`List<Person>` or a `Page` without the total).

Happy building—pick the pattern that best fits your user‑experience goals and your database size!
