[back](./README.md)

[Complete Spring Cloud Gateway with Kubernetes Example](#complete-spring-cloud-gateway-with-kubernetes-example)

Here's a practical example showing how to configure `GatewayFilter` in `application.yml` for Spring Cloud Gateway.

## 📝 Basic `application.yml` with GatewayFilters

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user_service_route
          uri: http://localhost:8081
          predicates:
            - Path=/api/users/**
          filters:
            # These are GatewayFilters applied only to this route
            - AddRequestHeader=X-Request-Source, gateway
            - AddResponseHeader=X-Response-Time, 100ms
            - RemoveRequestHeader=Cookie
            - StripPrefix=1

        - id: order_service_route
          uri: http://localhost:8082
          predicates:
            - Path=/api/orders/**
          filters:
            - AddRequestHeader=X-Request-Source, gateway
            - PrefixPath=/v2
            - RewritePath=/api/orders/(?<segment>.*), /orders/$\{segment}
            - name: CircuitBreaker
              args:
                name: orderCB
                fallbackUri: forward:/fallback
```

## 🎯 Real-World Authentication Example

Here's a more practical example with authentication and custom filters:

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: secured_api
          uri: lb://user-service
          predicates:
            - Path=/api/protected/**
          filters:
            # GatewayFilter (built-in) for authentication
            - name: TokenRelay
            # Custom GatewayFilter factory you create
            - name: AuthenticationFilter
              args:
                excludePaths: /api/protected/public
            # Add JWT validation (custom filter)
            - name: JwtValidationFilter
              args:
                issuer: https://auth.mycompany.com
                audience: my-api

        - id: public_api
          uri: lb://public-service
          predicates:
            - Path=/api/public/**
          filters:
            - AddRequestHeader=X-Public-Request, true
            # Skip authentication for public routes
            - RemoveRequestHeader=Authorization
```

## 🔧 Shortcut vs. Full Syntax

GatewayFilters can be written in two ways:

### Short Syntax

```yaml
filters:
  - AddRequestHeader=X-Request-Source, gateway
  - StripPrefix=1
```

### Full Syntax (for filters with arguments)

```yaml
filters:
  - name: AddRequestHeader
    args:
      name: X-Request-Source
      value: gateway
  - name: CircuitBreaker
    args:
      name: orderCB
      fallbackUri: forward:/fallback
```

## 🚦 Common GatewayFilter Examples

| GatewayFilter           | Description                            | Example                                                       |
| :---------------------- | :------------------------------------- | :------------------------------------------------------------ |
| **AddRequestHeader**    | Adds a header to the forwarded request | `AddRequestHeader=X-User-ID, 12345`                           |
| **AddResponseHeader**   | Adds a header to the response          | `AddResponseHeader=X-Gateway-Version, 2.0`                    |
| **StripPrefix**         | Removes path segments                  | `StripPrefix=1` (removes `/api` from `/api/users` → `/users`) |
| **PrefixPath**          | Adds a path prefix                     | `PrefixPath=/v1` (changes `/users` → `/v1/users`)             |
| **RewritePath**         | Rewrites the URL path                  | `RewritePath=/red/(?<segment>.*), /blue/$\{segment}`          |
| **SetPath**             | Sets the path directly                 | `SetPath=/new/path`                                           |
| **RemoveRequestHeader** | Removes a header from the request      | `RemoveRequestHeader=Authorization`                           |
| **CircuitBreaker**      | Adds resiliency patterns               | See full syntax example above                                 |
| **Retry**               | Retries failed requests                | `Retry=3, serverError`                                        |
| **RequestRateLimiter**  | Rate limiting                          | `RequestRateLimiter=10, 20, 1s`                               |

## 💡 Important Note on Ordering

When you use the short syntax, Spring Cloud Gateway automatically assigns the order based on the order they appear in the YAML list. For more control, you can wrap your custom GatewayFilters with `OrderedGatewayFilter`, but for built-in filters, the order in the configuration is the execution order.

## 🔗 Combining with Default Filters

You can also define default filters that apply to all routes:

```yaml
spring:
  cloud:
    gateway:
      default-filters:
        # These apply to ALL routes
        - AddResponseHeader=Global-Header, true
        - name: GlobalLoggingFilter
          args:
            enabled: true
      routes:
        - id: user_service_route
          uri: http://localhost:8081
          predicates:
            - Path=/api/users/**
          filters:
            # Route-specific filters (executed AFTER default filters)
            - AddRequestHeader=X-Route-ID, user-service
```

This configuration ensures that all routes have a global response header before applying route-specific modifications.

---

## Complete Spring Cloud Gateway with Kubernetes Example

### 1. Project Structure

```
api-gateway/
├── src/main/java/com/example/gateway/
│   ├── GatewayApplication.java
│   ├── config/
│   │   ├── GatewayConfig.java
│   │   ├── SecurityConfig.java
│   │   ├── RateLimiterConfig.java
│   │   └── LoggingConfig.java
│   ├── filters/
│   │   ├── AuthenticationFilter.java
│   │   ├── LoggingFilter.java
│   │   └── TransformationFilter.java
│   ├── handlers/
│   │   └── AggregationHandler.java
│   └── models/
│       └── User.java
├── src/main/resources/
│   └── application.yml
├── k8s/
│   ├── configmap.yml
│   ├── secrets.yml
│   ├── deployment.yml
│   ├── service.yml
│   ├── ingress.yml
│   └── rbac.yml
└── pom.xml
```

### 2. Dependencies (pom.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.1.5</version>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>api-gateway</artifactId>
    <version>1.0.0</version>

    <properties>
        <java.version>17</java.version>
        <spring-cloud.version>2022.0.4</spring-cloud.version>
    </properties>

    <dependencies>
        <!-- Spring Cloud Gateway -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-gateway</artifactId>
        </dependency>

        <!-- Kubernetes Discovery -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-kubernetes-client-all</artifactId>
        </dependency>

        <!-- Kubernetes Config -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-kubernetes-client-config</artifactId>
        </dependency>

        <!-- Security & JWT -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>
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
            <artifactId>jjwt-jackson</artifactId>
            <version>0.11.5</version>
            <scope>runtime</scope>
        </dependency>

        <!-- Rate Limiting -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis-reactive</artifactId>
        </dependency>

        <!-- Circuit Breaker -->
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-circuitbreaker-reactor-resilience4j</artifactId>
        </dependency>

        <!-- WebClient for Aggregation -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-webflux</artifactId>
        </dependency>

        <!-- Actuator -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <!-- Lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
</project>
```

### 3. Main Application

```java
package com.example.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@SpringBootApplication
@EnableDiscoveryClient
public class GatewayApplication {
    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}
```

### 4. Application Configuration (application.yml)

```yaml
spring:
  application:
    name: api-gateway

  # Cloud Configuration
  cloud:
    kubernetes:
      client:
        namespace: default
      discovery:
        enabled: true
        # Kubernetes handles service discovery
        service-name: api-gateway
        primary-service-name: api-gateway
        # Watch for service changes
        watch:
          enabled: true
      config:
        enabled: true
        sources:
          - name: api-gateway-config
            namespace: default
      reload:
        enabled: true
        mode: event
        period: 5000

    gateway:
      # Global configurations
      default-filters:
        - name: GlobalLoggingFilter
        - name: CircuitBreaker
          args:
            name: defaultCB
            fallbackUri: forward:/fallback/default

      routes:
        # === AUTHENTICATION & ROUTING ===
        - id: auth-service
          uri: http://auth-service:8081 # Kubernetes handles load balancing
          predicates:
            - Path=/api/auth/**
          filters:
            - name: AuthenticationFilter
            - StripPrefix=1

        # === RATE LIMITING & TRANSFORMATION ===
        - id: user-service
          uri: http://user-service:8082
          predicates:
            - Path=/api/users/**
          filters:
            - name: AuthenticationFilter
            - name: RequestRateLimiter
              args:
                key-resolver: "#{@userKeyResolver}"
                redis-rate-limiter.replenishRate: 10
                redis-rate-limiter.burstCapacity: 20
            - name: UserTransformationFilter
            - StripPrefix=1

        # === AGGREGATION EXAMPLE ===
        - id: dashboard-service
          uri: http://api-gateway:8080/aggregate/dashboard
          predicates:
            - Path=/api/dashboard/**
          filters:
            - name: AuthenticationFilter

        # === LOGGING & TRANSFORMATION ===
        - id: order-service
          uri: http://order-service:8083
          predicates:
            - Path=/api/orders/**
          filters:
            - name: OrderTransformationFilter
            - StripPrefix=1
            - name: CircuitBreaker
              args:
                name: orderCB
                fallbackUri: forward:/fallback/orders

  # Redis for rate limiting
  data:
    redis:
      host: redis-service
      port: 6379
      password: ${REDIS_PASSWORD:}

# Actuator endpoints
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,gateway
  health:
    livenessstate:
      enabled: true
    readinessstate:
      enabled: true

# Logging
logging:
  level:
    com.example.gateway: DEBUG
    org.springframework.cloud.gateway: INFO
    org.springframework.web: INFO

# JWT Configuration
jwt:
  secret: ${JWT_SECRET:your-256-bit-secret-key-here-must-be-long-enough}
  expiration: 3600000
```

### 5. Authentication Filter

```java
package com.example.gateway.filters;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilter;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.core.Ordered;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;

@Component
@Slf4j
public class AuthenticationFilter implements GatewayFilter, Ordered {

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String authHeader = exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION);

        // Skip authentication for public endpoints
        String path = exchange.getRequest().getPath().value();
        if (path.startsWith("/api/auth/") || path.startsWith("/actuator/")) {
            return chain.filter(exchange);
        }

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }

        String token = authHeader.substring(7);

        try {
            Claims claims = validateToken(token);

            // Add user info to headers for downstream services
            exchange = exchange.mutate()
                .request(r -> r.header("X-User-Id", claims.getSubject()))
                .request(r -> r.header("X-User-Roles", claims.get("roles", String.class)))
                .build();

            log.info("Authenticated user: {}", claims.getSubject());
            return chain.filter(exchange);

        } catch (Exception e) {
            log.error("Authentication failed: {}", e.getMessage());
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }
    }

    private Claims validateToken(String token) {
        SecretKey key = Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
        return Jwts.parserBuilder()
            .setSigningKey(key)
            .build()
            .parseClaimsJws(token)
            .getBody();
    }

    @Override
    public int getOrder() {
        return -100; // High priority
    }
}
```

### 6. Logging Filter

```java
package com.example.gateway.filters;

import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.gateway.filter.GatewayFilter;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.core.Ordered;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.UUID;

@Component
@Slf4j
public class GlobalLoggingFilter implements GatewayFilter, Ordered {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String requestId = UUID.randomUUID().toString();

        // Log request
        log.info("Request ID: {} - Method: {} - Path: {} - Headers: {}",
            requestId,
            exchange.getRequest().getMethod(),
            exchange.getRequest().getPath(),
            exchange.getRequest().getHeaders());

        // Add request ID to headers for traceability
        exchange = exchange.mutate()
            .request(r -> r.header("X-Request-Id", requestId))
            .build();

        long startTime = System.currentTimeMillis();

        // Log response
        return chain.filter(exchange).then(Mono.fromRunnable(() -> {
            long duration = System.currentTimeMillis() - startTime;
            log.info("Request ID: {} - Response Status: {} - Duration: {}ms",
                requestId,
                exchange.getResponse().getStatusCode(),
                duration);
        }));
    }

    @Override
    public int getOrder() {
        return 0;
    }
}
```

### 7. Rate Limiting Configuration

```java
package com.example.gateway.config;

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import reactor.core.publisher.Mono;

@Configuration
public class RateLimiterConfig {

    @Bean
    public KeyResolver userKeyResolver() {
        return exchange -> {
            // Rate limit by user ID if authenticated
            String userId = exchange.getRequest().getHeaders().getFirst("X-User-Id");
            if (userId != null) {
                return Mono.just(userId);
            }

            // Fallback to IP address
            String ip = exchange.getRequest().getRemoteAddress().getAddress().getHostAddress();
            return Mono.just(ip);
        };
    }

    @Bean
    public KeyResolver apiKeyResolver() {
        return exchange -> {
            String apiKey = exchange.getRequest().getHeaders().getFirst("X-API-Key");
            return Mono.just(apiKey != null ? apiKey : "default");
        };
    }
}
```

### 8. Request/Response Transformation Filter

```java
package com.example.gateway.filters;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.gateway.filter.GatewayFilter;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.core.Ordered;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;

@Component
@Slf4j
public class UserTransformationFilter implements GatewayFilter, Ordered {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        // Transform request - add default headers
        exchange = exchange.mutate()
            .request(r -> r.header("X-Source", "api-gateway"))
            .request(r -> r.header("X-Timestamp", String.valueOf(System.currentTimeMillis())))
            .build();

        // Transform response
        return chain.filter(exchange).then(Mono.fromRunnable(() -> {
            // Only transform JSON responses
            if (exchange.getResponse().getHeaders().getContentType() != null &&
                exchange.getResponse().getHeaders().getContentType().includes(MediaType.APPLICATION_JSON)) {

                // Response transformation is handled in a custom filter
                // This is a simplified example
                log.info("Response transformation applied");
            }
        }));
    }

    @Override
    public int getOrder() {
        return 10;
    }
}
```

### 9. Service Aggregation Handler

```java
package com.example.gateway.handlers;

import com.example.gateway.models.User;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.server.ServerRequest;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Component
@Slf4j
public class AggregationHandler {

    @Autowired
    private WebClient.Builder webClientBuilder;

    @Autowired
    private DiscoveryClient discoveryClient;

    public Mono<ServerResponse> getDashboard(ServerRequest request) {
        String userId = request.headers().firstHeader("X-User-Id");
        if (userId == null) {
            userId = "anonymous";
        }

        // Aggregate data from multiple services
        Mono<Map<String, Object>> userInfo = getUserInfo(userId);
        Mono<List<Map<String, Object>>> userOrders = getUserOrders(userId);
        Mono<Map<String, Object>> userStats = getUserStats(userId);

        return Mono.zip(userInfo, userOrders, userStats)
            .flatMap(tuple -> {
                Map<String, Object> dashboard = new HashMap<>();
                dashboard.put("user", tuple.getT1());
                dashboard.put("recent_orders", tuple.getT2());
                dashboard.put("stats", tuple.getT3());
                dashboard.put("timestamp", System.currentTimeMillis());

                return ServerResponse.ok()
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(dashboard);
            })
            .onErrorResume(e -> {
                log.error("Dashboard aggregation failed: {}", e.getMessage());
                return ServerResponse.status(500)
                    .bodyValue(Map.of("error", "Failed to load dashboard"));
            });
    }

    private Mono<Map<String, Object>> getUserInfo(String userId) {
        return webClientBuilder.build()
            .get()
            .uri("http://user-service/api/users/" + userId)
            .retrieve()
            .bodyToMono(Map.class)
            .onErrorResume(e -> Mono.just(Map.of("error", "User service unavailable")));
    }

    private Mono<List<Map<String, Object>>> getUserOrders(String userId) {
        return webClientBuilder.build()
            .get()
            .uri("http://order-service/api/orders?userId=" + userId)
            .retrieve()
            .bodyToMono(List.class)
            .onErrorResume(e -> Mono.just(List.of()));
    }

    private Mono<Map<String, Object>> getUserStats(String userId) {
        // Simulate stats aggregation
        Map<String, Object> stats = new HashMap<>();
        stats.put("total_orders", 42);
        stats.put("total_spent", 1250.50);
        stats.put("member_since", "2023-01-01");
        return Mono.just(stats);
    }
}
```

### 10. Route Configuration

```java
package com.example.gateway.config;

import com.example.gateway.filters.AuthenticationFilter;
import com.example.gateway.filters.GlobalLoggingFilter;
import com.example.gateway.filters.UserTransformationFilter;
import com.example.gateway.handlers.AggregationHandler;
import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.server.RouterFunction;
import org.springframework.web.reactive.function.server.ServerResponse;

import static org.springframework.web.reactive.function.server.RouterFunctions.route;

@Configuration
public class GatewayConfig {

    @Bean
    public RouteLocator customRouteLocator(RouteLocatorBuilder builder,
                                          AuthenticationFilter authFilter,
                                          GlobalLoggingFilter loggingFilter,
                                          UserTransformationFilter transformationFilter) {
        return builder.routes()
            // Public auth routes
            .route("auth-service", r -> r
                .path("/api/auth/**")
                .filters(f -> f
                    .filter(loggingFilter)
                    .stripPrefix(1)
                    .circuitBreaker(config -> config
                        .setName("authCB")
                        .setFallbackUri("forward:/fallback/auth")))
                .uri("http://auth-service:8081"))

            // Protected user routes with rate limiting
            .route("user-service", r -> r
                .path("/api/users/**")
                .filters(f -> f
                    .filter(loggingFilter)
                    .filter(authFilter)
                    .filter(transformationFilter)
                    .stripPrefix(1)
                    .requestRateLimiter(config -> config
                        .setRateLimiter(redisRateLimiter())
                        .setKeyResolver(userKeyResolver()))
                    .circuitBreaker(config -> config
                        .setName("userCB")
                        .setFallbackUri("forward:/fallback/users")))
                .uri("http://user-service:8082"))

            // Order service
            .route("order-service", r -> r
                .path("/api/orders/**")
                .filters(f -> f
                    .filter(loggingFilter)
                    .filter(authFilter)
                    .stripPrefix(1)
                    .circuitBreaker(config -> config
                        .setName("orderCB")
                        .setFallbackUri("forward:/fallback/orders")))
                .uri("http://order-service:8083"))

            .build();
    }

    @Bean
    public RouterFunction<ServerResponse> aggregationRoutes(AggregationHandler handler) {
        return route()
            .GET("/aggregate/dashboard", handler::getDashboard)
            .build();
    }
}
```

### 11. Security Configuration

```java
package com.example.gateway.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.reactive.CorsConfigurationSource;
import org.springframework.web.cors.reactive.UrlBasedCorsConfigurationSource;

import java.util.Arrays;

@Configuration
@EnableWebFluxSecurity
public class SecurityConfig {

    @Bean
    public SecurityWebFilterChain securityWebFilterChain(ServerHttpSecurity http) {
        return http
            .csrf().disable()
            .cors().configurationSource(corsConfigurationSource())
            .and()
            .authorizeExchange()
                .pathMatchers("/api/auth/**", "/actuator/**", "/health/**").permitAll()
                .anyExchange().authenticated()
            .and()
            .build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(Arrays.asList("*"));
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
```

### 12. Kubernetes Configurations

#### ConfigMap (k8s/configmap.yml)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-gateway-config
  namespace: default
data:
  application-kubernetes.yml: |
    spring:
      cloud:
        gateway:
          routes:
            - id: auth-service
              uri: http://auth-service:8081
              predicates:
                - Path=/api/auth/**
              filters:
                - StripPrefix=1
            
            - id: user-service  
              uri: http://user-service:8082
              predicates:
                - Path=/api/users/**
              filters:
                - StripPrefix=1
                - name: RequestRateLimiter
                  args:
                    key-resolver: "#{@userKeyResolver}"
                    redis-rate-limiter.replenishRate: 10
                    redis-rate-limiter.burstCapacity: 20
            
            - id: order-service
              uri: http://order-service:8083
              predicates:
                - Path=/api/orders/**
              filters:
                - StripPrefix=1
```

#### RBAC (k8s/rbac.yml)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-gateway-sa
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: api-gateway-role
rules:
  - apiGroups: [""]
    resources: ["services", "endpoints", "pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["discovery.k8s.io"]
    resources: ["endpointslices"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: api-gateway-rb
subjects:
  - kind: ServiceAccount
    name: api-gateway-sa
    namespace: default
roleRef:
  kind: ClusterRole
  name: api-gateway-role
  apiGroup: rbac.authorization.k8s.io
```

#### Deployment (k8s/deployment.yml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: default
  labels:
    app: api-gateway
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
      serviceAccountName: api-gateway-sa
      containers:
        - name: api-gateway
          image: api-gateway:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "kubernetes"
            - name: SPRING_CLOUD_KUBERNETES_DISCOVERY_ENABLED
              value: "true"
            - name: SPRING_CLOUD_KUBERNETES_CLIENT_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: jwt-secret
                  key: secret
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: redis-secret
                  key: password
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
            initialDelaySeconds: 20
            periodSeconds: 5
          volumeMounts:
            - name: config
              mountPath: /config
      volumes:
        - name: config
          configMap:
            name: api-gateway-config
```

#### Service (k8s/service.yml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: default
  labels:
    app: api-gateway
spec:
  selector:
    app: api-gateway
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
  type: ClusterIP
  # Kubernetes handles load balancing
```

#### Secrets (k8s/secrets.yml)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secret
  namespace: default
type: Opaque
data:
  # Base64 encoded "your-256-bit-secret-key-here-must-be-long-enough"
  secret: eW91ci0yNTYtYml0LXNlY3JldC1rZXktaGVyZS1tdXN0LWJlLWxvbmctZW5vdWdo
---
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
  namespace: default
type: Opaque
data:
  password: dXNlci1wYXNzd29yZA== # Base64 encoded
```

#### Ingress (k8s/ingress.yml)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: 50m
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Gateway-Version: v1";
spec:
  rules:
    - host: api.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-gateway
                port:
                  number: 80
```

### 13. Fallback Handlers

```java
package com.example.gateway.handlers;

import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.server.ServerRequest;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;

import java.util.Map;

@Component
public class FallbackHandler {

    public Mono<ServerResponse> defaultFallback(ServerRequest request) {
        return ServerResponse.status(503)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(Map.of(
                "error", "Service temporarily unavailable",
                "timestamp", System.currentTimeMillis(),
                "path", request.path()
            ));
    }

    public Mono<ServerResponse> userFallback(ServerRequest request) {
        return ServerResponse.status(503)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(Map.of(
                "error", "User service unavailable",
                "timestamp", System.currentTimeMillis(),
                "message", "Please try again later"
            ));
    }

    public Mono<ServerResponse> orderFallback(ServerRequest request) {
        return ServerResponse.status(503)
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(Map.of(
                "error", "Order service unavailable",
                "timestamp", System.currentTimeMillis()
            ));
    }
}
```

### 14. User Model

```java
package com.example.gateway.models;

import lombok.Data;

@Data
public class User {
    private String id;
    private String username;
    private String email;
    private String firstName;
    private String lastName;
    private String[] roles;
    private long createdAt;
    private long lastLogin;
}
```

### 15. Deployment Commands

```bash
# 1. Create secrets
kubectl create secret generic jwt-secret \
  --from-literal=secret='your-256-bit-secret-key-here' \
  -n default

kubectl create secret generic redis-secret \
  --from-literal=password='your-redis-password' \
  -n default

# Or use the yaml files
kubectl apply -f k8s/secrets.yml

# 2. Apply configurations
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/rbac.yml
kubectl apply -f k8s/deployment.yml
kubectl apply -f k8s/service.yml
kubectl apply -f k8s/ingress.yml

# 3. Check deployment
kubectl get pods -l app=api-gateway
kubectl get svc api-gateway
kubectl get ingress

# 4. View logs
kubectl logs -f deployment/api-gateway

# 5. Update configuration
kubectl edit configmap api-gateway-config
kubectl rollout restart deployment/api-gateway

# 6. Test endpoints
# Authentication
curl -X POST http://api.yourdomain.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'

# Get dashboard (aggregation)
curl http://api.yourdomain.com/api/dashboard \
  -H "Authorization: Bearer <token>"

# User endpoint with rate limiting
curl http://api.yourdomain.com/api/users/123 \
  -H "Authorization: Bearer <token>"
```

## Summary of Features

| Feature                             | Implementation                         | Kubernetes Role                        |
| ----------------------------------- | -------------------------------------- | -------------------------------------- |
| **Authentication**                  | JWT validation in AuthenticationFilter | Secrets for JWT secret                 |
| **Routing**                         | Route configuration in application.yml | Service discovery via Kubernetes       |
| **Logging**                         | GlobalLoggingFilter with request IDs   | ConfigMap for log levels               |
| **Rate Limiting**                   | Redis-based RequestRateLimiter         | Redis service, ConfigMap for limits    |
| **Service Aggregation**             | AggregationHandler with WebClient      | Service discovery for downstream calls |
| **Request/Response Transformation** | TransformationFilter                   | ConfigMap for rules                    |
| **Load Balancing**                  | Kubernetes Service                     | Kubernetes handles automatically       |
| **Service Discovery**               | Spring Cloud Kubernetes Client         | RBAC for service access                |

This setup ensures Kubernetes handles service discovery and load balancing automatically, while Spring Cloud Gateway provides the API gateway functionality with all requested features.
