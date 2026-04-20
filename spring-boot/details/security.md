### **Security**

[back](../annotation-cheat-sheet.md)

| Annotation                                             | What it does                                                                   |
| ------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `@EnableWebSecurity`                                   | Activates Spring Security’s web security support.                              |
| `@Configuration` + `@EnableWebSecurity`                | Customizes security configuration via `WebSecurityConfigurerAdapter`.          |
| `@EnableGlobalMethodSecurity`                          | Enables method‑level security (`@PreAuthorize`, `@PostAuthorize`, `@Secured`). |
| `@PreAuthorize("hasRole('ADMIN')")`                    | Authorizes based on SpEL expressions.                                          |
| `@Secured("ROLE_ADMIN")`                               | Authorizes based on roles.                                                     |
| `@RolesAllowed("ADMIN")`                               | JSR‑250 role‑based authorization.                                              |
| `@AuthenticationPrincipal`                             | Injects the current `UserDetails` into a controller method.                    |
| `@WithMockUser`                                        | Mocks an authenticated user in tests.                                          |
| `@SecurityConfigurerAdapter`                           | Custom security filter configuration.                                          |
| `@EnableOAuth2Client`                                  | Enables OAuth2 client support (deprecated in Spring 6).                        |
| `@EnableAuthorizationServer` / `@EnableResourceServer` | Deprecated; use Spring Authorization Server & Resource Server.                 |

---

### `@EnableWebSecurity`

**What it does**  
Turns on Spring Security’s web‑security support.

