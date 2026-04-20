### **Web & MVC**

[back](../annotation-cheat-sheet.md)

| Annotation           | What it does                                                    |
| -------------------- | --------------------------------------------------------------- |
| `@RequestMapping`    | Maps HTTP requests to handler methods (class or method level).  |
| `@GetMapping`        | Shortcut for `@RequestMapping(method = GET)`.                   |
| `@PostMapping`       | Shortcut for `@RequestMapping(method = POST)`.                  |
| `@PutMapping`        | Shortcut for `@RequestMapping(method = PUT)`.                   |
| `@DeleteMapping`     | Shortcut for `@RequestMapping(method = DELETE)`.                |
| `@PatchMapping`      | Shortcut for `@RequestMapping(method = PATCH)`.                 |
| `@PathVariable`      | Binds a URI template variable to a method argument.             |
| `@RequestParam`      | Binds a query/form parameter to a method argument.              |
| `@RequestBody`       | Deserializes the HTTP body into a Java object.                  |
| `@ResponseBody`      | Serializes a method return value to the HTTP response.          |
| `@ResponseStatus`    | Sets a custom HTTP status code for a method or exception.       |
| `@CrossOrigin`       | Enables CORS for a controller or method.                        |
| `@ExceptionHandler`  | Handles exceptions thrown from controller methods.              |
| `@ControllerAdvice`  | Global exception handling / response advice across controllers. |
| `@ModelAttribute`    | Adds an attribute to the model (or binds a form object).        |
| `@SessionAttributes` | Persists model attributes in the HTTP session.                  |
| `@InitBinder`        | Configures data binding and validation for web requests.        |
| `@SessionScope`      | Creates a bean that lives in the HTTP session.                  |
| `@RequestScope`      | Creates a bean that lives per HTTP request.                     |

Below are **one‑to‑one explanations** followed by a _complete, copy‑paste‑ready_ Java snippet for every annotation listed under **“Web & MVC.”**  
All code assumes the usual Spring Boot dependencies (`spring-boot-starter-web`) and Java 17+.

---

### `@RequestMapping`

**What it does**  
Maps an HTTP request to a controller method (or an entire controller).  
You can target _path_, _HTTP method_, _consumes_, _produces_, etc.

```java
@RestController
@RequestMapping("/api/books")          // class‑level mapping
public class BookController {

    @RequestMapping(                       // method‑level mapping
        path = "/{id}",
        method = RequestMethod.GET,
        produces = MediaType.APPLICATION_JSON_VALUE)
    public Book getBook(@PathVariable Long id) {
        return bookService.find(id);
    }

    @RequestMapping(                       // another HTTP verb on same path
        path = "/{id}",
        method = RequestMethod.PUT,
        consumes = MediaType.APPLICATION_JSON_VALUE)
    public Book updateBook(@PathVariable Long id,
                           @RequestBody Book book) {
        return bookService.update(id, book);
    }
}
```

---

### `@GetMapping`

**Shortcut for `@RequestMapping(method = GET)`**

```java
@GetMapping("/books")                    // GET /books
public List<Book> list() {
    return bookService.all();
}
```

---

### `@PostMapping`

**Shortcut for `@RequestMapping(method = POST)`**

```java
@PostMapping("/books")                   // POST /books
public ResponseEntity<Book> create(@RequestBody Book book) {
    Book saved = bookService.save(book);
    URI location = uriBuilder.path("/books/{id}")
                            .buildAndExpand(saved.getId())
                            .toUri();
    return ResponseEntity.created(location).body(saved);
}
```

---

### `@PutMapping`

**Shortcut for `@RequestMapping(method = PUT)`**

```java
@PutMapping("/books/{id}")               // PUT /books/42
public Book replace(@PathVariable Long id,
                    @RequestBody Book book) {
    return bookService.replace(id, book);
}
```

---

### `@DeleteMapping`

**Shortcut for `@RequestMapping(method = DELETE)`**

```java
@DeleteMapping("/books/{id}")            // DELETE /books/42
public ResponseEntity<Void> remove(@PathVariable Long id) {
    bookService.delete(id);
    return ResponseEntity.noContent().build();
}
```

---

### `@PatchMapping`

**Shortcut for `@RequestMapping(method = PATCH)`**

