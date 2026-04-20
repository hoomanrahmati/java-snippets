### starter‑cheat‑sheet

[back](../README.md)

Below is a practical “starter‑cheat‑sheet” that covers the most frequently used Spring Boot starter artifacts.  
For each one I’ve included the full Maven/Gradle coordinate (group : artifact) and a one‑sentence description of what it brings to the project.

| Category                      | Starter                                              | Short description                                                                                     |
| ----------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **Core**                      | `spring-boot-starter`                                | Pulls in the basic Spring Boot libraries and auto‑configuration support.                              |
|                               | `spring-boot-starter-actuator`                       | Adds production‑ready endpoints (health, metrics, env, etc.) and management features.                 |
|                               | `spring-boot-starter-logging`                        | Provides Logback + Log4j2 integration (configurable via `logback.xml` or `application.yml`).          |
|                               | `spring-boot-starter-test`                           | Includes JUnit 5, AssertJ, Hamcrest, Mockito, and Spring Test utilities for unit & integration tests. |
|                               | `spring-boot-starter-validation`                     | Adds Bean Validation (JSR‑380) via Hibernate Validator; useful for request/command validation.        |
|                               | `spring-boot-starter-aop`                            | Enables Spring AOP and AspectJ for cross‑cutting concerns (logging, transaction, etc.).               |
|                               | `spring-boot-starter-cache`                          | Provides a simple cache abstraction backed by Spring’s `CacheManager`.                                |
|                               | `spring-boot-starter-security`                       | Adds Spring Security core with auto‑config for authentication/authorization, CSRF, etc.               |
|                               | `spring-boot-starter-jdbc`                           | Pulls in Spring JDBC and a `DataSource` auto‑configuration.                                           |
|                               | `spring-boot-starter-batch`                          | Adds Spring Batch for large‑scale batch processing.                                                   |
| **Web**                       | `spring-boot-starter-web`                            | Starter for building REST/HTTP services with Spring MVC, Tomcat (embedded), Jackson, and validation.  |
|                               | `spring-boot-starter-webflux`                        | Reactive web stack (WebFlux) using Netty or Tomcat, RSocket, and Reactor.                             |
|                               | `spring-boot-starter-thymeleaf`                      | Adds the Thymeleaf templating engine for server‑side HTML rendering.                                  |
|                               | `spring-boot-starter-freemarker`                     | Includes FreeMarker templates for dynamic HTML.                                                       |
|                               | `spring-boot-starter-jetty`                          | Replaces Tomcat with Jetty as the embedded servlet container.                                         |
|                               | `spring-boot-starter-undertow`                       | Replaces Tomcat with Undertow (high‑performance async servlet container).                             |
|                               | `spring-boot-starter-websocket`                      | Enables WebSocket support with Spring’s `@EnableWebSocket` and STOMP messaging.                       |
|                               | `spring-boot-starter-graphql`                        | Provides Spring GraphQL with `graphql-spring-boot-starter` integration.                               |
|                               | `spring-boot-starter-openfeign`                      | Declarative REST client (OpenFeign) for calling external services.                                    |
|                               | `spring-boot-starter-graphql-spring-boot-starter`    | Another popular GraphQL starter that bundles `graphql-java` and `graphql-java-tools`.                 |
| **Data**                      | `spring-boot-starter-data-jpa`                       | Adds Spring Data JPA + Hibernate for ORM with a `JpaRepository` abstraction.                          |
|                               | `spring-boot-starter-data-mongodb`                   | Pulls in Spring Data MongoDB for document‑store access.                                               |
|                               | `spring-boot-starter-data-redis`                     | Spring Data Redis with connection pooling and template APIs.                                          |
|                               | `spring-boot-starter-data-neo4j`                     | Spring Data Neo4j integration for graph databases.                                                    |
|                               | `spring-boot-starter-data-elasticsearch`             | Adds Spring Data Elasticsearch for full‑text search.                                                  |
|                               | `spring-boot-starter-data-rest`                      | Exposes Spring Data repositories as REST endpoints automatically.                                     |
|                               | `spring-boot-starter-data-ldap`                      | Provides LDAP integration via Spring Data LDAP.                                                       |
| **Messaging**                 | `spring-boot-starter-amqp`                           | Spring AMQP with RabbitMQ support (Template, Listener containers).                                    |
|                               | `spring-boot-starter-kafka`                          | Spring for Apache Kafka (producer & consumer APIs).                                                   |
|                               | `spring-boot-starter-aws-messaging`                  | Simplifies Amazon SQS/SNS integration.                                                                |
|                               | `spring-boot-starter-spring-cloud-stream`            | Abstract messaging binder (Rabbit, Kafka, etc.) for microservice patterns.                            |
| **Cloud / Cloud‑Native**      | `spring-cloud-starter-netflix-eureka-client`         | Registers the service with Eureka discovery server.                                                   |
|                               | `spring-cloud-starter-netflix-eureka-server`         | Stand‑alone Eureka server.                                                                            |
|                               | `spring-cloud-starter-config`                        | Connects to a Spring Cloud Config Server for centralized property management.                         |
|                               | `spring-cloud-starter-openfeign`                     | Feign integration for declarative REST clients (often paired with Eureka).                            |
|                               | `spring-cloud-starter-gateway`                       | Reactive API gateway based on Spring WebFlux.                                                         |
|                               | `spring-cloud-starter-sleuth`                        | Distributed tracing support with Zipkin/Jaeger.                                                       |
|                               | `spring-cloud-starter-zipkin`                        | Exports traces to Zipkin.                                                                             |
|                               | `spring-cloud-starter-bootiful-azure`                | Azure service integrations (Key Vault, Service Bus, etc.).                                            |
|                               | `spring-cloud-starter-consul-discovery`              | Service registration with HashiCorp Consul.                                                           |
|                               | `spring-cloud-starter-bus`                           | Messaging bus for refreshing configuration across nodes.                                              |
|                               | `spring-cloud-starter-stream-rabbit`                 | Spring Cloud Stream binder for RabbitMQ.                                                              |
|                               | `spring-cloud-starter-stream-kafka`                  | Spring Cloud Stream binder for Kafka.                                                                 |
| **Reactive / Functional**     | `spring-boot-starter-reactor-netty`                  | Netty runtime for reactive applications.                                                              |
|                               | `spring-boot-starter-reactor-test`                   | Test utilities for Project Reactor.                                                                   |
| **Monitoring & Metrics**      | `spring-boot-starter-micrometer-registry-prometheus` | Exposes Prometheus metrics via Micrometer.                                                            |
|                               | `spring-boot-starter-graphql-spring-boot-starter`    | GraphQL support for real‑time metrics queries.                                                        |
|                               | `spring-boot-starter-logging`                        | Built‑in Logback integration (replaceable with Log4j2).                                               |
| **Utilities / Miscellaneous** | `spring-boot-starter-validation`                     | Bean Validation (JSR‑380) support.                                                                    |
|                               | `spring-boot-starter-mail`                           | JavaMailSender and email utilities.                                                                   |
|                               | `spring-boot-starter-data-rest`                      | Exposes Spring Data repositories as REST endpoints.                                                   |
|                               | `spring-boot-starter-freemarker`                     | Freemarker templating engine.                                                                         |
|                               | `spring-boot-starter-grpc`                           | Adds gRPC support via `grpc-spring-boot-starter`.                                                     |
|                               | `spring-boot-starter-jsonb`                          | JSON-B (JSR‑367) support with Eclipse Yasson.                                                         |

### How to use them

```xml
<!-- Maven example -->
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
```

```groovy
// Gradle (Groovy)
implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
```

When you add a starter, Spring Boot automatically pulls in the most common transitive dependencies and configures them via auto‑configuration classes.  
Choose the minimal set that fits your use‑case; you can always add more later.

**Tip:** Keep an eye on the version alignment. The starter artifacts are all managed by Spring Boot’s dependency management, so you only need to specify the Spring Boot parent or the `spring-boot-dependencies` BOM.