**Typical usage**

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    // In Boot this is often enough – the default filter chain is added automatically.
}
```

**Where it lives**  
A configuration class (usually `@SpringBootApplication` or a dedicated `@Configuration`).

---

### `@Configuration` + `@EnableWebSecurity`

**What it does**  
Lets you customize the default security filter chain (e.g., which URLs are public, what login form to use, etc.).

**Typical usage** (Spring 6+ – no `WebSecurityConfigurerAdapter`)

```java
@Configuration
public class SecurityFilterChainConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/public/**").permitAll()
                .anyRequest().authenticated())
            .formLogin(Customizer.withDefaults());   // default form‑login
        return http.build();
    }
}
```

**Where it lives**  
A configuration class that declares a `SecurityFilterChain` bean (or extends `WebSecurityConfigurerAdapter` in Spring 5).

---

### `@EnableGlobalMethodSecurity`

**What it does**  
Enables method‑level security annotations such as `@PreAuthorize`, `@Secured`, and JSR‑250 `@RolesAllowed`.

**Typical usage**

```java
@Configuration
@EnableGlobalMethodSecurity(
        prePostEnabled = true,   // @PreAuthorize / @PostAuthorize
        securedEnabled = true,   // @Secured
        jsr250Enabled = true)    // @RolesAllowed
public class MethodSecurityConfig {
    // nothing else needed – Spring automatically registers MethodSecurityMetadataSource
}
```

**Where it lives**  
A configuration class (usually alongside your main `@SpringBootApplication`).

---

### `@PreAuthorize`

**What it does**  
Authorizes a method call based on a SpEL expression evaluated against the current security context.

**Typical usage**

```java
@RestController
@RequestMapping("/admin")
public class AdminController {

    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping("/dashboard")
    public String dashboard() {
        return "Admin dashboard";
    }
}
```

**Where it lives**  
Any Spring bean – controller, service, repository, etc.

---

### `@Secured`

**What it does**  
Authorizes a method based on a static list of roles. Requires `securedEnabled=true`.

**Typical usage**

```java
@RestController
@RequestMapping("/users")
public class UserController {

    @Secured("ROLE_USER")
    @GetMapping("/profile")
    public UserProfile profile() {
        // only users with ROLE_USER can hit this method
        return userService.getCurrentUser();
    }
}
```

**Where it lives**  
Any Spring bean.

---

### `@RolesAllowed`

**What it does**  
Standard JSR‑250 role‑based annotation. Requires `jsr250Enabled=true`.

**Typical usage**

```java
@RestController
@RequestMapping("/reports")
public class ReportsController {

    @RolesAllowed("ADMIN")
    @GetMapping("/sales")
    public List<SalesReport> salesReports() {
        return reportService.getSalesReports();
    }
}
```

**Where it lives**  
Any Spring bean.

---

### `@AuthenticationPrincipal`

**What it does**  
Injects the currently authenticated principal (or a property of it) into a controller method.

**Typical usage**

```java
@RestController
public class ProfileController {

    @GetMapping("/me")
    public UserProfile me(@AuthenticationPrincipal UserDetails user) {
        return userService.findByUsername(user.getUsername());
    }
}
```

If you have a custom `UserDetails` implementation (`AppUser`), Spring will inject that type automatically:

```java
@GetMapping("/me")
public AppUser me(@AuthenticationPrincipal AppUser user) { … }
```

**Where it lives**  
Controller method parameters.

---

### `@WithMockUser`

**What it does**  
Mocks an authenticated user for unit/integration tests.

**Typical usage**

```java
@SpringBootTest
@AutoConfigureMockMvc
class AdminControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void dashboardShouldBeAccessible() throws Exception {
        mockMvc.perform(get("/admin/dashboard"))
               .andExpect(status().isOk());
    }
}
```

You can also mock anonymous users:

```java
@Test
@WithAnonymousUser
void publicEndpointAccessible() throws Exception { … }
```

**Where it lives**  
JUnit test methods or test classes.

---

### `@SecurityConfigurerAdapter`

**What it does**  
Allows you to register custom security configurers (e.g., custom filters, authentication providers).

**Typical usage** (Spring 6+)

```java
@Configuration
public class CustomSecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .addFilterAfter(new MyCustomFilter(), BasicAuthenticationFilter.class)
            .authorizeHttpRequests(authz -> authz.anyRequest().authenticated());
        return http.build();
    }
}
```

If you still extend `WebSecurityConfigurerAdapter` (pre‑Spring 6), you would override `configure(HttpSecurity http)` and call `http.apply(myConfigurer());`.

**Where it lives**  
A configuration class that declares a `SecurityFilterChain` bean.

---

### `@EnableOAuth2Client`

**What it does**  
Enables Spring OAuth2 client support (e.g., for social logins). **Deprecated** in Spring 6 – use the newer OAuth2 client support in Spring Boot instead.

**Typical usage** (legacy code)

```java
@Configuration
@EnableOAuth2Client
public class OAuth2ClientConfig {
    // Spring Boot auto‑configures OAuth2ClientContext, OAuth2RestTemplate, etc.
}
```

**Modern alternative**  
Add `spring-boot-starter-oauth2-client` and configure `spring.security.oauth2.client.*` properties in `application.yml`.  
You can then inject `OAuth2AuthorizedClientService` or use `@RegisteredOAuth2AuthorizedClient` in controllers.

---

### `@EnableAuthorizationServer` / `@EnableResourceServer`

**What it does**  
Old way to bootstrap an OAuth2 authorization server or resource server. Both annotations are **deprecated** (removed in Spring 6).

**Typical usage** (legacy code)

```java
@Configuration
@EnableAuthorizationServer
public class AuthorizationServerConfig extends AuthorizationServerConfigurerAdapter {
    // configure clients, tokens, etc.
}
```

**Modern alternative**

- **Authorization server** – build a separate Spring Boot application with the **Spring Authorization Server** dependency (`org.springframework.security:spring-security-oauth2-authorization-server`).
- **Resource server** – simply add `spring-boot-starter-oauth2-resource-server` and set `spring.security.oauth2.resourceserver.jwt.issuer-uri` (or `opaqueToken` settings) in `application.yml`. No `@EnableResourceServer` annotation is needed.

---

Below is a minimal “token‑only” setup that works with a React front‑end (or any SPA).  
No internal login page, no form‑login – the front‑end posts **username/password** to a REST endpoint and receives a **JWT** that it stores locally (usually `localStorage` or `cookies`).  
All subsequent API calls send the token in the `Authorization: Bearer …` header.

---

## JWT token

## 1. Maven / Gradle dependencies

```xml
<!-- Spring Boot 3.x -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>

<!-- JWT helper – jjwt 0.11.5 -->
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.11.5</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-impl</artifactId>
    <version>0.11.5</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-jackson</artifactId> <!-- or jjwt-gson if you prefer -->
    <version>0.11.5</version>
    <scope>runtime</scope>
</dependency>
```

(If you’re using Gradle, just add the same artifacts.)

---

## 2. User entity & repository

```java
@Entity
@Table(name = "users")
public class AppUser {

    @Id @GeneratedValue
    private Long id;

    @Column(unique = true, nullable = false)
    private String username;

    @Column(nullable = false)
    private String password;      // stored *encoded* (BCrypt)

    // getters / setters
}
```

```java
public interface AppUserRepository extends JpaRepository<AppUser, Long> {
    Optional<AppUser> findByUsername(String username);
}
```

---

## 3. Custom `UserDetailsService`

```java
@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final AppUserRepository repo;

    public CustomUserDetailsService(AppUserRepository repo) {
        this.repo = repo;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        AppUser u = repo.findByUsername(username)
                        .orElseThrow(() -> new UsernameNotFoundException("No user " + username));
        return User.builder()
                   .username(u.getUsername())
                   .password(u.getPassword())            // BCrypt‑encoded
                   .roles("USER")                         // or whatever roles you want
                   .build();
    }
}
```

---

## 4. JWT utility class

```java
@Component
public class JwtUtil {

    // 15‑minute expiration – tweak as needed
    private static final long EXPIRATION_MS = 15 * 60 * 1000;

    // 256‑bit secret – keep this in `application.yml` (or env var)
    @Value("${jwt.secret}")
    private String secret;

    public String generateToken(UserDetails userDetails) {
        return Jwts.builder()
                .setSubject(userDetails.getUsername())
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + EXPIRATION_MS))
                .signWith(Keys.hmacShaKeyFor(secret.getBytes()), SignatureAlgorithm.HS256)
                .compact();
    }

    public String extractUsername(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(secret.getBytes())
                .build()
                .parseClaimsJws(token)
                .getBody()
                .getSubject();
    }

    public boolean validateToken(String token, UserDetails userDetails) {
        String username = extractUsername(token);
        return username.equals(userDetails.getUsername()) &&
               !isTokenExpired(token);
    }

    private boolean isTokenExpired(String token) {
        Date exp = Jwts.parserBuilder()
                .setSigningKey(secret.getBytes())
                .build()
                .parseClaimsJws(token)
                .getBody()
                .getExpiration();
        return exp.before(new Date());
    }
}
```

`jwt.secret` is a 32‑byte base‑64 value (e.g., `AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`).

---

## 5. Authentication controller (no form page)

```java
@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthenticationManager authManager;
    private final CustomUserDetailsService userDetailsService;
    private final JwtUtil jwtUtil;

    public AuthController(AuthenticationManager authManager,
                          CustomUserDetailsService userDetailsService,
                          JwtUtil jwtUtil) {
        this.authManager = authManager;
        this.userDetailsService = userDetailsService;
        this.jwtUtil = jwtUtil;
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody AuthRequest request) {
        try {
            Authentication auth = authManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.getUsername(),
                                                           request.getPassword()));
            SecurityContextHolder.getContext().setAuthentication(auth);
            UserDetails userDetails = (UserDetails) auth.getPrincipal();
            String token = jwtUtil.generateToken(userDetails);
            return ResponseEntity.ok(new AuthResponse(token));
        } catch (BadCredentialsException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                                 .body("Invalid credentials");
        }
    }
}
```

`AuthRequest` & `AuthResponse`:

```java
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class AuthRequest { private String username; private String password; }

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class AuthResponse { private String token; }
```

The front‑end calls `POST /auth/login` with a JSON body `{ "username": "...", "password": "..." }`.  
The server replies with `{ "token": "eyJhbGciOi..." }`.  
React stores the token (e.g., `localStorage.setItem('token', token)`).

---

## 6. JWT filter (stateless request‑processing)

```java
@Component
public class JwtRequestFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final CustomUserDetailsService userDetailsService;

    public JwtRequestFilter(JwtUtil jwtUtil,
                            CustomUserDetailsService userDetailsService) {
        this.jwtUtil = jwtUtil;
        this.userDetailsService = userDetailsService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {

        final String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);
        String username = null;
        String jwt = null;

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            jwt = authHeader.substring(7);
            try {
                username = jwtUtil.extractUsername(jwt);
            } catch (JwtException e) {
                // invalid token – let it fail later
            }
        }

        if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            UserDetails userDetails = userDetailsService.loadUserByUsername(username);
            if (jwtUtil.validateToken(jwt, userDetails)) {
                UsernamePasswordAuthenticationToken auth =
                        new UsernamePasswordAuthenticationToken(userDetails, null,
                                userDetails.getAuthorities());
                SecurityContextHolder.getContext().setAuthentication(auth);
            }
        }
        chain.doFilter(request, response);
    }
}
```

---

## 7. Security configuration (Spring Security 5+ style)

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final CustomUserDetailsService userDetailsService;
    private final JwtRequestFilter jwtFilter;

    public SecurityConfig(CustomUserDetailsService userDetailsService,
                          JwtRequestFilter jwtFilter) {
        this.userDetailsService = userDetailsService;
        this.jwtFilter = jwtFilter;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())                     // stateless
            .sessionManagement(sm -> sm.sessionCreationPolicy(
                    SessionCreationPolicy.STATELESS))         // no HttpSession

            // 1️⃣  Allow the public login endpoint
            .authorizeHttpRequests(auth -> auth
                    .requestMatchers("/auth/login").permitAll()
                    .anyRequest().authenticated())

            // 2️⃣  Disable the default form‑login & basic UI
            .formLogin(form -> form.disable())
            .httpBasic(basic -> basic.disable())

            // 3️⃣  Register the JWT filter **before** SpringAuthFilter
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /* ----------  AuthenticationManager bean ---------- */
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration authConfig) throws Exception {
        return authConfig.getAuthenticationManager();
    }

    @Bean
    public BCryptPasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public UserDetailsService userDetailsService() {
        return userDetailsService;
    }
}
```

With the above config:

- `POST /auth/login` is **open** to anyone.
- Every other request must supply a valid JWT.  
  If the `Authorization: Bearer …` header is missing or the token is invalid, Spring returns `401 Unauthorized`.

---

## 7. `application.yml` (or `application.properties`)

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb # replace with your DB
    username: sa
    password:

  jpa:
    hibernate:
      ddl-auto: update

jwt:
  secret: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" # 256‑bit base64 key
```