```java
@PatchMapping("/books/{id}")             // PATCH /books/42
public Book partialUpdate(@PathVariable Long id,
                          @RequestBody Map<String, Object> updates) {
    return bookService.applyPatch(id, updates);
}
```

---

### `@PathVariable`

**Binds a URI template variable to a method argument**

```java
@GetMapping("/books/{id}")
public Book get(@PathVariable("id") Long bookId) {
    return bookService.find(bookId);
}
```

If the argument name matches the template variable you can omit the explicit name:

```java
@GetMapping("/books/{id}")
public Book get(@PathVariable Long id) {      // id ⇔ {id}
    return bookService.find(id);
}
```

---

### `@RequestParam`

**Binds a query/form parameter to a method argument**

```java
@GetMapping("/books")
public List<Book> search(@RequestParam(required = false) String title,
                        @RequestParam(defaultValue = "10") int limit) {
    return bookService.searchByTitle(title, limit);
}
```

---

### `@RequestBody`

**Deserializes the HTTP body into a Java object**

```java
@PostMapping("/books")
public Book create(@RequestBody @Valid Book newBook) {
    return bookService.save(newBook);
}
```

The `@Valid` triggers bean‑validation on `Book` (requires `@Validated` on the controller or a `Validator` bean).

---

### `@ResponseBody`

**Serializes a method return value to the HTTP response.**  
When used on a controller class (`@RestController`) it’s implicit for every method.

```java
@RestController
public class SimpleRest {

    @GetMapping("/hello")
    public @ResponseBody String sayHello() {   // explicit, but redundant with @RestController
        return "Hello, world!";
    }
}
```

---

### `@ResponseStatus`

**Sets a custom HTTP status code for a method or an exception.**

```java
@GetMapping("/books/{id}")
@ResponseStatus(HttpStatus.OK)          // optional – OK is default
public Book get(@PathVariable Long id) {
    return bookService.find(id);
}

@ResponseStatus(HttpStatus.NOT_FOUND)    // applies to the exception class
public static class BookNotFoundException extends RuntimeException {
    public BookNotFoundException(String msg) { super(msg); }
}
```

---

### `@CrossOrigin`

**Enables CORS for a controller or method**

```java
@RestController
@RequestMapping("/api/public")
@CrossOrigin(origins = "https://frontend.example.com")   // whole controller
public class PublicController {

    @GetMapping("/info")
    public Info getInfo() { return new Info(); }

    @PostMapping("/info")
    @CrossOrigin(origins = "*", maxAge = 3600)   // overrides controller level
    public void postInfo(@RequestBody Info info) { /* … */ }
}
```

---

### `@ExceptionHandler`

**Handles exceptions thrown from controller methods**

```java
@RestController
@RequestMapping("/api/books")
public class BookController {

    @GetMapping("/{id}")
    public Book get(@PathVariable Long id) {
        return bookService.find(id);
    }

    @ExceptionHandler(BookNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleNotFound(BookNotFoundException ex) {
        return new ErrorResponse("Book not found: " + ex.getMessage());
    }
}
```

---

### `@ControllerAdvice`

**Global exception handling / response advice across controllers**

```java
@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    @ResponseBody
    public ErrorResponse handleValidation(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getAllErrors().stream()
                       .map(ObjectError::getDefaultMessage)
                       .collect(Collectors.joining("; "));
        return new ErrorResponse(msg);
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    @ResponseBody
    public ErrorResponse handleAll(Exception ex) {
        return new ErrorResponse("Unexpected error: " + ex.getMessage());
    }
}
```

---

### `@ModelAttribute`

**Adds an attribute to the model (or binds a form object).**

```java
@Controller
@RequestMapping("/contact")
public class ContactController {

    @ModelAttribute("countries")
    public List<String> countries() {
        return Arrays.asList("USA", "Canada", "UK");
    }

    @GetMapping
    public String form(Model model) {
        model.addAttribute("contact", new ContactForm());
        return "contactForm";
    }

    @PostMapping
    public String submit(@ModelAttribute ContactForm form, BindingResult br) {
        if (br.hasErrors()) { return "contactForm"; }
        contactService.save(form);
        return "redirect:/contact/success";
    }
}
```

---

### `@SessionAttributes`

**Persists model attributes in the HTTP session.**

