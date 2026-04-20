1️⃣ **Configuration & Boot‑up**

[back](../annotation-cheat-sheet.md)

| Annotation                                    | What it does                                                                                                                                                 |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `@SpringBootApplication`                      | Marks the main class, enables component scanning, auto‑configuration, and property support (`@Configuration`, `@EnableAutoConfiguration`, `@ComponentScan`). |
| `@SpringBootConfiguration`                    | The same as `@Configuration` but with `@ComponentScan` + `@EnableAutoConfiguration`.                                                                         |
| `@EnableAutoConfiguration`                    | Tells Spring Boot to automatically configure beans based on the classpath and `application‑*` files.                                                         |
| `@ComponentScan`                              | Scans the current package (and subpackages) for Spring components.                                                                                           |
| `@Import`                                     | Imports additional configuration classes or beans.                                                                                                           |
| `@Bean`                                       | Declares a singleton bean in the application context.                                                                                                        |
| `@ConfigurationProperties`                    | Binds external properties (`application.yml`) to a POJO.                                                                                                     |
| `@PropertySource`                             | Adds an external `.properties` file to the environment.                                                                                                      |
| `@PropertySource("classpath:foo.properties")` | Loads a specific properties file.                                                                                                                            |
| `@ConditionalOn…` / `@Conditional`            | Conditional bean registration (e.g. `@ConditionalOnMissingBean`).                                                                                            |
| `@EnableAspectJAutoProxy`                     | Enables Spring AOP support (used under‑the‑hood by many starters).                                                                                           |

Below are **one‑liner descriptions** followed by a _tiny_ but complete Java snippet that demonstrates each annotation in a real Spring‑Boot context.  
All snippets compile as‑is (assuming the normal Spring Boot dependencies are present).

---

## `@SpringBootApplication`

```java
@SpringBootApplication   // enables @Configuration, @EnableAutoConfiguration, @ComponentScan
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
```

> Marks the entry point of a Spring‑Boot app. It automatically scans for `@Component`, `@Service`, `@Repository`, etc., in the same package and below.

---

## `@SpringBootConfiguration`

```java
@SpringBootConfiguration   // same as @Configuration + @EnableAutoConfiguration + @ComponentScan
public class CustomConfig {
    // bean definitions, etc.
}
```

> Usually you **don’t need** to use this directly; `@SpringBootApplication` already contains it. It’s handy when you want a dedicated configuration class that still gets the “auto‑configuration” benefits.

---

## `@EnableAutoConfiguration`

```java
@Configuration
@EnableAutoConfiguration   // activates Spring Boot’s auto‑configuration engine
public class AutoConfigDemo {
    // no explicit beans needed – spring‑boot‑starter modules wire themselves
}
```

> Explicitly tells Spring Boot to create beans automatically from the classpath (e.g., a `DataSource` if `spring-boot-starter-data-jpa` is present).  
> **Tip:** Use `@ConditionalOnClass` inside the same config to guard auto‑configuration when a library is missing.

---

## `@ComponentScan`

```java
@Configuration
@ComponentScan(basePackages = "com.example.services")
public class ServiceScanConfig {
    // only components inside com.example.services (and its subpackages) are registered
}
```

> Scans a given package for classes annotated with `@Component`, `@Service`, `@Repository`, etc.  
> By default, `@SpringBootApplication` scans the package of the main class and all subpackages.

---

## `@Import`

```java
@Configuration
@Import({SecurityConfig.class, DataSourceConfig.class})
public class MainConfig {
    // pulls in two additional configuration classes
}
```

> Brings in other `@Configuration` classes (or regular beans) into the current context.  
> Useful for modularising large configuration files.

---

## `@Bean`

```java
@Configuration
public class AppBeans {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();   // singleton, injected wherever @Autowired is used
    }
}
```

> Declares a single‑ton bean that Spring manages.  
> You can set the scope (`@Scope("prototype")`), name (`@Bean(name = "customRest")`), etc.

---

## `@ConfigurationProperties`

