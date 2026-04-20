### 9️⃣ **Testing**

[back](../annotation-cheat-sheet.md)

| Annotation                      | What it does                                              |
| ------------------------------- | --------------------------------------------------------- |
| `@SpringBootTest`               | Boots the full application context for integration tests. |
| `@WebMvcTest`                   | Loads only the web layer (controllers, MVC config).       |
| `@DataJpaTest`                  | Loads JPA components and an in‑memory DB.                 |
| `@AutoConfigureMockMvc`         | Adds a `MockMvc` bean for MVC tests.                      |
| `@MockBean`                     | Replaces a bean in the context with a Mockito mock.       |
| `@TestConfiguration`            | Adds test‑specific bean configuration.                    |
| `@Transactional`                | Rolls back transactions after each test method.           |
| `@DirtiesContext`               | Marks the context as dirty so it gets recreated.          |
| `@Sql(scripts = "/schema.sql")` | Executes SQL scripts before a test.                       |
| `@SqlGroup`                     | Groups multiple `@Sql` annotations.                       |
| `@ActiveProfiles("test")`       | Activates the `application‑test.yml` profile.             |
| `@MockBean(name="myBean")`      | Creates a named mock.                                     |
| `@WithMockUser`                 | Provides a fake authenticated user (security tests).      |
| `@MockRestServiceServer`        | Mocks a REST client’s HTTP calls.                         |

Below are **self‑contained, copy‑paste‑ready** examples for every annotation that appears in the “Testing” chapter.  
Each snippet is a minimal but complete test class that you can drop into a Spring Boot project (assume Java 17+, `spring-boot-starter-test` and `spring-boot-starter-web` on the classpath).

> **Tip** – Whenever you run a test that touches the database, keep an eye on the `@Transactional` rollback and the `@DataJpaTest`‑provided H2 instance.

---

## `@SpringBootTest`

**What it does** – Boots the _entire_ application context.  
Great for end‑to‑end or integration tests that need all the beans wired together.

```java
@SpringBootTest
class FullApplicationIT {

    @Autowired
    private UserRepository userRepository;          // a real repository bean

    @Test
    void usersArePersisted() {
        User user = new User("alice");
        userRepository.save(user);

        assertNotNull(userRepository.findByUsername("alice"));
    }
}
```

---

## `@WebMvcTest`

**What it does** – Loads **only** the MVC layer: controllers, `@ControllerAdvice`, filters, view resolvers, etc.  
Use this when you want to test _controller_ logic in isolation.

```java
@WebMvcTest(BookController.class)
class BookControllerTest {

    @Autowired
    private MockMvc mockMvc;                       // injected automatically

    @MockBean
    private BookService bookService;                // the service the controller calls

    @Test
    void getBook_returns200() throws Exception {
        Book book = new Book("Spring in Action", "John Doe");
        given(bookService.findById(1L)).willReturn(Optional.of(book));

        mockMvc.perform(get("/books/1"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.title").value("Spring in Action"));
    }
}
```

---

## `@DataJpaTest`

**What it does** – Boots a _minimal_ slice containing only JPA components and configures an **in‑memory** database (H2 by default).  
Use this to unit‑test repositories without pulling the whole stack.

```java
@DataJpaTest
class BookRepositoryTest {

    @Autowired
    private BookRepository bookRepository;

    @Test
    void savesAndFindsBook() {
        Book book = new Book("Testing with Spring");
        bookRepository.save(book);

        Optional<Book> found = bookRepository.findByTitle("Testing with Spring");
        assertTrue(found.isPresent());
    }
}
```

---

## `@AutoConfigureMockMvc`

**What it does** – Adds a fully configured `MockMvc` bean to the test context.  
Can be used together with `@SpringBootTest` (full context) or `@WebMvcTest` (partial context).

```java
@SpringBootTest
@AutoConfigureMockMvc
class MockMvcIntegrationIT {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void getEndpointReturnsExpectedJson() throws Exception {
        mockMvc.perform(get("/api/books"))
               .andExpect(status().isOk())
               .andExpect(content().contentType(MediaType.APPLICATION_JSON));
    }
}
```

---

## `@MockBean`

