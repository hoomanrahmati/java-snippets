## Spring Cloud Gateway

[back](../README.md)

[more sample](./spring-cloud-gateway2.md)

An **API Gateway** is a server that sits between clients (web apps, mobile apps, third-party services) and your backend services. Instead of clients calling each microservice directly, they call the gateway, which routes the request to the appropriate service.

```
Without API Gateway

Client
  ├── User Service
  ├── Order Service
  ├── Product Service
  └── Payment Service

With API Gateway

Client
   |
API Gateway
  ├── User Service
  ├── Order Service
  ├── Product Service
  └── Payment Service
```

In the Spring ecosystem, the common implementation is **Spring Cloud Gateway**.

## Why use an API Gateway?

### 1. Single Entry Point

Instead of exposing multiple services:

```
users.example.com
orders.example.com
products.example.com
payments.example.com
```

You expose just one endpoint:

```
api.example.com
```

The gateway routes requests:

```
GET /users/5
        ↓
User Service

GET /orders/12
        ↓
Order Service
```

Clients don't need to know where services actually live.

---

## 2. Authentication & Authorization

This is probably the biggest advantage.

Instead of every service validating JWT tokens:

```
Client
   |
 JWT
   |
User Service
Order Service
Product Service
```

Every service has duplicated authentication logic.

With a gateway:

```
Client
   |
 JWT
   |
API Gateway
   |
Valid?
   |
Yes
   |
---------------------
|        |          |
User   Order    Product
```

The gateway validates the JWT once.

If invalid:

```
401 Unauthorized
```

The request never reaches the services.

The gateway can also forward user information to downstream services via headers if appropriate.

---

## 3. Routing

Spring Cloud Gateway makes routing easy.

Example:

```java
@Bean
RouteLocator customRoutes(RouteLocatorBuilder builder) {
    return builder.routes()
        .route("user_route", r ->
            r.path("/users/**")
             .uri("lb://USER-SERVICE"))

        .route("order_route", r ->
            r.path("/orders/**")
             .uri("lb://ORDER-SERVICE"))

        .build();
}
```