(If you keep the secret in plain text in the repo, make sure the repo is private, otherwise put it in an environment variable.)

---

## 8. How the React app talks to the API

```js
// 1️⃣  login
await fetch("/auth/login", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ username, password }),
})
  .then((r) => r.json())
  .then((data) => localStorage.setItem("token", data.token));

// 2️⃣  subsequent API call
await fetch("/api/secret", {
  headers: { Authorization: `Bearer ${localStorage.getItem("token")}` },
});
```

That’s it!  
You now have:

| **What you send**         | **What the server does**                                                                                                                 | **What you receive**                        |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `POST /auth/login` (JSON) | Authenticates against DB, generates JWT                                                                                                  | `{ token: "…"}`                             |
| **Every other API call**  | Reads `Authorization: Bearer …`, validates the JWT, creates a `UsernamePasswordAuthenticationToken` and puts it in the `SecurityContext` | 200 OK (or 401 if token is missing/invalid) |

Because the filter never touches `HttpSession`, your API is fully stateless – perfect for an SPA.

Feel free to add:

- a _refresh‑token_ endpoint (long‑lived JWT that gives a new short‑lived token),
- role‑based `@PreAuthorize` or `hasRole` checks,
- a `User`‑registration endpoint,
- exception handling / error DTOs, etc.

