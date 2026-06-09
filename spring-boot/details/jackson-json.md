## Jackson Annotaion

[back](../README.md)

Great! Let's dive into the **most useful Jackson annotations and customizations** you'll use in real Spring Boot projects.

## 🎯 1. Renaming Fields with `@JsonProperty`

When your Java field name doesn't match the JSON property name:

```java
public class Product {
    @JsonProperty("product_name")  // JSON will use "product_name" instead of "name"
    private String name;

    @JsonProperty("price_usd")      // JSON uses "price_usd" but Java uses "priceInUsd"
    private BigDecimal priceInUsd;

    // getters/setters required...
}
```

**Result:**

- **JSON input/output**: `{"product_name":"Laptop", "price_usd":999.99}`
- **Java field names remain**: `name`, `priceInUsd`

## 🚫 2. Ignoring Fields with `@JsonIgnore`

Prevent sensitive or computed fields from being serialized/deserialized:

```java
public class User {
    private String username;

    @JsonIgnore  // Password will NEVER appear in JSON response
    private String password;

    @JsonIgnore  // Don't expose internal database ID to clients
    private Long dbId;

    // getters/setters...
}
```

**Result:** JSON will only contain `{"username":"john"}` - password and dbId are excluded.

## 📅 3. Customizing Date Format

Dates are a common pain point. Here's how to control them:

### Option A: Global Format (application.properties)

```properties
spring.jackson.date-format=yyyy-MM-dd'T'HH:mm:ss.SSSZ
spring.jackson.time-zone=America/New_York
```

### Option B: Field-Specific Format with `@JsonFormat`

```java
public class Event {
    private String name;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss", timezone = "Asia/Tokyo")
    private LocalDateTime startTime;

    @JsonFormat(pattern = "MM/dd/yyyy")
    private LocalDate eventDate;

    // getters/setters...
}
```

**Input JSON:** `{"startTime":"2024-12-25 14:30:00"}` → Java `LocalDateTime` object  
**Output JSON:** same formatted string

## 🔧 4. Custom Serializer & Deserializer

For complex logic that annotations can't handle:

### Create a Custom Serializer

```java
public class SensitiveDataSerializer extends JsonSerializer<String> {
    @Override
    public void serialize(String value, JsonGenerator gen, SerializerProvider serializers)
            throws IOException {
        // Mask sensitive data except last 4 characters
        if (value != null && value.length() > 4) {
            String masked = "****" + value.substring(value.length() - 4);
            gen.writeString(masked);
        } else {
            gen.writeString("****");
        }
    }
}
```

### Create a Custom Deserializer

```java
public class TrimStringDeserializer extends JsonDeserializer<String> {
    @Override
    public String deserialize(JsonParser p, DeserializationContext ctxt)
            throws IOException {
        String value = p.getValueAsString();
        return value != null ? value.trim() : null;
    }
}
```

### Apply Them to Your Model

```java
public class CreditCard {
    @JsonSerialize(using = SensitiveDataSerializer.class)
    @JsonDeserialize(using = TrimStringDeserializer.class)
    private String cardNumber;

    // getters/setters...
}
```

**Result:**

- **JSON input**: `{"cardNumber":"  4111-1111-1111-1111  "}` → stored as `"4111-1111-1111-1111"` (trimmed)
- **JSON output**: `{"cardNumber":"****1111"}` (masked)

## 🎨 5. Controlling Null Values

### Option A: Global (application.properties)

```properties
spring.jackson.default-property-inclusion=non_null
```

### Option B: Class-Level

```java
@JsonInclude(JsonInclude.Include.NON_NULL)
public class Product {
    private String name;
    private String description;  // if null, omitted from JSON
    private BigDecimal price;     // if null, omitted
}
```

### Option C: Field-Level (more specific)

```java
public class SearchResult {
    private String query;

    @JsonInclude(JsonInclude.Include.NON_EMPTY)
    private List<String> suggestions;  // omit if null or empty list

    @JsonInclude(JsonInclude.Include.NON_DEFAULT)
    private int pageNumber;  // omit if 0 (int default)
}
```

