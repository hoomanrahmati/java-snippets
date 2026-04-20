### **Validation**

[back](../annotation-cheat-sheet.md)

| Annotation                                                        | What it does                                                  |
| ----------------------------------------------------------------- | ------------------------------------------------------------- |
| `@Valid`                                                          | Triggers validation on a method argument or bean.             |
| `@Validated`                                                      | Same as `@Valid` but allows group validation on method level. |
| `@NotNull`                                                        | Value must not be `null`.                                     |
| `@NotBlank`                                                       | String must not be `null` and must contain non‑whitespace.    |
| `@NotEmpty`                                                       | Collection/array/CharSequence must not be empty.              |
| `@Size(min=, max=)`                                               | Enforces length bounds.                                       |
| `@Min` / `@Max`                                                   | Numeric range.                                                |
| `@Email`                                                          | Valid email format.                                           |
| `@Pattern(regexp=)`                                               | Regex validation.                                             |
| `@Past` / `@Future`                                               | Date/time constraints.                                        |
| `@AssertTrue` / `@AssertFalse`                                    | Boolean property must be true/false.                          |
| `@Positive` / `@PositiveOrZero` / `@Negative` / `@NegativeOrZero` | Numeric sign constraints.                                     |
| `@DecimalMin` / `@DecimalMax`                                     | Decimal bounds.                                               |

Below are small, self‑contained snippets that show **one real‑world use** of every annotation you listed.  
Feel free to copy‑paste them into your project; just make sure you have the Jakarta Bean Validation (or Hibernate Validator) dependency on the classpath.

> **General notes**
>
> - Put an annotation on a **field**, a **method parameter**, or a **getter**.
> - Use `message = "...`" to override the default error message.
> - For collection/array annotations, the _collection_ itself must not be `null` unless you add `@NotNull` on top of it.
> - When you want **group‑based validation** (e.g. create vs. update), add `@Validated` on the service or controller method and reference the group on the field.

---

## `@Valid`

```java
@RestController
public class BookController {

    @PostMapping("/books")
    public ResponseEntity<Void> create(@RequestBody @Valid BookDto book) {
        bookService.save(book);
        return ResponseEntity.ok().build();
    }
}
```

> Triggers validation on the `BookDto` object when it’s received from the client.

---

## `@Validated`

```java
@Service
@Validated          // activates method‑level validation
public class BookService {

    @Transactional
    public void add(@Validated(OnCreate.class) BookDto book) {
        repository.save(book);   // validated only against OnCreate group
    }
}

interface OnCreate {}
```

> Use when you want **different validation groups** for different operations.

---

## `@NotNull`

```java
public class User {
    @NotNull(message = "Username must not be null")
    private String username;
}
```

> Guarantees the field is present; does **not** check emptiness.

---

## `@NotBlank`

```java
public class LoginForm {
    @NotBlank(message = "Password cannot be blank")
    private String password;
}
```

> Ensures the string is not `null` and contains non‑whitespace characters.

---

## `@NotEmpty`

```java
public class Survey {
    @NotEmpty(message = "Answers cannot be empty")
    private List<String> answers;
}
```

> The collection itself must contain at least one element.

---

## `@Size(min=, max=)`

```java
public class Comment {
    @Size(min = 10, max = 200, message = "Comment must be between 10 and 200 characters")
    private String text;
}
```

> Applies to `String`, `Collection`, `Map`, or `Array`.

---

## `@Min` / `@Max`

```java
public class Product {
    @Min(value = 1, message = "Quantity must be at least 1")
    @Max(value = 999, message = "Quantity cannot exceed 999")
    private int quantity;
}
```

> Validates integer or long values.

---

## `@Email`

```java
public class Subscriber {
    @Email(message = "Must be a valid e‑mail address")
    private String email;
}
```

> Checks the RFC‑5322 email format.

---

## `@Pattern(regexp=)`

```java
public class Customer {
    @Pattern(regexp = "\\d{3}-\\d{2}-\\d{4}",
             message = "SSN must be in the format 123-45-6789")
    private String ssn;
}
```

> Use a regular expression to enforce custom string patterns.

---

## `@Past` / `@Future`

```java
public class Event {
    @Past(message = "Start date must be in the past")
    private LocalDate startDate;

    @Future(message = "End date must be in the future")
    private LocalDate endDate;
}
```

> Works on `java.time` classes or `java.util.Date`.

---

## `@AssertTrue` / `@AssertFalse`

```java
public class TermsAgreement {
    @AssertTrue(message = "You must accept the terms and conditions")
    private boolean acceptedTerms;
}
```

> Useful for checkboxes that must be ticked.

---

## `@Positive` / `@PositiveOrZero` / `@Negative` / `@NegativeOrZero`

```java
public class Investment {
    @Positive(message = "Amount must be positive")
    private BigDecimal amount;

    @NegativeOrZero(message = "Fee cannot be positive")
    private BigDecimal fee;
}
```

> Handles numeric sign constraints for `int`, `long`, `float`, `double`, `BigDecimal`, etc.

---

## `@DecimalMin` / `@DecimalMax`

```java
public class Temperature {
    @DecimalMin(value = "-273.15", inclusive = true,
                message = "Temperature cannot be below absolute zero")
    @DecimalMax(value = "1.4e-45", inclusive = true,
                message = "Temperature cannot exceed the Planck length")
    private BigDecimal value;
}
```

> Use when you need precise decimal bounds rather than integer `@Min/@Max`.

---

### Quick “how‑to” checklist

1. **Declare the bean** (DTO, entity, etc.) and annotate its fields.
2. **Add `@Valid`** on the controller method parameter or on a nested field.
3. **Enable group validation** with `@Validated` if you need distinct constraints for create/update.
4. **Run the application** – any validation violation will automatically trigger a `MethodArgumentNotValidException` (Spring) or similar.