But the snippets above are enough to get a React app talking to a Spring Boot back‑end **without ever showing a login page**.

---

## role‑based `@PreAuthorize` or `hasRole` checks

Below is a **complete, copy‑and‑paste** example that shows

1. **How to give every user a set of roles** (`ROLE_ADMIN`, `ROLE_USER`, …).
2. **How Spring Security turns those roles into `GrantedAuthority` objects** so they can be used in the `@PreAuthorize` / `hasRole` checks.
3. **A few endpoints** that illustrate the different ways you can secure a method.

> ⚡️ The whole stack runs on the newest Spring Boot 3.x / Spring Security 6.x – no deprecated APIs.

---

## 1. Domain objects

```java
// ──────  src/main/java/com/example/security/entity/User.java  ──────
@Entity
@Table(name = "app_user")
public class User {

    @Id @GeneratedValue
    private Long id;

    @Column(nullable = false, unique = true)
    private String username;

    @Column(nullable = false)
    private String password;   // BCrypt‑encoded

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "user_role",
                     joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "role")
    @Enumerated(EnumType.STRING)
    private Set<Role> roles = new HashSet<>();

    // getters / setters
}

// ──────  src/main/java/com/example/security/entity/Role.java  ──────
public enum Role {
    USER,
    ADMIN
}
```