## 🔄 6. Handling Extra Unknown Fields

By default, Jackson fails if JSON has fields your Java class doesn't. Fix it:

### Option A: Global (application.properties)

```properties
spring.jackson.deserialization.fail-on-unknown-properties=false
```

### Option B: Class-Level

```java
@JsonIgnoreProperties(ignoreUnknown = true)
public class User {
    private String name;
    // JSON with "age" field will just ignore it
}
```

## 📋 7. Complete Real-World Example

Here's a typical DTO you might see in a Spring Boot project:

```java
import com.fasterxml.jackson.annotation.*;
import java.time.LocalDateTime;

@JsonIgnoreProperties(ignoreUnknown = true)  // Ignore extra JSON fields
@JsonInclude(JsonInclude.Include.NON_NULL)   // Don't include nulls in response
public class OrderDTO {

    @JsonProperty("order_id")  // JSON uses snake_case, Java uses camelCase
    private Long orderId;

    @JsonProperty("customer_email")
    private String customerEmail;

    @JsonIgnore  // Don't expose internal status codes to API clients
    private String internalStatusCode;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private LocalDateTime createdAt;

    @JsonSerialize(using = MoneySerializer.class)  // Custom: add "$" symbol
    private BigDecimal totalAmount;

    // getters and setters...
}
```

## 🧪 Testing Your Configuration

Here's a quick test to verify your JSON serialization:

```java
@SpringBootTest
class JsonTest {

    @Autowired
    private ObjectMapper objectMapper;  // Jackson's main class

    @Test
    void testSerialization() throws Exception {
        User user = new User("John", "secret123");
        String json = objectMapper.writeValueAsString(user);

        assertThat(json).doesNotContain("secret123");  // Password should be ignored
        assertThat(json).contains("John");
    }
}
```

## 💡 Pro Tips

1. **Use DTOs for APIs** - Don't expose your entity classes directly. Create separate DTO classes with Jackson annotations.
2. **Lombok users**: If using `@Data` or `@Getter/@Setter`, Jackson works fine. Just add `@NoArgsConstructor`.
3. **Record classes (Java 14+)**: Jackson 2.12+ supports records:
   ```java
   public record UserDto(@JsonProperty("user_name") String userName, int age) {}
   ```

## ObjectMapper

```java

    ObjectMapper mapper = new ObjectMapper();

    // Java → JSON
    String json = mapper.writeValueAsString(myUser);

    // JSON → Java
    User user = mapper.readValue(json, User.class);

    // JSON → Map<String, Object>
    Map<String, Object> map = objectMapper.readValue(jsonFromDb, new TypeReference<>() {});

```

---

## TypeRefrence

`TypeReference` is a Jackson utility that solves a **specific problem** with Java's **type erasure**. Let me explain why it exists and when you need it.

## 🎯 The Problem: Type Erasure

Java removes generic type information at runtime. This causes problems for Jackson:

```java
// This WON'T work - Jackson can't know it's a List<User>
List<User> users = objectMapper.readValue(json, List<User>.class);  // Compiler error!

// This makes Jackson think it's just a List (no type info)
List<User> users = objectMapper.readValue(json, List.class);  // Compiles but UNSAFE!
// Jackson returns List<LinkedHashMap> instead of List<User>
```

## ✅ The Solution: TypeReference

`TypeReference` preserves generic type information for Jackson:

```java
// This works perfectly!
List<User> users = objectMapper.readValue(
    json,
    new TypeReference<List<User>>() {}  // Notice the empty braces - anonymous class
);
```

## 📝 Common Use Cases

### 1. Lists and Collections

