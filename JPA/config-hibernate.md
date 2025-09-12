## Config Hibernate and JPA

[Back](README.md)

### pom.xml

```xml
<dependencies>
    <dependency>
        <groupId>org.hibernate</groupId>
        <artifactId>hibernate-core</artifactId>
        <version>6.5.0.Final</version>
    </dependency>
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <version>42.7.7</version>
    </dependency>
</dependencies>
```

### (persistence.xml) src\main\resources\META-INF\persistence.xml

```xml
<?xml version="1.0" encoding="utf-8" ?>
<persistence xmlns="http://xmlns.jcp.org/xml/ns/persistence" version="2.1">
    <persistence-unit name="library_persistence_unit" transaction-type="RESOURCE_LOCAL">
        <provider>org.hibernate.jpa.HibernatePersistenceProvider</provider>
        <properties>
            <property name="jakarta.persistence.jdbc.url" value="jdbc:postgresql://localhost:5432/library"/>
            <property name="jakarta.persistence.jdbc.driver" value="org.postgresql.Driver"/>
            <property name="jakarta.persistence.jdbc.user" value="postgres"/>
            <property name="jakarta.persistence.jdbc.password" value="12345"/>
            <property name="hibernate.show_sql" value="true"/>
            <property name="hibernate.hbm2ddl.auto" value="update"/>
        </properties>
    </persistence-unit>
</persistence>
```

### To connect into wildfly

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<persistence xmlns="https://jakarta.ee/xml/ns/persistence"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="https://jakarta.ee/xml/ns/persistence https://jakarta.ee/xml/ns/persistence/persistence_3_2.xsd"
             version="3.2">
    <persistence-unit name="SERP-PU" transaction-type="JTA">
        <provider>org.hibernate.jpa.HibernatePersistenceProvider</provider>
        <jta-data-source>java:jboss/datasources/serp</jta-data-source>
        <exclude-unlisted-classes>false</exclude-unlisted-classes>
        <properties>
            <property name="hibernate.dialect" value="org.hibernate.dialect.SQLServerDialect"/>
            <property name="hibernate.jpa.compliance.query" value="false"/>
            <property name="hibernate.show_sql" value="true"/>
            <property name="hibernate.format_sql" value="true"/>
            <property name="hibernate.use_sql_comments" value="true"/>
            <property name="hibernate.hbm2ddl.auto" value="update"/>
        </properties>
    </persistence-unit>
</persistence>

```

- need to use jta-data-source:

```xml
<jta-data-source>java:jboss/datasources/serp</jta-data-source>
```

and also we can add inside persistence.xml: (value: create-drop, create, update, validate)

```xml
<property name="hibernate.hbm2ddl.auto" value="create-drop"/>
```