> **Why `@ElementCollection`?**  
> It lets you keep a simple `Set<Role>` without a separate `Role` entity.  
> The database will have a table `user_role` with columns `user_id` and `role`.

---

## 2. Repository

```java
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
}
```

---

## 3. `UserDetails` implementation

Spring Security needs a `UserDetails` instance that carries the authorities.

```java
// ──────  src/main/java/com/example/security/security/CustomUserDetails.java  ──────
public class CustomUserDetails implements UserDetails {

    private final User user;

    public CustomUserDetails(User user) {
        this.user = user;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        // Prefix `ROLE_` is mandatory for `hasRole("ADMIN")` to work
        return user.getRoles().stream()
                .map(r -> new SimpleGrantedAuthority("ROLE_" + r.name()))
                .collect(Collectors.toSet());
    }

    @Override
    public String getPassword() { return user.getPassword(); }

    @Override
    public String getUsername() { return user.getUsername(); }

    @Override public boolean isAccountNonExpired()   { return true; }
    @Override public boolean isAccountNonLocked()    { return true; }
    @Override public boolean isCredentialsNonExpired() { return true; }
    @Override public boolean isEnabled()             { return true; }
}
```

---

## 4. `UserDetailsService`

```java
// ──────  src/main/java/com/example/security/security/CustomUserDetailsService.java  ──────
@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepo;

    public CustomUserDetailsService(UserRepository userRepo) {
        this.userRepo = userRepo;
    }

    @Override
    public UserDetails loadUserByUsername(String username) {
        User user = userRepo.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        return new CustomUserDetails(user);
    }
}
```

---

## 5. Security configuration

```java
// ──────  src/main/java/com/example/security/config/SecurityConfig.java  ──────
@Configuration
@EnableWebSecurity
@EnableMethodSecurity   // ← <‑‑ enables @PreAuthorize etc.
public class SecurityConfig {

    private final CustomUserDetailsService userDetailsService;

    public SecurityConfig(CustomUserDetailsService userDetailsService) {
        this.userDetailsService = userDetailsService;
    }

    @Bean
    public BCryptPasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(); }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

            // public endpoints
            .authorizeHttpRequests(auth -> auth
                    .requestMatchers("/auth/**").permitAll()
                    .anyRequest().authenticated())

            .httpBasic(httpBasic -> httpBasic.disable())   // no basic auth UI
            .formLogin(form -> form.disable());

        return http.build();
    }

    @Bean
    public AuthenticationManager authenticationManager(HttpSecurity http) throws Exception {
        return http.getSharedObject(AuthenticationManagerBuilder.class)
                   .userDetailsService(userDetailsService)
                   .passwordEncoder(passwordEncoder())
                   .and()
                   .build();
    }
}
```

---

## 6. Authentication controller (unchanged from the previous answer)