```java
@Controller
@RequestMapping("/cart")
@SessionAttributes("shoppingCart")
public class CartController {

    @ModelAttribute("shoppingCart")
    public ShoppingCart cart() {
        return new ShoppingCart();
    }

    @GetMapping("/add/{productId}")
    public String add(@PathVariable Long productId,
                      @ModelAttribute ShoppingCart cart) {
        cart.add(productId);
        return "redirect:/cart/view";
    }
}
```

The `shoppingCart` attribute is stored in the session until the session ends or you manually remove it.

---

### `@InitBinder`

**Configures data binding and validation for web requests.**

```java
@Controller
@RequestMapping("/orders")
public class OrderController {

    @InitBinder("order")
    public void initOrderBinder(WebDataBinder binder) {
        binder.setValidator(orderValidator);
        binder.registerCustomEditor(Date.class, new CustomDateEditor(
                new SimpleDateFormat("yyyy-MM-dd"), true));
    }

    @PostMapping
    public ResponseEntity<Order> create(@ModelAttribute Order order) {
        orderService.save(order);
        return ResponseEntity.ok(order);
    }
}
```

The binder is invoked before the `@ModelAttribute` method arguments are resolved, so custom editors or validators are applied automatically.

---

### `@SessionScope`

**Creates a bean that lives in the HTTP session.**  
Useful for per‑user state that is _not_ part of the model.

```java
@Component
@SessionScope
public class UserPreferences {

    private Locale locale = Locale.ENGLISH;
    private Theme theme = Theme.LIGHT;

    // getters & setters
}
```

```java
@RestController
public class PreferencesController {

    @GetMapping("/prefs")
    public UserPreferences get(@Autowired UserPreferences prefs) {
        return prefs;      // same instance for the current session
    }
}
```

---

### `@RequestScope`

**Creates a bean that lives per HTTP request.**

```java
@Component
@RequestScope
public class RequestIdProvider {
    private final String id = UUID.randomUUID().toString();

    public String getId() { return id; }
}
```

```java
@RestController
public class TrackingController {

    @GetMapping("/track")
    public String track(@Autowired RequestIdProvider reqId) {
        return "Request ID: " + reqId.getId();
    }
}
```

---

### `@ResponseBody`

**Serializes a method return value to the HTTP response.**  
When a class is annotated with `@RestController`, all its methods already have this behavior.

```java
@RestController
@RequestMapping("/api")
public class SimpleRest {

    @GetMapping("/ping")
    @ResponseBody           // explicit – redundant with @RestController
    public Map<String, String> ping() {
        return Collections.singletonMap("status", "ok");
    }
}
```

---

### `@ResponseStatus`

**Sets a custom HTTP status code for a method or exception.**

```java
@GetMapping("/books/{id}")
@ResponseStatus(HttpStatus.OK)          // explicit – OK is default
public Book get(@PathVariable Long id) { /* … */ }

@ResponseStatus(HttpStatus.BAD_REQUEST)
public static class InvalidBookException extends RuntimeException {
    public InvalidBookException(String msg) { super(msg); }
}
```

---

### `@CrossOrigin`

**Enables CORS for a controller or method.**

```java
@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "https://app.example.com")
public class ApiController {

    @GetMapping("/data")
    public Data get() { /* … */ }

    @PostMapping("/data")
    @CrossOrigin(methods = {RequestMethod.GET, RequestMethod.POST},
                 allowedHeaders = {"Content-Type"},
                 maxAge = 3600)
    public Data post(@RequestBody Data d) { /* … */ }
}
```

---

### `@ControllerAdvice` with `@ModelAttribute`

**Adds global attributes available to all `@ModelAttribute` methods.**

```java
@ControllerAdvice
public class GlobalModelAttributes {

    @ModelAttribute("appName")
    public String appName() { return "MyBookStore"; }
}
```

Now `appName` is automatically available in every controller’s model.

---

### `@ModelAttribute` on a Method (Form Pre‑Populating)

You can also use `@ModelAttribute` on a _method_ to prepare data before any request handling method.

```java
@Controller
@RequestMapping("/login")
public class LoginController {

    @ModelAttribute
    public void addGlobalAttributes(Model model) {
        model.addAttribute("appName", "Book Store");
    }

    @GetMapping
    public String showForm() { return "loginForm"; }
}
```

The method runs before every request mapped to `/login`.

---

These snippets illustrate the primary uses of each annotation.  
Combining them yields expressive, maintainable Spring MVC controllers without boilerplate.
