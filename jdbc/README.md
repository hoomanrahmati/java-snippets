## JDBC

[back](../README.md)

### application.properties for h2 and jdbc

```xml
spring.datasource.driver-class-name=org.h2.Driver
spring.datasource.username=sa
spring.datasource.password=password
spring.datasource.url=jdbc:h2:file:./data/spring6jdbc3
spring.sql.init.mode=always
spring.h2.console.enabled=true
spring.h2.console.path=/h2-console
```

```xml
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
</dependency>
```