or in YAML:

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user-service
          uri: lb://USER-SERVICE
          predicates:
            - Path=/users/**
```

---

## 4. Load Balancing

Suppose you have:

```
Order Service

Instance 1
Instance 2
Instance 3
```

The gateway can distribute requests:

```
Client
   |
Gateway
 ├── Instance 1
 ├── Instance 2
 └── Instance 3
```

Usually with Spring Cloud LoadBalancer or a service registry like Eureka.

---

## 5. Rate Limiting

Prevent abuse.

Example:

```
Client sends

10000 requests/minute
```

Gateway:

```
429 Too Many Requests
```

instead of overwhelming your services.

---

## 6. Centralized Logging

Every request goes through one place.

Gateway logs:

```
GET /users/10
IP: 10.0.0.15
Time: 12ms
User: john
```

Instead of collecting logs from many services.

---

## 7. Cross-cutting Concerns

Things every service would otherwise implement:

- Logging
- Authentication
- CORS
- Compression
- Metrics
- Tracing
- Rate limiting
- Header manipulation

The gateway handles these once.

---

## 8. SSL Termination

Instead of HTTPS on every service:

```
Internet
   |
HTTPS
   |
Gateway
   |
HTTP
   |
Internal services
```

Only the gateway manages TLS certificates, while communication inside a trusted network can remain HTTP (or HTTPS if your security requirements call for end-to-end encryption).

---

## 9. Hide Internal Services

Clients never know:

```
http://10.1.4.23:8080
```

or

```
http://user-service:8080
```

Only:

```
api.company.com
```

Internal topology can change without affecting clients.

---

## 10. API Aggregation

Suppose a mobile app needs:

- User
- Orders
- Recommendations

Without gateway:

```
3 HTTP calls
```

With gateway:

```
1 HTTP call

/api/dashboard
```

Gateway internally calls:

```
User Service
Order Service
Recommendation Service
```

and combines the results into one response, reducing network round trips.

---

# Spring Cloud Gateway Filters

One of Spring Cloud Gateway's strengths is its filter mechanism.

Example:

```java
.route("user-service", r -> r
    .path("/users/**")
    .filters(f -> f
        .addRequestHeader("X-App", "MyApp")
        .stripPrefix(1))
    .uri("lb://USER-SERVICE"))
```

Filters can:

- Add headers
- Remove headers
- Rewrite paths
- Validate tokens
- Log requests
- Measure execution time
- Modify responses

---

# Example Request Flow

```
Browser

   |
   | GET /orders/12
   |
API Gateway
   |
   | Validate JWT
   | Check Rate Limit
   | Log Request
   | Route Request
   |
Order Service
   |
Database
   |
Order Service
   |
API Gateway
   |
Browser
```

The Order Service can focus on business logic without duplicating infrastructure concerns.

---

# When should you use an API Gateway?

Use one when you have **multiple backend services** (microservices) that clients need to access. It centralizes routing, security, observability, and other cross-cutting concerns.

For a **single Spring Boot monolith**, an API Gateway is often unnecessary. Since there's only one application, adding a gateway introduces another component to deploy and maintain without providing much benefit. If you later split the monolith into microservices, introducing a gateway becomes much more valuable.

## Summary

| Feature                | Benefit                                              |
| ---------------------- | ---------------------------------------------------- |
| Single entry point     | Simplifies client access                             |
| Routing                | Directs requests to the correct service              |
| Authentication         | Centralized JWT/OAuth2 validation                    |
| Authorization          | Enforce access policies before services are reached  |
| Load balancing         | Distributes traffic across service instances         |
| Rate limiting          | Protects services from abuse                         |
| Logging & metrics      | Centralized observability                            |
| CORS handling          | Configure once for all services                      |
| SSL termination        | Centralized certificate management                   |
| API aggregation        | Combine responses from multiple services             |
| Hide internal topology | Keeps internal services private and easier to change |

For Spring Boot microservices, **Spring Cloud Gateway** is generally the recommended gateway because it integrates well with Spring Security, Spring Cloud LoadBalancer, service discovery (such as Eureka), and the rest of the Spring ecosystem.

---

Yes, that's a common architecture. One thing I'd change in your plan is **who is responsible for service discovery**.

With **Kubernetes**, you usually **do not need Eureka**. Kubernetes already provides service discovery through its DNS.

Your architecture would look like this:

```text
                  Internet
                      |
                Spring Cloud Gateway
                 (Spring Boot)
                      |
        +-------------+--------------+
        |             |              |
   user-service   order-service   payment-service
        |             |              |
   Kubernetes    Kubernetes     Kubernetes
        \             |             /
          Kubernetes Networking
```

The gateway handles:

- ✅ JWT authentication
- ✅ CORS
- ✅ Routing
- ✅ Logging
- ✅ Rate limiting (later)
- ✅ Header manipulation
- ✅ SSL termination (usually Ingress handles this)

Kubernetes handles:

- ✅ Service discovery
- ✅ Load balancing between Pods
- ✅ Health checks
- ✅ Scaling

---

# Project Structure

```
gateway
│
├── config
│     SecurityConfig.java
│     CorsConfig.java
│     JwtAuthenticationFilter.java
│
├── filter
│     LoggingFilter.java
│
├── GatewayApplication.java
│
└── application.yml
```

---

# Dependencies

```xml
<dependencies>

    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-gateway-server-webflux</artifactId>
    </dependency>

    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-security</artifactId>
    </dependency>

    <dependency>
        <groupId>io.jsonwebtoken</groupId>
        <artifactId>jjwt-api</artifactId>
        <version>0.12.6</version>
    </dependency>

    <dependency>
        <groupId>io.jsonwebtoken</groupId>
        <artifactId>jjwt-impl</artifactId>
        <scope>runtime</scope>
        <version>0.12.6</version>
    </dependency>

    <dependency>
        <groupId>io.jsonwebtoken</groupId>
        <artifactId>jjwt-jackson</artifactId>
        <scope>runtime</scope>
        <version>0.12.6</version>
    </dependency>

</dependencies>
```

---

# application.yml

Notice there is **no `lb://`** because Kubernetes DNS resolves the services.

```yaml
server:
  port: 8080

spring:
  cloud:
    gateway:
      routes:
        - id: user-service
          uri: http://user-service:8080
          predicates:
            - Path=/api/users/**

        - id: order-service
          uri: http://order-service:8080
          predicates:
            - Path=/api/orders/**

        - id: payment-service
          uri: http://payment-service:8080
          predicates:
            - Path=/api/payments/**
```

Inside Kubernetes:

```
http://user-service:8080
```

works automatically.

---

# Security Configuration

Since Gateway uses **Spring WebFlux**, use the reactive security API.

```java
@Configuration
@EnableWebFluxSecurity
public class SecurityConfig {

    @Bean
    SecurityWebFilterChain securityFilterChain(ServerHttpSecurity http,
                                               JwtAuthenticationFilter jwtFilter) {

        return http
                .csrf(ServerHttpSecurity.CsrfSpec::disable)

                .cors(Customizer.withDefaults())

                .authorizeExchange(exchange -> exchange

                        .pathMatchers("/auth/**").permitAll()

                        .anyExchange().authenticated())

                .addFilterAt(jwtFilter,
                        SecurityWebFiltersOrder.AUTHENTICATION)

                .build();
    }

}
```

---

# JWT Filter

The filter validates the token before forwarding the request.

```java
@Component
public class JwtAuthenticationFilter implements WebFilter {

    private final SecretKey secret =
            Keys.hmacShaKeyFor(
                "my-secret-key-my-secret-key-123456"
                    .getBytes());

    @Override
    public Mono<Void> filter(ServerWebExchange exchange,
                             WebFilterChain chain) {

        String header =
            exchange.getRequest()
                    .getHeaders()
                    .getFirst(HttpHeaders.AUTHORIZATION);

        if (header == null || !header.startsWith("Bearer ")) {
            return chain.filter(exchange);
        }

        String token = header.substring(7);

        try {

            Jwts.parser()
                    .verifyWith(secret)
                    .build()
                    .parseSignedClaims(token);

            return chain.filter(exchange);

        } catch (Exception ex) {

            exchange.getResponse()
                    .setStatusCode(HttpStatus.UNAUTHORIZED);

            return exchange.getResponse().setComplete();
        }
    }
}
```

For production, you would typically create an `Authentication` object and place it into the reactive `SecurityContext` rather than only validating the token. That allows downstream authorization rules (roles, scopes, etc.) to work correctly.

---

# CORS

```java
@Configuration
public class CorsConfig {

    @Bean
    CorsConfigurationSource corsConfigurationSource() {

        CorsConfiguration config =
                new CorsConfiguration();

        config.setAllowedOrigins(List.of(
                "http://localhost:3000"));

        config.setAllowedMethods(List.of(
                "GET",
                "POST",
                "PUT",
                "DELETE"));

        config.setAllowedHeaders(List.of("*"));

        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source =
                new UrlBasedCorsConfigurationSource();

        source.registerCorsConfiguration("/**", config);

        return source;
    }

}
```

---

# Logging Filter

```java
@Component
public class LoggingFilter implements GlobalFilter {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange,
                             GatewayFilterChain chain) {

        System.out.println(
                exchange.getRequest().getMethod()
                + " "
                + exchange.getRequest().getURI());

        return chain.filter(exchange);
    }
}
```

---

# Kubernetes Service

```yaml
apiVersion: v1
kind: Service

metadata:
  name: gateway-service

spec:
  selector:
    app: gateway

  ports:
    - port: 8080
      targetPort: 8080
```

---

# Deployment

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: gateway

spec:
  replicas: 2

  selector:
    matchLabels:
      app: gateway

  template:
    metadata:
      labels:
        app: gateway

    spec:
      containers:
        - name: gateway

          image: gateway:latest

          ports:
            - containerPort: 8080
```

---

## A few production improvements

The example above is a good learning starting point, but in production I would recommend a few changes:

- **Use Spring Security's OAuth2 Resource Server** (`spring-boot-starter-oauth2-resource-server`) to validate JWTs instead of writing a custom JWT filter. It supports JWT signature validation, expiration, issuer, audience, and integrates directly with Spring Security.
- **Use Spring Cloud Gateway filters** (e.g. `GlobalFilter`, `GatewayFilter`) for gateway-specific concerns like logging, request/response mutation, and rate limiting. Use Spring Security filters for authentication and authorization.
- **Keep JWT validation at the gateway, but let downstream services authorize** based on the propagated user identity and authorities if needed.
- **Store secrets securely**, for example in Kubernetes Secrets or by using an external identity provider (Keycloak, Auth0, Okta, Azure AD, etc.), rather than hardcoding a signing key.
- **Place an Ingress controller (such as NGINX or Traefik) in front of the gateway** for external traffic. The Ingress typically handles TLS termination and exposes the gateway service, while the gateway manages routing and security.

Since you're learning Kubernetes with Spring Boot, a modern stack that maps well to real-world deployments would be:

```
Internet
    │
NGINX Ingress
    │
Spring Cloud Gateway
    │
────────────────────────────────────
│          │             │
User      Order       Payment
Service   Service      Service
    │          │             │
PostgreSQL  RabbitMQ   Redis
```

This architecture is common in production environments and avoids components (like Eureka) that Kubernetes already replaces with its own service discovery.

---

Absolutely. This is actually one of the most important concepts to understand when using Spring Cloud Gateway.

A good rule of thumb is:

| Use Spring Security | Use Spring Cloud Gateway        |
| ------------------- | ------------------------------- |
| Authentication      | Logging                         |
| Authorization       | Routing                         |
| JWT Validation      | Add/Remove Headers              |
| CSRF                | Rewrite Path                    |
| CORS                | Rate Limiting                   |
| Security Context    | Request/Response Transformation |

Think of it this way:

- **Spring Security asks:** _"Should this request be allowed?"_
- **Spring Cloud Gateway asks:** _"How should this request be processed and forwarded?"_

---

# Example Architecture

```text
Client
   │
   ▼
Spring Security Filters
   │
   ├── Validate JWT
   ├── Check Roles
   └── Create Authentication
   │
   ▼
Spring Cloud Gateway Filters
   │
   ├── Log request
   ├── Add headers
   ├── Rewrite URL
   ├── Rate limit
   └── Forward request
   │
   ▼
User Service
```

Notice that authentication happens **before** gateway filters process the request.

---

# Example 1: Logging (GlobalFilter)

This runs for every request.

```java
@Component
public class RequestLoggingFilter implements GlobalFilter, Ordered {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange,
                             GatewayFilterChain chain) {

        ServerHttpRequest request = exchange.getRequest();

        System.out.printf(
                "[%s] %s%n",
                request.getMethod(),
                request.getURI());

        return chain.filter(exchange)
                .then(Mono.fromRunnable(() -> {

                    HttpStatusCode status =
                            exchange.getResponse().getStatusCode();

                    System.out.println("Response: " + status);
                }));
    }

    @Override
    public int getOrder() {
        return -1;
    }
}
```

Output

```
GET /api/users/10
Response: 200 OK
```

No authentication logic belongs here.

---

# Example 2: Add Request Header

Suppose every microservice should know

- Gateway version
- Request id

```java
@Component
public class AddHeaderFilter implements GlobalFilter {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange,
                             GatewayFilterChain chain) {

        ServerHttpRequest request =
                exchange.getRequest()
                        .mutate()
                        .header("X-Gateway", "SpringGateway")
                        .header("X-Version", "1.0")
                        .build();

        return chain.filter(exchange.mutate()
                .request(request)
                .build());
    }
}
```

Now every service receives

```
X-Gateway: SpringGateway
X-Version: 1.0
```

---

# Example 3: Response Header

Maybe you want every response to contain

```
X-Response-Time
```

```java
@Component
public class ResponseTimeFilter
        implements GlobalFilter {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange,
                             GatewayFilterChain chain) {

        long start = System.currentTimeMillis();

        return chain.filter(exchange)
                .then(Mono.fromRunnable(() -> {

                    long duration =
                            System.currentTimeMillis() - start;

                    exchange.getResponse()
                            .getHeaders()
                            .add(
                                "X-Response-Time",
                                duration + " ms");
                }));
    }
}
```

---

# Example 4: Route-specific GatewayFilter

Only for the User Service.

```java
@Configuration
public class GatewayConfiguration {

    @Bean
    RouteLocator routes(RouteLocatorBuilder builder) {

        return builder.routes()

                .route("users", route ->

                        route.path("/users/**")

                                .filters(filter ->

                                        filter.addRequestHeader(
                                                "X-Service",
                                                "UserService"))

                                .uri("http://user-service:8080"))

                .build();
    }
}
```

Only requests going to `/users/**` receive

```
X-Service: UserService
```

---

# Example 5: Rewrite Path

Client

```
GET /api/users/5
```

Gateway changes it to

```
GET /users/5
```

```java
.filters(f -> f.rewritePath(
        "/api/(?<segment>.*)",
        "/${segment}"))
```

Your service doesn't even know the client requested `/api`.

---

# Example 6: Rate Limiting

Gateway already provides a filter.

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user
          uri: http://user-service:8080
          predicates:
            - Path=/users/**
          filters:
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate: 5
                redis-rate-limiter.burstCapacity: 10
```

Meaning

```
5 requests / second
```

Extra requests

```
429 Too Many Requests
```

No code required (it uses Redis behind the scenes).

---

# Example 7: Authentication (Spring Security)

Notice this is **not** a Gateway filter.

```java
@Bean
SecurityWebFilterChain security(ServerHttpSecurity http)
{
    return http

        .authorizeExchange(exchanges -> exchanges

            .pathMatchers("/login").permitAll()

            .pathMatchers("/admin/**")
                .hasRole("ADMIN")

            .anyExchange()
                .authenticated())

        .oauth2ResourceServer(
            oauth -> oauth.jwt())

        .build();
}
```

This is where

- JWT validation
- Role checking
- Authentication

belong.

---

# Example 8: Custom GatewayFilter

Suppose you want every request to have a correlation ID. If one isn't provided, create one.

```java
@Component
public class CorrelationIdGatewayFilter
        extends AbstractGatewayFilterFactory<CorrelationIdGatewayFilter.Config> {

    public CorrelationIdGatewayFilter() {
        super(Config.class);
    }

    @Override
    public GatewayFilter apply(Config config) {

        return (exchange, chain) -> {

            String correlationId = exchange.getRequest()
                    .getHeaders()
                    .getFirst("X-Correlation-Id");

            if (correlationId == null) {
                correlationId = UUID.randomUUID().toString();
            }

            ServerHttpRequest request = exchange.getRequest()
                    .mutate()
                    .header("X-Correlation-Id", correlationId)
                    .build();

            return chain.filter(
                    exchange.mutate()
                            .request(request)
                            .build());
        };
    }

    public static class Config {
    }
}
```

Then enable it:

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: users
          uri: http://user-service:8080
          predicates:
            - Path=/users/**
          filters:
            - CorrelationIdGatewayFilter
```

Every downstream service now receives an `X-Correlation-Id`, making it much easier to trace a request across multiple microservices.

---

## A realistic production flow

Imagine a request to `GET /orders/123`:

1. **Spring Security** checks the `Authorization: Bearer ...` header.
2. It validates the JWT (signature, expiration, issuer, audience).
3. If valid, it creates an `Authentication` object and stores it in the reactive `SecurityContext`.
4. A **GlobalFilter** logs the request and adds an `X-Correlation-Id` header.
5. A route-specific **GatewayFilter** rewrites the path from `/api/orders/123` to `/orders/123`.
6. The request is forwarded to the `order-service`.
7. When the response comes back, another **GlobalFilter** adds an `X-Response-Time` header and logs the response status.

This separation of responsibilities keeps the gateway clean:

- **Spring Security**: "Who are you? Are you allowed?"
- **Gateway Filters**: "How should this request be enriched, transformed, monitored, and routed?"

Following this pattern scales well as your gateway grows because security and routing concerns remain independent.

---

Definitely! **API Aggregation (also called Backend for Frontend or Composite API)** is one of the most useful features of an API Gateway. The idea is that the gateway calls multiple backend services and combines their responses into a single response for the client.

For example, suppose your frontend needs to display a user's dashboard.

Without aggregation, the frontend would make three requests:

```text
GET /users/1
GET /orders/user/1
GET /notifications/user/1
```

The browser waits for three HTTP calls and combines the data itself.

With aggregation, the frontend makes just one request:

```text
GET /dashboard/1
```

The gateway internally calls all three services and returns one JSON document.

---

# Services

Imagine these three microservices.

### User Service

```http
GET /users/1
```

Response:

```json
{
  "id": 1,
  "name": "Hooman",
  "email": "hooman@example.com"
}
```

---

### Order Service

```http
GET /orders/user/1
```

```json
[
  {
    "id": 10,
    "total": 120
  },
  {
    "id": 11,
    "total": 300
  }
]
```

---

### Notification Service

```http
GET /notifications/user/1
```

```json
[
  {
    "message": "Welcome!"
  },
  {
    "message": "Payment received."
  }
]
```

---

# What the client receives

The client calls only

```http
GET /dashboard/1
```

and gets

```json
{
  "user": {
    "id": 1,
    "name": "Hooman",
    "email": "hooman@example.com"
  },
  "orders": [
    {
      "id": 10,
      "total": 120
    },
    {
      "id": 11,
      "total": 300
    }
  ],
  "notifications": [
    {
      "message": "Welcome!"
    },
    {
      "message": "Payment received."
    }
  ]
}
```

---

# DTO

```java
public record DashboardResponse(
        UserDto user,
        List<OrderDto> orders,
        List<NotificationDto> notifications
) {
}
```

---

# Controller

Since Spring Cloud Gateway is built on **WebFlux**, use `WebClient`.

```java
@RestController
@RequestMapping("/dashboard")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping("/{id}")
    public Mono<DashboardResponse> dashboard(
            @PathVariable Long id) {

        return dashboardService.getDashboard(id);
    }
}
```

---

# Service

Here is where the aggregation happens.

```java
@Service
public class DashboardService {

    private final WebClient webClient;

    public DashboardService(WebClient.Builder builder) {
        this.webClient = builder.build();
    }

    public Mono<DashboardResponse> getDashboard(Long userId) {

        Mono<UserDto> user =
                webClient.get()
                        .uri("http://user-service:8080/users/{id}", userId)
                        .retrieve()
                        .bodyToMono(UserDto.class);

        Mono<List<OrderDto>> orders =
                webClient.get()
                        .uri("http://order-service:8080/orders/user/{id}", userId)
                        .retrieve()
                        .bodyToFlux(OrderDto.class)
                        .collectList();

        Mono<List<NotificationDto>> notifications =
                webClient.get()
                        .uri("http://notification-service:8080/notifications/user/{id}", userId)
                        .retrieve()
                        .bodyToFlux(NotificationDto.class)
                        .collectList();

        return Mono.zip(user, orders, notifications)
                .map(tuple -> new DashboardResponse(
                        tuple.getT1(),
                        tuple.getT2(),
                        tuple.getT3()
                ));
    }
}
```

The important part is:

```java
Mono.zip(user, orders, notifications)
```

The three HTTP requests are started **concurrently**, not one after another. The gateway waits until all three complete and then combines their results.

---

# Request Flow

```text
                  Client
                     |
          GET /dashboard/1
                     |
                     ▼
          Spring Cloud Gateway
                     |
      +--------------+--------------+
      |              |              |
      ▼              ▼              ▼
 User Service   Order Service   Notification Service
      |              |              |
      +--------------+--------------+
                     |
             Combine Results
                     |
                     ▼
              DashboardResponse
                     |
                     ▼
                  Client
```

---

# Error handling

What if the Notification Service is down?

You may decide it's not critical and return an empty list instead.

```java
Mono<List<NotificationDto>> notifications =
    webClient.get()
            .uri("http://notification-service:8080/notifications/user/{id}", userId)
            .retrieve()
            .bodyToFlux(NotificationDto.class)
            .collectList()
            .onErrorReturn(List.of());
```

Now the client still gets the dashboard:

```json
{
  "user": {
    "id": 1,
    "name": "Hooman"
  },
  "orders": [
    {
      "id": 10,
      "total": 120
    }
  ],
  "notifications": []
}
```

This is a common resilience pattern for optional data.

---

## Should aggregation always be in the API Gateway?

This is an excellent design question. While the gateway _can_ aggregate data, many teams avoid putting complex business logic into the gateway.

A common guideline is:

- **Gateway:** authentication, routing, logging, rate limiting, simple aggregation, and request/response transformation.
- **Backend-for-Frontend (BFF) or dedicated aggregation service:** complex orchestration, business rules, calling many services, retries, caching, and fallbacks.

For a small project or when learning Spring Cloud Gateway, implementing aggregation like the example above is perfectly reasonable. As systems grow, teams often move complex aggregation into a dedicated **Dashboard Service** or **BFF**, leaving the gateway focused on infrastructure concerns. This separation keeps the gateway simpler and easier to maintain.

---

Certainly. Since you've worked with Spring Boot, Kafka, microservices, and Kubernetes, I'll show you how these pieces fit together in a **real project** rather than as isolated snippets.

Let's imagine we have this system:

```text
                   Client
                      │
                      ▼
             Spring Cloud Gateway
                      │
      ┌───────────────┼────────────────┐
      │               │                │
      ▼               ▼                ▼
 User Service    Order Service   Product Service
```

---

# 1. Authentication

**Purpose:** Verify the user's identity before allowing access.

### Client

```http
GET /orders/15
Authorization: Bearer eyJhbGc...
```

### Gateway

Spring Security validates the JWT.

If invalid:

```http
401 Unauthorized
```

If valid:

```text
JWT
 ├── subject = hooman
 ├── role = ADMIN
 └── expires = tomorrow
```

Spring Security creates

```java
Authentication authentication =
    UsernamePasswordAuthenticationToken(...)
```

and stores it in the `SecurityContext`.

The request continues.

The Order Service never checks the JWT signature again (unless you choose a defense-in-depth approach).

---

# 2. Routing

The gateway decides which service receives the request.

```http
GET /users/10
```

↓

Gateway

```yaml
routes:
  - id: users
    uri: http://user-service:8080
    predicates:
      - Path=/users/**
```

↓

```text
User Service
```

Another request

```http
GET /orders/5
```

↓

```text
Order Service
```

No controller is required.

Spring Cloud Gateway routes automatically.

---

# 3. Logging

Suppose you want every request logged.

Client

```http
GET /orders/10
```

Gateway logs

```text
[INFO]

GET /orders/10

User:
hooman

IP:
192.168.1.20

Time:
13:05:41
```

Response

```text
Status: 200

Duration: 42 ms
```

Implementation

```java
@Component
public class LoggingFilter
        implements GlobalFilter {

    @Override
    public Mono<Void> filter(
            ServerWebExchange exchange,
            GatewayFilterChain chain) {

        long start = System.currentTimeMillis();

        return chain.filter(exchange)
                .then(Mono.fromRunnable(() -> {

                    long duration =
                            System.currentTimeMillis() - start;

                    System.out.println(
                            exchange.getRequest().getMethod()
                                    + " "
                                    + exchange.getRequest().getURI());

                    System.out.println(duration);
                }));
    }
}
```

Every request automatically gets logged.

---

# 4. Rate Limiting

Suppose one client sends

```text
5000 requests/second
```

Without rate limiting

```text
Gateway

↓

Order Service

↓

Database dies ☠
```

Instead

Gateway

```text
Allowed

10 req/sec
```

Request 11

↓

```http
429 Too Many Requests
```

Configuration

```yaml
filters:
  - name: RequestRateLimiter
    args:
      redis-rate-limiter.replenishRate: 10
      redis-rate-limiter.burstCapacity: 20
```

No Java code.

Gateway handles everything.

---

# 5. Simple Aggregation

Dashboard page.

Browser needs

```text
User

Orders

Products
```

Without gateway

```text
Browser

↓

GET /users

↓

GET /orders

↓

GET /products
```

Three HTTP requests.

Instead

```http
GET /dashboard
```

Gateway

```text
User Service

↓

Order Service

↓

Product Service
```

Combine

```json
{
  "user": {},
  "orders": [],
  "products": []
}
```

Return once.

Only one request from the browser.

---

# 6. Request Transformation

Suppose your old mobile app sends

```http
GET /v1/users/15
```

But the new service expects

```http
GET /users/15
```

Gateway rewrites it.

Configuration

```yaml
filters:
  - RewritePath=/v1/(?<segment>.*), /${segment}
```

The service receives

```http
GET /users/15
```

without any changes to the mobile app.

Another example:

Client

```http
POST /users
```

Gateway adds

```text
X-API-Version: 2
```

before forwarding.

```java
.filters(f ->
    f.addRequestHeader(
        "X-API-Version",
        "2"))
```

The service automatically receives

```http
POST /users

X-API-Version: 2
```

---

# 7. Response Transformation

Suppose every response should contain

```http
X-Gateway-Version
```

Gateway adds

```http
HTTP/1.1 200 OK

X-Gateway-Version: 1.3
```

Implementation

```java
@Component
public class ResponseHeaderFilter
        implements GlobalFilter {

    @Override
    public Mono<Void> filter(
            ServerWebExchange exchange,
            GatewayFilterChain chain) {

        return chain.filter(exchange)
                .then(Mono.fromRunnable(() ->
                        exchange.getResponse()
                                .getHeaders()
                                .add(
                                        "X-Gateway-Version",
                                        "1.3")));
    }
}
```

The services know nothing about this header.

---

# Putting Everything Together

Imagine the client calls:

```http
GET /dashboard
Authorization: Bearer xxx
```

The request flows like this:

```text
                     Client
                        │
                        ▼
          Spring Security (Authentication)
             ✓ Validate JWT
             ✓ Create Authentication
                        │
                        ▼
        Global Logging Filter
             ✓ Log request
             ✓ Start timer
                        │
                        ▼
        Rate Limiter Filter
             ✓ Check request quota
                        │
                        ▼
        Request Transformation
             ✓ Rewrite path
             ✓ Add X-Correlation-ID
             ✓ Add X-API-Version
                        │
                        ▼
        Aggregation Controller
             ├── User Service
             ├── Order Service
             └── Product Service
                        │
                        ▼
        Response Transformation
             ✓ Add response headers
             ✓ Log response time
                        │
                        ▼
                     Client
```

## One important architectural note

There is one thing in the previous list I'd classify a bit differently in a production system:

- **Authentication, routing, logging, rate limiting, and request/response transformation** are classic API Gateway responsibilities.
- **Simple aggregation** is acceptable in the gateway when it's just combining a few service responses with little or no business logic.
- **Complex aggregation** (business rules, conditional workflows, retries, caching, data enrichment, etc.) is often moved into a dedicated **Backend-for-Frontend (BFF)** or **Aggregator Service** to keep the gateway focused on infrastructure concerns.

This distinction becomes important as systems grow, because gateways that accumulate business logic can become difficult to maintain. For learning and for smaller systems, however, implementing simple aggregation in Spring Cloud Gateway is a perfectly good approach.

---

## The Kubernetes-Native Approach

### 1. **API Gateway as a Kubernetes Service**

Your API Gateway becomes just another microservice in your cluster:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
        - name: gateway
          image: your-api-gateway:latest
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
spec:
  selector:
    app: api-gateway
  ports:
    - port: 80
      targetPort: 8080
  type: LoadBalancer # or NodePort, ClusterIP
```

### 2. **How Gateway Discovers Services**

Instead of Eureka, your API Gateway can use:

#### **Option A: Kubernetes DNS (Most Common)**

```yaml
# In your gateway configuration
spring:
  cloud:
    gateway:
      routes:
        - id: order-service
          uri: http://order-service:8080 # Kubernetes service DNS
          predicates:
            - Path=/orders/**
        - id: product-service
          uri: http://product-service:8080
          predicates:
            - Path=/products/**
```

#### **Option B: Spring Cloud Kubernetes**

Add dependency:

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-kubernetes-client</artifactId>
</dependency>
```

Then use service discovery:

```yaml
spring:
  cloud:
    gateway:
      discovery:
        locator:
          enabled: true
          lower-case-service-id: true
```

### 3. **Advanced Gateway Patterns**

#### **Ingress Controller (Recommended for Production)**

Instead of exposing your API Gateway as a LoadBalancer, use an Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: api.yourdomain.com
      http:
        paths:
          - path: /orders
            pathType: Prefix
            backend:
              service:
                name: api-gateway
                port:
                  number: 80
```

#### **Service Mesh (Istio/Linkerd)**

For advanced routing, circuit breaking, and observability:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: gateway-routes
spec:
  hosts:
    - api-gateway
  http:
    - match:
        - uri:
            prefix: /orders
      route:
        - destination:
            host: order-service
            port:
              number: 8080
          weight: 90
        - destination:
            host: order-service-v2
            port:
              number: 8080
          weight: 10 # Canary deployment
```

## Comparison: Eureka vs Kubernetes

| Aspect            | Eureka               | Kubernetes Services             |
| ----------------- | -------------------- | ------------------------------- |
| Service Discovery | Client-side (Ribbon) | DNS-based (kube-dns)            |
| Load Balancing    | Client-side          | Kube-proxy (iptables/IPVS)      |
| Health Checks     | Heartbeat            | Readiness/Liveness Probes       |
| Configuration     | Spring Cloud Config  | ConfigMaps/Secrets              |
| Scaling           | Manual               | HPA (Horizontal Pod Autoscaler) |

## Best Practices

### 1. **Use Readiness Probes**

```yaml
readinessProbe:
  httpGet:
    path: /actuator/health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

### 2. **Implement Circuit Breaking**

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: order-service
          uri: http://order-service:8080
          predicates:
            - Path=/orders/**
          filters:
            - name: CircuitBreaker
              args:
                name: orderService
                fallbackUri: forward:/fallback/orders
```

### 3. **Centralize Configuration**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
data:
  application.yml: |
    spring:
      cloud:
        gateway:
          routes:
            - id: order-service
              uri: http://order-service:8080
              predicates:
                - Path=/orders/**
```

### 4. **Externalize with Helm**

```yaml
# values.yaml
gateway:
  routes:
    - id: order-service
      uri: http://order-service:8080
      path: /orders/**
```

## When to Use What?

- **Simple Gateway**: Kubernetes Services + Ingress
- **Advanced Routing**: Spring Cloud Gateway + Kubernetes Discovery
- **Service Mesh**: Istio/Consul + Kubernetes (for complex traffic management)
- **Hybrid**: Spring Cloud Gateway with Kubernetes service discovery for internal routing

## Sample Complete Setup

```yaml
# Complete gateway deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
        - name: gateway
          image: your-registry/gateway:latest
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_CLOUD_KUBERNETES_ENABLED
              value: "true"
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
spec:
  selector:
    app: api-gateway
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
```

The key insight: **Kubernetes replaces Eureka's service discovery, while the API Gateway remains your entry point**. You don't need Eureka at all in a Kubernetes environment - just use Kubernetes native features!