```java
// ──────  src/main/java/com/example/security/controller/AuthController.java  ──────
@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthenticationManager authManager;
    private final BCryptPasswordEncoder encoder;
    private final JwtUtil jwtUtil;        // you already have this from the previous snippet

    public AuthController(AuthenticationManager authManager,
                          BCryptPasswordEncoder encoder,
                          JwtUtil jwtUtil) {
        this.authManager = authManager;
        this.encoder = encoder;
        this.jwtUtil = jwtUtil;
    }

    @PostMapping("/login")
    public ResponseEntity<TokenDto> login(@RequestBody LoginDto dto) {
        Authentication auth = authManager.authenticate(
                new UsernamePasswordAuthenticationToken(dto.getUsername(), dto.getPassword()));
        String token = jwtUtil.generateToken((UserDetails) auth.getPrincipal());
        return ResponseEntity.ok(new TokenDto(token));
    }
}
```

> `TokenDto`, `LoginDto` – simple DTOs for JSON payloads.

---

## 7. **Role‑based endpoint examples**

### 7‑1 Securing a controller method

```java
// ──────  src/main/java/com/example/security/controller/AdminController.java  ──────
@RestController
@RequestMapping("/admin")
public class AdminController {

    @GetMapping("/dashboard")
    @PreAuthorize("hasRole('ADMIN')")          //  only users with ROLE_ADMIN
    public ResponseEntity<String> dashboard() {
        return ResponseEntity.ok("Secret admin dashboard – visible only to ADMIN");
    }
}
```

> **What does `hasRole('ADMIN')` do?**  
> It internally expands to `hasAuthority('ROLE_ADMIN')`.  
> That means every role in your database **must** be stored without the `ROLE_` prefix, but `CustomUserDetails#getAuthorities()` prefixes it for you.

### 7‑2 Securing a service method

You can move the security closer to the business logic.

```java
// ──────  src/main/java/com/example/security/service/CustomerService.java  ──────
@Service
public class CustomerService {

    @PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
    public List<Customer> findAllCustomers() {
        // … load customers
    }

    @PreAuthorize("hasRole('ADMIN')")
    public void deleteCustomer(Long id) {
        // … delete
    }
}
```

### 7‑3 Using `hasAuthority()` directly

If you prefer _no_ `ROLE_` prefix, simply use `hasAuthority("ADMIN")`:

```java
@PreAuthorize("hasAuthority('ADMIN')")
public String adminOnlyEndpoint() { … }
```

> ⚠️ **Important:** `SimpleGrantedAuthority("ROLE_ADMIN")` is what `hasAuthority("ROLE_ADMIN")` looks for, whereas `hasRole("ADMIN")` expects the string `"ROLE_ADMIN"` automatically.

### 7‑4 Multiple roles (OR / AND)

```java
@PreAuthorize("hasAnyRole('ADMIN', 'MANAGER')")
```

or

```java
@PreAuthorize("hasRole('ADMIN') and hasAuthority('EDIT_ALL')")
```

---

## 7. Quick “seed” data

```java
// ──────  src/main/java/com/example/security/config/DataSeeder.java  ──────
@Component
public class DataSeeder implements CommandLineRunner {

    private final UserRepository userRepo;
    private final BCryptPasswordEncoder encoder;

    public DataSeeder(UserRepository userRepo, BCryptPasswordEncoder encoder) {
        this.userRepo = userRepo;
        this.encoder = encoder;
    }

    @Override
    public void run(String... args) {
        if (userRepo.findByUsername("alice").isEmpty()) {
            User alice = new User();
            alice.setUsername("alice");
            alice.setPassword(encoder.encode("alice123"));
            alice.setRoles(Set.of(Role.USER));
            userRepo.save(alice);
        }

        if (userRepo.findByUsername("bob").isEmpty()) {
            User bob = new User();
            bob.setUsername("bob");
            bob.setPassword(encoder.encode("bob123"));
            bob.setRoles(Set.of(Role.USER, Role.ADMIN));
            userRepo.save(bob);
        }
    }
}
```