```java
@Service
public class UserService {
    private final ObjectMapper objectMapper;

    public List<User> parseUserList(String json) throws JsonProcessingException {
        // Without TypeReference - BAD PRACTICE
        List<User> bad = objectMapper.readValue(json, List.class);
        // This gives List<LinkedHashMap>, NOT List<User> - ClassCastException risk!

        // With TypeReference - GOOD
        return objectMapper.readValue(json, new TypeReference<List<User>>() {});
    }

    public Set<Long> parseIdSet(String json) throws JsonProcessingException {
        return objectMapper.readValue(json, new TypeReference<Set<Long>>() {});
    }

    public Queue<Product> parseProductQueue(String json) throws JsonProcessingException {
        return objectMapper.readValue(json, new TypeReference<Queue<Product>>() {});
    }
}
```

### 2. Maps with Complex Values

```java
@Service
public class ConfigService {

    // Map<String, User> - tricky without TypeReference
    public Map<String, User> parseUserMap(String json) throws JsonProcessingException {
        return objectMapper.readValue(json, new TypeReference<Map<String, User>>() {});
    }

    // Map<String, List<Order>> - nested generics
    public Map<String, List<Order>> parseOrdersByCustomer(String json) throws JsonProcessingException {
        return objectMapper.readValue(json, new TypeReference<Map<String, List<Order>>>() {});
    }

    // Map<Long, Map<String, Product>> - very complex
    public Map<Long, Map<String, Product>> parseComplexMap(String json) throws JsonProcessingException {
        return objectMapper.readValue(json, new TypeReference<Map<Long, Map<String, Product>>>() {});
    }
}
```

### 3. Nested Generic Structures

```java
public class ApiResponse<T> {
    private String status;
    private T data;
    private String message;
    // getters/setters...
}

// Parsing generic wrapper classes
@Service
public class ApiClient {

    public ApiResponse<List<User>> parseUserResponse(String json) throws JsonProcessingException {
        // TypeReference preserves both outer AND inner generic types
        return objectMapper.readValue(
            json,
            new TypeReference<ApiResponse<List<User>>>() {}
        );
    }

    public ApiResponse<Map<String, Product>> parseProductResponse(String json) throws JsonProcessingException {
        return objectMapper.readValue(
            json,
            new TypeReference<ApiResponse<Map<String, Product>>>() {}
        );
    }
}
```

### 4. Real-World REST Client Example

```java
@Service
public class GitHubClient {
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    public List<Repository> getUserRepos(String username) throws JsonProcessingException {
        String jsonResponse = restTemplate.getForObject(
            "https://api.github.com/users/" + username + "/repos",
            String.class
        );

        // TypeReference is essential here
        return objectMapper.readValue(
            jsonResponse,
            new TypeReference<List<Repository>>() {}
        );
    }

    public Map<String, Integer> getLanguageStats(String username) throws JsonProcessingException {
        String json = restTemplate.getForObject(
            "https://api.github.com/users/" + username + "/repos",
            String.class
        );

        // Complex parsing: count languages across all repos
        List<Repository> repos = objectMapper.readValue(json, new TypeReference<List<Repository>>() {});
        Map<String, Integer> stats = new HashMap<>();
        for (Repository repo : repos) {
            stats.merge(repo.getLanguage(), 1, Integer::sum);
        }
        return stats;
    }
}

class Repository {
    private String name;
    private String language;
    // getters/setters...
}
```

## 🆚 Alternatives to TypeReference

### Option 1: Use Arrays (if applicable)

```java
// Instead of List<User>
User[] userArray = objectMapper.readValue(json, User[].class);
List<User> users = Arrays.asList(userArray);
```

### Option 2: Use JsonNode for dynamic parsing

```java
JsonNode root = objectMapper.readTree(json);
List<User> users = new ArrayList<>();
for (JsonNode node : root) {
    User user = objectMapper.treeToValue(node, User.class);
    users.add(user);
}
```

### Option 3: Create a wrapper class

```java
// Instead of TypeReference<List<User>>
public class UserList {
    private List<User> users;
    // getter/setter
}

UserList wrapper = objectMapper.readValue(json, UserList.class);
List<User> users = wrapper.getUsers();
```

### Option 4: Java 16+ Records (still needs TypeReference for lists)

```java
record UserWrapper(List<User> users) {}

UserWrapper wrapper = objectMapper.readValue(json, UserWrapper.class);
// Still need TypeReference for standalone List<User>
List<User> users = objectMapper.readValue(json, new TypeReference<List<User>>() {});
```

