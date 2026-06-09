Here's a detailed explanation and sample code for using `@Order` in **Spring Boot** for **filters**, **interceptors**, and **component scans**.

[back](../annotation-cheat-sheet.md)

---

## 🔍 1. **Filter Ordering with `@Order`**

In Spring Boot, you can use `@Order` to define the order in which **filters** execute during the request lifecycle.

### ✅ Example: Filter with `@Order`

```java
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.annotation.Order;

@Component
@Order(1) // Lower value means higher priority
public class FirstFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        System.out.println("FirstFilter: Before processing request");
        filterChain.doFilter(request, response);
        System.out.println("FirstFilter: After processing request");
    }
}
```

```java
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.core.annotation.Order;

@Component
@Order(2) // Runs after FirstFilter
public class SecondFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        System.out.println("SecondFilter: Before processing request");
        filterChain.doFilter(request, response);
        System.out.println("SecondFilter: After processing request");
    }
}
```

### 📌 Output:

```
FirstFilter: Before processing request
SecondFilter: Before processing request
SecondFilter: After processing request
FirstFilter: After processing request
```

> **Note:** Filters with lower `@Order` values execute **first**.

---

## 🔍 2. **Interceptor Ordering with `@Order`**

Spring MVC interceptors are not directly annotated with `@Order`, but they can be ordered using the `Ordered` interface or by using `@Order` on the interceptor class.

### ✅ Example: Interceptor with `@Order`

```java
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.core.annotation.Order;

@Component
@Order(1) // Lower value means higher priority
public class FirstInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        System.out.println("FirstInterceptor: preHandle");
        return true;
    }

    @Override
    public void postHandle(HttpServletRequest request, HttpServletResponse response, Object handler, Object result) {
        System.out.println("FirstInterceptor: postHandle");
    }
}
```

```java
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.core.annotation.Order;

@Component
@Order(2) // Runs after FirstInterceptor
public class SecondInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        System.out.println("SecondInterceptor: preHandle");
        return true;
    }

    @Override
    public void postHandle(HttpServletRequest request, HttpServletResponse response, Object handler, Object result) {
        System.out.println("SecondInterceptor: postHandle");
    }
}
```

### ✅ Register Interceptors in `WebMvcConfigurer`

```java
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new FirstInterceptor());
        registry.addInterceptor(new SecondInterceptor());
    }
}
```

### 📌 Output:

```
FirstInterceptor: preHandle
SecondInterceptor: preHandle
SecondInterceptor: postHandle
FirstInterceptor: postHandle
```

> **Note:** Interceptors are ordered by their `@Order` value. If you don't use `@Order`, the order is determined by the order in which they are added to the registry.

---

## 🔍 3. **Component Scan Ordering with `@Order`**

Spring Boot **does not use `@Order`** to control the **order of component scans**. Instead, the order of component scan is determined by the **order in which `@ComponentScan` annotations appear in configuration classes**.

### ❗ Example: Component Scans

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication
@ComponentScan(basePackages = "com.example.first") // Scans first
public class FirstApplication {
    public static void main(String[] args) {
        SpringApplication.run(FirstApplication.class, args);
    }
}
```

```java
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;

@SpringBootApplication
@ComponentScan(basePackages = "com.example.second") // Scans second
public class SecondApplication {
    public static void main(String[] args) {
        SpringApplication.run(SecondApplication.class, args);
    }
}
```

> **Note:** The `@ComponentScan` order is **not** controlled by `@Order`. If you want to control the **order of bean initialization**, you can use `@Order` on beans that implement the `Ordered` interface or use `@Order` on the bean class.

---

## ✅ Summary

| Component          | Ordering Mechanism                                             | Example                    |
| ------------------ | -------------------------------------------------------------- | -------------------------- |
| **Filter**         | `@Order` on the filter class                                   | `@Order(1)`                |
| **Interceptor**    | `@Order` on the interceptor class                              | `@Order(1)`                |
| **Component Scan** | Order of `@ComponentScan` annotations in configuration classes | Not controlled by `@Order` |

---

Let me know if you'd like to see examples for **`@Order` on beans** or **custom ordering logic**!