Now when you run the app:

| User  | Password | Roles                     |
| ----- | -------- | ------------------------- |
| alice | alice123 | `ROLE_USER`               |
| bob   | bob123   | `ROLE_USER`, `ROLE_ADMIN` |

---

## 8. Testing the protection

```bash
# 1️⃣  Login – will return a JWT
curl -X POST -H "Content-Type: application/json" \
     -d '{"username":"bob","password":"bob123"}' \
     http://localhost:8080/auth/login

# 2️⃣  Call the admin endpoint
curl -H "Authorization: Bearer <JWT>" http://localhost:8080/admin/dashboard
# → 200 OK (because Bob is ADMIN)

curl -H "Authorization: Bearer <JWT>" http://localhost:8080/admin/dashboard  # with Alice’s JWT
# → 403 Forbidden (because Alice is NOT ADMIN)
```

If you try the same endpoint with **no JWT** you’ll get a **401 Unauthorized**.

---

## 9. Recap – the “magic” line

```java
@EnableMethodSecurity   // <‑‑ enables @PreAuthorize, @Secured, @RolesAllowed
```

All you have to do is:

1.  Store roles (`enum Role` / `Set<Role>`).
2.  Convert them to `GrantedAuthority` with the `"ROLE_"` prefix.
3.  Sprinkle `@PreAuthorize("hasRole('ADMIN')")` (or `hasAuthority('ADMIN')`) on any method – controller, service, repository, even a custom method in your own classes.

---

### TL;DR – one‑liner snippet

```java
@PreAuthorize("hasRole('ADMIN')")
@GetMapping("/admin/dashboard")
public String dashboard() { … }
```

That single annotation guarantees **only** users that belong to the `ADMIN` role can reach the method. All other users (including authenticated users with `USER` role) receive a 403 Forbidden.

---

### a User‑registration endpoint

Below is a **drop‑in “register a new user”** endpoint that fits right into the sample project we built earlier.  
It demonstrates:

| Step | What you’ll do                                                              |
| ---- | --------------------------------------------------------------------------- |
| 1    | Accept a **JSON payload** (`username`, `password`, optional `roles`).       |
| 2    | Validate the payload (unique username, password strength).                  |
| 3    | Encode the password with `BCryptPasswordEncoder`.                           |
| 4    | Persist the `User` entity with its roles.                                   |
| 5    | (Optional) Return a JWT immediately so the client can log‑in automatically. |

> ⚠️ **Security note** – never expose the raw password. The endpoint is open to public users (`permitAll()`) because it is the first point where an account is created.

---

## 1. DTOs

```java
// ──────  src/main/java/com/example/security/dto/RegisterDto.java  ──────
public record RegisterDto(
        String username,
        String password,
        Set<String> roles   // e.g. ["USER", "ADMIN"]
) {}
```

```java
// ──────  src/main/java/com/example/security/dto/TokenDto.java  ──────
public record TokenDto(String token) {}
```

> `TokenDto` is reused from the login controller so you can return a token from the registration flow if you wish.

---

## 2. Service layer

```java
// ──────  src/main/java/com/example/security/service/UserService.java  ──────
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepo;
    private final BCryptPasswordEncoder encoder;
    private final JwtUtil jwtUtil;    // the same JWT util you already have

    public User registerUser(RegisterDto dto) {
        if (userRepo.findByUsername(dto.username()).isPresent()) {
            throw new IllegalArgumentException("Username already taken");
        }

        User user = new User();
        user.setUsername(dto.username());
        user.setPassword(encoder.encode(dto.password()));

        // Convert the string roles into the enum set
        Set<Role> roles = dto.roles() != null
                ? dto.roles().stream()
                        .map(String::toUpperCase)
                        .map(Role::valueOf)
                        .collect(Collectors.toSet())
                : Set.of(Role.USER);   // default

        user.setRoles(roles);
        return userRepo.save(user);
    }

    public String generateJwtFor(User user) {
        return jwtUtil.generateToken(new CustomUserDetails(user));
    }
}
```