**What it does** – Replaces an existing bean with a Mockito mock.  
Perfect when you want to stub out a dependency that isn’t the focus of the test.

```java
@WebMvcTest(InventoryController.class)
class InventoryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private InventoryService inventoryService;       // mocked instead of real

    @Test
    void whenItemOutOfStock_thenReturns404() throws Exception {
        given(inventoryService.isInStock("widget")).willReturn(false);

        mockMvc.perform(get("/inventory/widget"))
               .andExpect(status().isNotFound());
    }
}
```

> **Named mocks** (see `@MockBean(name="myBean")`) work the same way but let you pick the exact bean by name.

---

## `@TestConfiguration`

**What it does** – Declares **test‑only** bean definitions that are added to the context.  
Useful when a test needs a special bean implementation (e.g., a stub or a lightweight alternative).

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @TestConfiguration
    static class TestBeans {
        @Bean
        public PasswordEncoder testPasswordEncoder() {
            return NoOpPasswordEncoder.getInstance();   // simple encoder for tests
        }
    }

    @Test
    void canCreateUser() throws Exception {
        mockMvc.perform(post("/users")
                .content("{\"username\":\"bob\"}")
                .contentType(MediaType.APPLICATION_JSON))
               .andExpect(status().isCreated());
    }
}
```

---

## `@Transactional`

**What it does** – Wraps each test method in a transaction that is _rolled back_ after the method completes.  
Keeps the database clean between tests without manual cleanup.

```java
@DataJpaTest
@Transactional
class TransactionalRepositoryTest {

    @Autowired
    private BookRepository bookRepository;

    @Test
    void transactionRollsBack() {
        bookRepository.save(new Book("Transactional Test"));
        // the book disappears automatically after this test method
    }
}
```

---

## `@DirtiesContext`

**What it does** – Marks the _application context_ as dirty so it will be destroyed and recreated for the next test (or test class).  
Use it when a test modifies global state that subsequent tests shouldn’t see.

```java
@SpringBootTest
class DirtyContextIT {

    @Autowired
    private CacheManager cacheManager;

    @Test
    @DirtiesContext
    void clearCache() {
        cacheManager.getCache("users").clear();
        // After this test, the whole context will be rebuilt
    }

    @Test
    void cacheStartsEmpty() {
        assertNull(cacheManager.getCache("users").get("alice"));
    }
}
```

---

## `@Sql(scripts = "/schema.sql")`

**What it does** – Executes one or more SQL scripts _before_ the test method runs.  
Great for pre‑populating a real database or running DDL.

```java
@SpringBootTest
@Sql(scripts = "/setup-users.sql")
class SqlScriptIT {

    @Autowired
    private UserRepository userRepository;

    @Test
    void usersLoadedFromScript() {
        assertTrue(userRepository.findAll().size() > 0);
    }
}
```

> The file `setup‑users.sql` should be in `src/test/resources`.

---

## `@SqlGroup`

**What it does** – Allows grouping multiple `@Sql` annotations into a single container.

```java
@SpringBootTest
@SqlGroup({
        @Sql(scripts = "/create-table.sql", executionPhase = Sql.ExecutionPhase.BEFORE_TEST_METHOD),
        @Sql(scripts = "/insert-data.sql",  executionPhase = Sql.ExecutionPhase.BEFORE_TEST_METHOD)
})
class SqlGroupIT {

    @Autowired
    private UserRepository userRepository;

    @Test
    void dataFromTwoScriptsIsAvailable() {
        assertNotNull(userRepository.findByUsername("bob"));
    }
}
```

---

## `@ActiveProfiles("test")`

**What it does** – Activates the `application‑test.yml` (or `application‑test.properties`) profile so that beans marked with `@Profile("test")` are loaded.

```java
@SpringBootTest
@ActiveProfiles("test")
class ProfileSpecificIT {

    @Autowired
    private FeatureToggle featureToggle;   // bean defined only in test profile

    @Test
    void testFeatureFlagIsEnabled() {
        assertTrue(featureToggle.isEnabled());
    }
}
```

---

## `@MockBean(name="myBean")`

**What it does** – Creates a _named_ Mockito mock and injects it into the application context, replacing the real bean with that name.

```java
@WebMvcTest(NotificationController.class)
class MockNamedBeanTest {