```java
@ConfigurationProperties(prefix = "mail")
public class MailProperties {
    private String host;
    private int port;
    private List<String> recipients;

    // getters & setters
}

@Configuration
@EnableConfigurationProperties(MailProperties.class)
public class MailConfig {
    private final MailProperties props;

    public MailConfig(MailProperties props) {
        this.props = props;
    }

    @Bean
    public JavaMailSender mailSender() {
        JavaMailSenderImpl sender = new JavaMailSenderImpl();
        sender.setHost(props.getHost());
        sender.setPort(props.getPort());
        // ...
        return sender;
    }
}
```

> Binds all properties that start with `mail.` from `application.yml` (or `.properties`) into a POJO.  
> Use `@Validated` on the POJO to enforce bean‑validation constraints.

---

## `@PropertySource`

```java
@Configuration
@PropertySource("classpath:custom.properties")
public class ExternalPropsConfig {
    // beans can now reference ${some.key}
}
```

> Adds a plain `.properties` file to the `Environment`.  
> The file must be on the classpath (or you can supply an absolute URL).

---

## `@PropertySource("classpath:foo.properties")`

```java
@Configuration
@PropertySource("classpath:foo.properties")
public class FooPropsConfig {
    @Value("${foo.message}")
    private String message;

    @Bean
    public String fooMessage() {
        return message;
    }
}
```

> Exactly the same as the previous example but demonstrates a _specific_ file name.  
> If `foo.properties` contains `foo.message=Hello`, the bean `fooMessage` will return `"Hello"`.

---

## `@ConditionalOn…` / `@Conditional`

### Example: `@ConditionalOnMissingBean`

```java
@Configuration
public class OptionalServiceConfig {

    @Bean
    @ConditionalOnMissingBean(MyService.class)
    public MyService defaultMyService() {
        return new DefaultMyService();
    }
}
```

> Registers `DefaultMyService` **only if** no other `MyService` bean is already present in the context.

### Example: Custom `@Conditional`

```java
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
@Conditional(WindowsCondition.class)
public @interface ConditionalOnWindows { }

public class WindowsCondition implements Condition {
    @Override
    public boolean matches(ConditionContext ctx, AnnotatedTypeMetadata meta) {
        return System.getProperty("os.name").toLowerCase().contains("win");
    }
}

@Configuration
@ConditionalOnWindows
public class WindowsOnlyConfig {
    // beans here are loaded only on Windows
}
```

> You can write any custom logic inside a `Condition` implementation and use it as an annotation.

---

## `@EnableAspectJAutoProxy`

```java
@Configuration
@EnableAspectJAutoProxy   // turns on Spring AOP (proxy‑based)
public class AopDemoConfig {

    @Bean
    public LoggingAspect loggingAspect() {
        return new LoggingAspect();
    }
}

@Aspect
@Component
public class LoggingAspect {

    @Around("execution(* com.example.repository.*.*(..))")
    public Object log(ProceedingJoinPoint pjp) throws Throwable {
        System.out.println(">> before " + pjp.getSignature());
        Object result = pjp.proceed();
        System.out.println("<< after " + pjp.getSignature());
        return result;
    }
}
```

> Turns on AOP support so that `@Aspect` classes can weave around your beans.  
> Most starters (e.g., `spring-boot-starter-actuator`) enable this automatically, so you rarely need to add it yourself.

---

### Quick sanity‑check

| What you’ll usually put in the **main** class | Annotation(s)                                                 |
| --------------------------------------------- | ------------------------------------------------------------- |
| Entry point + auto‑config                     | `@SpringBootApplication`                                      |
| Only the config section                       | `@EnableAutoConfiguration` (or inside a custom config)        |
| Scanning non‑default packages                 | `@ComponentScan(basePackages=…)`                              |
| Pull in separate modules                      | `@Import(...)`                                                |
| Simple bean                                   | `@Bean`                                                       |
| Bind `application.yml` values                 | `@ConfigurationProperties` + `@EnableConfigurationProperties` |
| Add an external file                          | `@PropertySource`                                             |
| Conditional beans                             | `@ConditionalOnMissingBean` or a custom `@Conditional`        |

Now you can drop the annotation in your own classes and see the effect immediately. Happy coding!