## 📊 Comparison Table

| Approach                          | Type Safety | Complexity | Use Case                    |
| --------------------------------- | ----------- | ---------- | --------------------------- |
| `List.class`                      | ❌ Unsafe   | Simple     | NEVER use                   |
| `User[].class`                    | ✅ Safe     | Simple     | Arrays only                 |
| **`TypeReference<List<User>>()`** | ✅ Safe     | Medium     | **Go-to for collections**   |
| Wrapper class                     | ✅ Safe     | High       | When you control the schema |
| `JsonNode`                        | ⚠️ Manual   | Complex    | Dynamic/unknown structure   |

## 🎯 Best Practices

### ✅ DO use TypeReference when:

```java
// 1. Parsing JSON arrays from external APIs
List<Order> orders = mapper.readValue(json, new TypeReference<List<Order>>() {});

// 2. Working with complex Maps
Map<String, List<Product>> catalog = mapper.readValue(json, new TypeReference<>() {});

// 3. Parsing generic wrapper classes
ApiResponse<PaymentResult> response = mapper.readValue(json, new TypeReference<>() {});

// 4. In utility methods that return generic types
public <T> T parseJson(String json, TypeReference<T> typeRef) throws Exception {
    return objectMapper.readValue(json, typeRef);
}
```

### ❌ DON'T use TypeReference when:

```java
// 1. Simple non-generic types (just use Class)
User user = mapper.readValue(json, User.class);  // ✓ Good
// User user = mapper.readValue(json, new TypeReference<User>() {});  // ✗ Overkill

// 2. You have the actual class (arrays)
User[] users = mapper.readValue(json, User[].class);  // ✓ Good

// 3. Spring already handles it in @RequestBody
@PostMapping("/users")
public void createUsers(@RequestBody List<User> users) {  // ✓ Spring handles generics
    // No TypeReference needed here!
}
```

## 💡 Pro Tips

1. **Static import for cleaner code:**

```java
import com.fasterxml.jackson.core.type.TypeReference;

// Instead of:
List<User> users = mapper.readValue(json, new TypeReference<List<User>>() {});

// You can create a utility method:
public class JsonUtils {
    public static <T> T parse(String json, TypeReference<T> typeRef) {
        return objectMapper.readValue(json, typeRef);
    }
}
```

2. **Reuse TypeReference instances** for performance (though creating them is cheap):

```java
private static final TypeReference<List<User>> USER_LIST_TYPE = new TypeReference<>() {};

public List<User> getUsers(String json) {
    return objectMapper.readValue(json, USER_LIST_TYPE);
}
```

3. **Spring's ParameterizedTypeReference** (for RestTemplate):

```java
// RestTemplate has its own version for generics
ParameterizedTypeReference<List<User>> typeRef = new ParameterizedTypeReference<>() {};
ResponseEntity<List<User>> response = restTemplate.exchange(url, HttpMethod.GET, null, typeRef);
```

## 🧪 Quick Test to See the Difference

```java
@Test
void typeReferenceExample() throws Exception {
    String json = "[{\"name\":\"Alice\",\"age\":30},{\"name\":\"Bob\",\"age\":25}]";

    // WRONG: This returns List<LinkedHashMap>
    List wrong = objectMapper.readValue(json, List.class);
    Object first = wrong.get(0);
    System.out.println(first.getClass());  // class LinkedHashMap - NOT User!

    // RIGHT: This returns List<User>
    List<User> correct = objectMapper.readValue(json, new TypeReference<List<User>>() {});
    User user = correct.get(0);
    System.out.println(user.getClass());  // class User ✓
}
```

**Bottom line:** Use `TypeReference` whenever you need to tell Jackson about **generic types** (`List<T>`, `Map<K,V>`, `ApiResponse<T>`) at runtime. It's essential for type safety when working with collections of your custom objects.

Would you like to see how this works with Spring's `RestTemplate` or how to handle JSON with polymorphic types?