> `@RequiredArgsConstructor` (Lombok) auto‑injects the dependencies.

---

## 3. Controller

```java
// ──────  src/main/java/com/example/security/controller/AuthController.java  ──────
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final UserService userService;
    private final AuthenticationManager authManager;
    private final BCryptPasswordEncoder encoder;
    private final JwtUtil jwtUtil;

    // --------------- existing login endpoint ----------------

    @PostMapping("/login")
    public ResponseEntity<TokenDto> login(@RequestBody LoginDto dto) {
        Authentication auth = authManager.authenticate(
                new UsernamePasswordAuthenticationToken(dto.getUsername(), dto.getPassword()));
        String token = jwtUtil.generateToken((UserDetails) auth.getPrincipal());
        return ResponseEntity.ok(new TokenDto(token));
    }

    // --------------- NEW registration endpoint ----------------

    @PostMapping("/register")
    public ResponseEntity<TokenDto> register(@RequestBody RegisterDto dto) {
        User newUser = userService.registerUser(dto);

        // Optionally log the user in automatically:
        String token = userService.generateJwtFor(newUser);

        return ResponseEntity.status(HttpStatus.CREATED).body(new TokenDto(token));
    }
}
```

> **What happens?**
>
> 1. The user submits JSON.
> 2. `UserService.registerUser` checks uniqueness, encodes the password, sets the roles, and saves the entity.
> 3. We immediately generate a JWT (so the client can use the account straight away).
> 4. The response status is **201 Created** with the JWT.

---

## 4. Security configuration tweak

If you had previously set:

```java
.authorizeHttpRequests(auth -> auth
        .requestMatchers("/auth/**").permitAll()
        .anyRequest().authenticated())
```

you’re already good – `/auth/register` is open to everyone.  
If you had used the newer `authorizeHttpRequests((auth) -> auth.anyRequest().authenticated())` form, add:

```java
.authorizeHttpRequests(auth -> auth
        .requestMatchers("/auth/register", "/auth/login").permitAll()
        .anyRequest().authenticated())
```

---

## 5. Sample `curl` tests

```bash
# Register a new user (Alice) – she will automatically get a JWT
curl -X POST http://localhost:8080/auth/register \
     -H "Content-Type: application/json" \
     -d '{"username":"alice","password":"StrongP@ssw0rd","roles":["USER"]}'

# Expected response (201 Created)
# { "token": "<JWT>" }

# Use that token to call a protected endpoint
curl http://localhost:8080/admin/dashboard \
     -H "Authorization: Bearer <JWT>"
# → 403 Forbidden because Alice is not ADMIN

# Now register an admin user
curl -X POST http://localhost:8080/auth/register \
     -H "Content-Type: application/json" \
     -d '{"username":"bob","password":"AdminP@ss123","roles":["ADMIN"]}'

# Use Bob’s token to access admin endpoint
curl http://localhost:8080/admin/dashboard \
     -H "Authorization: Bearer <JWT>"
# → 200 OK
```

---

## 6. What else can you do?

| Feature                     | How to add                                                                                  |
| --------------------------- | ------------------------------------------------------------------------------------------- |
| **Email verification**      | After saving the user, send a confirmation link containing a signed token.                  |
| **Password reset**          | Create a `/auth/forgot` & `/auth/reset` flow, generate a short‑lived JWT for the reset.     |
| **Rate‑limit registration** | Add a Spring Cloud Gateway or `Bucket4j` filter to cap new account creation per IP.         |
| **Audit log**               | Save `registration_time`, `registration_ip` in the `User` entity or a separate audit table. |

---

### TL;DR – register a user in one method

```java
@PostMapping("/auth/register")
public ResponseEntity<TokenDto> register(@RequestBody RegisterDto dto) {
    User user = userService.registerUser(dto);   // save + encode password
    String token = userService.generateJwtFor(user); // optional auto‑login
    return ResponseEntity.status(HttpStatus.CREATED).body(new TokenDto(token));
}
```

That’s all you need to let anyone create an account and immediately get a token you can use to authenticate subsequent requests.