    @MockBean(name = "emailService")
    private EmailService emailServiceMock;   // the bean name must match

    @Autowired
    private MockMvc mockMvc;

    @Test
    void notificationSendsEmail() throws Exception {
        doNothing().when(emailServiceMock).send(any());

        mockMvc.perform(post("/notify")
                .content("{\"message\":\"Hello\"}")
                .contentType(MediaType.APPLICATION_JSON))
               .andExpect(status().isOk());

        verify(emailServiceMock).send(any());
    }
}
```

---

## `@WithMockUser`

**What it does** – Supplies a fake authenticated user for Spring Security tests.  
You can specify username, roles, and authorities.

```java
@WebMvcTest(SecureController.class)
class SecurityIT {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void adminCanAccessProtectedEndpoint() throws Exception {
        mockMvc.perform(get("/admin/dashboard"))
               .andExpect(status().isOk());
    }

    @Test
    void unauthenticatedUserGets401() throws Exception {
        mockMvc.perform(get("/admin/dashboard"))
               .andExpect(status().isUnauthorized());
    }
}
```

---

## `@MockRestServiceServer`

**What it does** – Mocks HTTP interactions performed by a `RestTemplate` (or `WebClient`) so that external services can be simulated during tests.

```java
@SpringBootTest
@AutoConfigureMockRestServiceServer
class RestClientIT {

    @Autowired
    private RestTemplate restTemplate;

    @Test
    void externalApiIsMocked() {
        MockRestServiceServer server = MockRestServiceServer.createServer(restTemplate);

        server.expect(requestTo("http://external/api/hello"))
              .andRespond(withSuccess("{\"greeting\":\"Hi\"}", MediaType.APPLICATION_JSON));

        String response = restTemplate.getForObject("http://external/api/hello", String.class);
        assertTrue(response.contains("\"greeting\":\"Hi\""));

        server.verify();            // ensures all expectations were met
    }
}
```

> The `@AutoConfigureMockRestServiceServer` annotation automatically registers the mock server for the `RestTemplate` bean in the context.

---

## `@AutoConfigureMockRestServiceServer` (optional helper)

**What it does** – Similar to `@MockRestServiceServer` but auto‑configures the mock server for you, so you don’t have to call `createServer` manually.

```java
@SpringBootTest
@AutoConfigureMockRestServiceServer
class AutoMockRestIT {

    @Autowired
    private RestTemplate restTemplate;

    @Autowired
    private MockRestServiceServer server;   // injected automatically

    @Test
    void testAutoConfiguredServer() {
        server.expect(requestTo("http://api.example.com/data"))
              .andRespond(withJsonResponse("{\"id\":42}", MediaType.APPLICATION_JSON));

        Book book = restTemplate.getForObject("http://api.example.com/data", Book.class);
        assertEquals(42, book.getId());

        server.verify();
    }
}
```

---

### Quick Summary of Slices

| Slice                                                                            | Use‑Case                    | What You Get                           |
| -------------------------------------------------------------------------------- | --------------------------- | -------------------------------------- |
| **Full** (`@SpringBootTest`)                                                     | Test entire application     | Full context, all beans                |
| **MVC** (`@WebMvcTest`)                                                          | Test controllers only       | Controllers + filters                  |
| **Repository** (`@DataJpaTest`)                                                  | Test JPA repos              | Repositories + in‑memory DB            |
| **Full + MockMvc** (`@SpringBootTest + @AutoConfigureMockMvc`)                   | End‑to‑end controller tests | Full context + `MockMvc`               |
| **Full + Rest Client** (`@SpringBootTest + @AutoConfigureMockRestServiceServer`) | Mock external APIs          | Full context + `MockRestServiceServer` |

Pick the slice that matches what you’re testing, and the rest of the dependencies can be stubbed with `@MockBean` or provided via `@TestConfiguration`. This keeps your tests fast, focused, and deterministic.

Below is a **drop‑in, copy‑paste** showcase that focuses **only on testing a REST client** (no MVC layer).  
I’ll walk you through two common ways to call external services in Spring:

1.  `RestTemplate` + `MockRestServiceServer`
2.  `WebClient` + OkHttp’s `MockWebServer`

Both examples use `@SpringBootTest` (full context) so you can see the client in its real wiring, but the remote HTTP calls are completely mocked.

> **Prerequisites** – Add the following to your **`build.gradle.kts`** (or Maven pom.xml) just for the tests:

```kotlin
testImplementation("org.springframework.boot:spring-boot-starter-test")   // includes JUnit, Mockito, etc.
testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")           // for WebClient demo
```

---

## 1️⃣ RestTemplate + MockRestServiceServer

### Production code – a thin service that talks to an external book API

```java
package com.example.client;

