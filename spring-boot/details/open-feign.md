## **OpenFeign**

[back](../README.md)

## 🧰 Prerequisites

Make sure you have the following dependencies in your project:

- **Spring Boot** (2.x or 3.x)
- **Spring Cloud OpenFeign**
- **Spring Web**

---

## 📦 1. Add Dependencies

### For **Maven** (`pom.xml`):

```xml
<dependencies>
    <!-- Spring Boot Starter Web -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>

    <!-- Spring Cloud OpenFeign -->
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-openfeign</artifactId>
    </dependency>
</dependencies>
```

### For **Gradle** (`build.gradle`):

```groovy
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.cloud:spring-cloud-starter-openfeign'
}
```

---

## 🎯 2. Enable Feign Clients

Add the `@EnableFeignClients` annotation in your main Spring Boot application class.

```java
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.openfeign.EnableFeignClients;

@SpringBootApplication
@EnableFeignClients
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
```

---

## 🧱 3. Create a Feign Client Interface

This interface defines how your application will interact with a remote REST API.

```java
package com.example.demo.client;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@FeignClient(name = "user-service", url = "${user.service.url}")
public interface UserClient {

    @GetMapping("/users/{id}")
    User getUserById(@PathVariable("id") Long id);
}
```

---

## 📄 4. Configure the Remote Service URL

In your `application.properties` (or `application.yml`), define the base URL of the remote service:

```properties
user.service.url=https://jsonplaceholder.typicode.com
```

---

## 📦 5. Define the User DTO

Create a simple `User` class to map the response from the remote service.

```java
package com.example.demo.dto;

public class User {
    private Long id;
    private String name;
    private String email;

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
}
```

---

## 🧩 6. Use the Feign Client in a Service or Controller

Here’s how you can use the `UserClient` in a controller:

```java
package com.example.demo.controller;

import com.example.demo.client.UserClient;
import com.example.demo.dto.User;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private UserClient userClient;

    @GetMapping("/{id}")
    public User getUser(@PathVariable Long id) {
        return userClient.getUserById(id);
    }
}
```

---

## 🧪 7. Testing the Application

Start your Spring Boot application and make a request to:

```
GET http://localhost:8080/api/users/1
```

You should receive a response similar to:

```json
{
  "id": 1,
  "name": "Leanne Graham",
  "email": "sincere@april.biz"
}
```

---

## ✅ Summary

This example demonstrates how to use **OpenFeign** in **Spring Boot** to consume a remote REST API. Key components include:

- `@FeignClient` to define the client.
- `@GetMapping` to map HTTP methods.
- External configuration via `application.properties`.
- A simple DTO to map the response.

---

## 📌 Additional Tips

- Use `@RequestMapping` for more complex path mappings.
- Use `@RequestHeader` or `@RequestParam` to pass headers or query parameters.
- You can use `@FeignClient` with Spring Cloud Config for dynamic service discovery.

Let me know if you'd like a more advanced example with **circuit breakers**, **custom interceptors**, or **retry logic**!