import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class BookClient {

    private final RestTemplate restTemplate;

    // Injected by Spring (auto‑configured in the test)
    public BookClient(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    public Book getBookById(Long id) {
        String url = "https://api.example.com/books/" + id;
        ResponseEntity<Book> resp = restTemplate.getForEntity(url, Book.class);
        return resp.getBody();
    }

    public Book createBook(Book book) {
        String url = "https://api.example.com/books";
        return restTemplate.postForObject(url, book, Book.class);
    }
}
```

> **Book POJO**

```java
package com.example.client;

public record Book(Long id, String title, String author) {}
```

### Test – mocking the external call

```java
package com.example.client;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.MockRestServiceServer;
import org.springframework.boot.test.autoconfigure.web.client.AutoConfigureMockRestServiceServer;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;

@SpringBootTest          // full context – RestTemplate bean comes from @Bean below
@AutoConfigureMockRestServiceServer   // injects a MockRestServiceServer into the context
class BookClientRestTemplateIT {

    @Autowired
    private BookClient bookClient;                     // the bean under test

    @Autowired
    private MockRestServiceServer mockServer;           // injected by the auto‑config

    /** RestTemplate bean used only for the test – points to the mock server */
    @SpringBootTest.WebConfiguration
    static class TestConfig {
        @Bean
        RestTemplate restTemplate() {
            return new RestTemplate();   // Spring will wire this into BookClient
        }
    }

    @Test
    void getBookById_returnsBook() {
        // Arrange – what the mock server should reply with
        mockServer.expect(requestTo("https://api.example.com/books/42"))
                  .andExpect(method(HttpMethod.GET))
                  .andRespond(withSuccess(
                          "{\"id\":42,\"title\":\"Clean Code\",\"author\":\"Robert C. Martin\"}",
                          MediaType.APPLICATION_JSON));

        // Act
        Book book = bookClient.getBookById(42L);

        // Assert
        assertNotNull(book);
        assertEquals(42L, book.id());
        assertEquals("Clean Code", book.title());
        assertEquals("Robert C. Martin", book.author());

        mockServer.verify();   // make sure all expectations were met
    }

    @Test
    void createBook_postsBookAndReturnsCreated() {
        // Arrange – mock POST
        mockServer.expect(requestTo("https://api.example.com/books"))
                  .andExpect(method(HttpMethod.POST))
                  .andExpect(content()
                           .json("{\"title\":\"Domain-Driven Design\",\"author\":\"Eric Evans\"}"))
                  .andRespond(withSuccess(
                          "{\"id\":99,\"title\":\"Domain-Driven Design\",\"author\":\"Eric Evans\"}",
                          MediaType.APPLICATION_JSON));

        // Act
        Book created = bookClient.createBook(new Book(null, "Domain-Driven Design", "Eric Evans"));

        // Assert
        assertNotNull(created);
        assertEquals(99L, created.id());
        assertEquals("Domain-Driven Design", created.title());
        assertEquals("Eric Evans", created.author());

        mockServer.verify();
    }
}
```

**What the test does**

| Step                                     | What happens                                                                         | Why it matters                               |
| ---------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------- |
| `@AutoConfigureMockRestServiceServer`    | Registers a **single** `MockRestServiceServer` for the `RestTemplate` bean           | You never hit the real network               |
| `mockServer.expect(...).andRespond(...)` | Declares an expected request and a canned response                                   | Precise control over the HTTP dialogue       |
| `bookClient.getBookById(42L)`            | Executes the real method – the `RestTemplate` automatically hits the **mock** server | No external dependency, deterministic output |

---

## 2️⃣ WebClient + MockWebServer

The same idea works with the reactive `WebClient`.  
OkHttp’s `MockWebServer` is a tiny HTTP server that lets you push any HTTP response into the client.

### Production code – a reactive client

```java
package com.example.client;

import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Service
public class ReactiveBookClient {

    private final WebClient webClient;

    public ReactiveBookClient(WebClient webClient) {
        this.webClient = webClient;
    }

    public Mono<Book> getBookById(Long id) {
        String url = "https://api.example.com/books/" + id;
        return webClient.get()
                        .uri(url)
                        .retrieve()
                        .bodyToMono(Book.class);
    }

    public Mono<Book> createBook(Book book) {
        String url = "https://api.example.com/books";
        return webClient.post()
                        .uri(url)
                        .bodyValue(book)
                        .retrieve()
                        .bodyToMono(Book.class);
    }
}
```

### Test – spin‑up a MockWebServer, point `WebClient` at it

```java
package com.example.client;

import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Bean;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;
import reactor.test.StepVerifier;

import java.io.IOException;
import java.net.URI;

@SpringBootTest
class ReactiveBookClientIT {

    private static MockWebServer mockWebServer;

    @BeforeAll
    static void startServer() throws IOException {
        mockWebServer = new MockWebServer();
        mockWebServer.start();          // starts on a random free port
    }

    @AfterAll
    static void stopServer() throws IOException {
        mockWebServer.shutdown();
    }

    /** Production WebClient bean – will hit the MockWebServer */
    @SpringBootTest.WebConfiguration
    static class TestConfig {
        @Bean
        WebClient webClient() {
            // Note: we build it manually so we can set a baseUrl
            return WebClient.builder()
                    .baseUrl(mockWebServer.url("/").toString())   // <-- points to MockWebServer
                    .build();
        }
    }

    @Autowired
    private ReactiveBookClient client;          // bean under test

    @Test
    void getBookById_shouldReturnBook() {
        // 1️⃣ Queue the canned response
        mockWebServer.enqueue(new MockResponse()
                .setBody("{\"id\":55,\"title\":\"Reactive Systems\",\"author\":\"John Doe\"}")
                .addHeader("Content-Type", "application/json")
                .setResponseCode(200));

        // 2️⃣ Call the client
        Mono<Book> result = client.getBookById(55L);

        // 3️⃣ Verify the reactive stream
        StepVerifier.create(result)
                .expectNextMatches(book ->
                        book.id() == 55L &&
                        "Reactive Systems".equals(book.title()) &&
                        "John Doe".equals(book.author()))
                .verifyComplete();

        // 4️⃣ Optional: ensure the server received the expected request
        var recorded = mockWebServer.takeRequest();   // blocks until a request arrives
        assertEquals("/books/55", recorded.getPath());
        assertEquals("GET", recorded.getMethod());
    }

    @Test
    void createBook_shouldReturnCreatedBook() {
        mockWebServer.enqueue(new MockResponse()
                .setBody("{\"id\":77,\"title\":\"Microservices in Action\",\"author\":\"Jane Smith\"}")
                .addHeader("Content-Type", "application/json")
                .setResponseCode(201));

        Book toCreate = new Book(null, "Microservices in Action", "Jane Smith");

        StepVerifier.create(client.createBook(toCreate))
                .expectNextMatches(book ->
                        book.id() == 77L &&
                        "Microservices in Action".equals(book.title()) &&
                        "Jane Smith".equals(book.author()))
                .verifyComplete();
    }
}
```

### Why this test is so clean

| What you control    | How you control it                                                                                       |
| ------------------- | -------------------------------------------------------------------------------------------------------- |
| **Remote response** | `mockWebServer.enqueue(...)` – you can return any JSON, error code, delay, etc.                          |
| **Request shape**   | `StepVerifier` + assertions on `recorded.getPath()` or `recorded.getMethod()`                            |
| **Non‑blocking**    | The test runs on the **reactive** `WebClient` stream, so you get backpressure guarantees, timeouts, etc. |
