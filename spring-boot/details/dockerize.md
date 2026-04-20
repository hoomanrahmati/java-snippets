Dockerizing a Spring Boot project involves creating a Docker image that packages your application and its dependencies. Below is a step-by-step guide to help you achieve this.

[back](../README.md)

---

### **Prerequisites**

1. **Docker Installed**: Ensure Docker is installed on your system. You can verify this with:
   ```bash
   docker --version
   ```
2. **Spring Boot Project**: You should have a Spring Boot project ready (e.g., built with Maven or Gradle).

---

### **Step 1: Create a Dockerfile**

Create a file named `Dockerfile` in the root of your Spring Boot project. Here's an example using **multi-stage build** (recommended for smaller images):

```Dockerfile
# Stage 1: Build the application
FROM maven:3.8.6 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package

# Stage 2: Create a minimal runtime image
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY --from=builder /app/target/your-springboot-app.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Notes**:

- Replace `your-springboot-app.jar` with your actual JAR file name (e.g., `your-project-0.0.1-SNAPSHOT.jar`).
- `EXPOSE 8080` maps the container port to the host port (default for Spring Boot).
- Use `openjdk:17-jdk-slim` for a lightweight runtime image.

---

### **Step 2: Build the Docker Image**

Run the following command in the root of your project directory:

```bash
docker build -t your-springboot-app .
```

- `-t` tags the image with a name (`your-springboot-app`).
- `.` specifies the build context (current directory).

---

### **Step 3: Run the Docker Container**

Start a container using the built image:

```bash
docker run -d -p 8080:8080 --name your-springboot-container your-springboot-app
```

- `-d`: Runs the container in detached mode.
- `-p 8080:8080`: Maps port 8080 on the host to port 8080 in the container.
- `--name`: Assigns a name to the container for easier management.

---

### **Step 4: Test the Application**

Open your browser or use `curl` to test the app:

```bash
curl http://localhost:8080/actuator/health
```

Replace `/actuator/health` with your app's actual endpoint.

---

### **Optional: Use Docker Compose (for Multi-Service Apps)**

If your app depends on other services (e.g., a database), use a `docker-compose.yml` file:

```yaml
version: "3.8"
services:
  your-springboot-app:
    image: your-springboot-app
    build: .
    ports:
      - "8080:8080"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql-db:3306/mydb
    depends_on:
      - mysql-db

  mysql-db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: mydb
      MYSQL_USER: user
      MYSQL_PASSWORD: password
    ports:
      - "3306:3306"
```

Run with:

```bash
docker-compose up -d
```

---

### **Best Practices**

1. **Use Environment Variables**: Store sensitive data (e.g., database credentials) in environment variables instead of hardcoding them.
2. **Use Multi-Stage Builds**: This reduces the final image size.
3. **Optimize Ports**: Ensure the container exposes the correct ports (`EXPOSE` in Dockerfile).
4. **Use Lightweight Base Images**: Prefer `openjdk:slim` or `adoptium/temurin` for smaller images.

---

### **Troubleshooting**

- **Missing JAR File**: Ensure your Spring Boot app is built (`mvn package` or `gradle build`) before running `docker build`.
- **Port Conflicts**: If port 8080 is already in use, change the `-p` mapping (e.g., `8081:8080`).
- **Logs**: Check container logs with:
  ```bash
  docker logs your-springboot-container
  ```

---

### **Optional: Push to a Registry**

To deploy your image to a registry (e.g., Docker Hub):

1. **Tag the Image**:
   ```bash
   docker tag your-springboot-app your-dockerhub-username/your-springboot-app:latest
   ```
2. **Login to Docker Hub**:
   ```bash
   docker login
   ```
3. **Push the Image**:
   ```bash
   docker push your-dockerhub-username/your-springboot-app:latest
   ```

---

By following these steps, your Spring Boot application will be containerized and ready for deployment in any environment that supports Docker. Let me know if you need help with specific configurations! 🐳

---

### To dockerize a **multi-service Spring Boot microservices application** that depends on **PostgreSQL** and **Kafka**, you can use **Docker Compose** to define and manage the services in a single, declarative file. This approach ensures that all your services (microservices, databases, message brokers, etc.) are started and connected properly.

## 📦 1. Project Structure

Your project should have the following structure:

```
your-project/
├── your-springboot-service/
│   ├── Dockerfile
│   └── (your Spring Boot app files)
├── docker-compose.yml
```

---

## 📜 2. Dockerfile for Spring Boot Microservice

Here's a sample `Dockerfile` for your Spring Boot service (using a **multi-stage build**):

```Dockerfile
# Stage 1: Build the application
FROM maven:3.8.6 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package

# Stage 2: Create a minimal runtime image
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY --from=builder /app/target/your-springboot-service.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Notes:**

- Replace `your-springboot-service.jar` with the actual JAR name generated by your build (e.g., `your-service-0.0.1-SNAPSHOT.jar`).
- Ensure you have built the JAR file before running `docker build`.

---

## 🧱 3. `docker-compose.yml` File

Here is a complete `docker-compose.yml` file that includes:

- Your Spring Boot service
- PostgreSQL database
- Apache Kafka broker

```yaml
version: "3.8"

services:
  # Spring Boot Microservice
  your-springboot-service:
    build: ./your-springboot-service
    ports:
      - "8080:8080"
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/yourdb
      - SPRING_DATASOURCE_USERNAME=youruser
      - SPRING_DATASOURCE_PASSWORD=yourpassword
      - KAFKA_BOOTSTRAP_SERVERS=kafka:9092
    depends_on:
      - postgres
      - kafka

  # PostgreSQL Database
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: youruser
      POSTGRES_PASSWORD: yourpassword
      POSTGRES_DB: yourdb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  # Kafka Broker
  kafka:
    image: bitnami/kafka:3.4.0
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
    ports:
      - "9092:9092"
    depends_on:
      - zookeeper

  # Zookeeper for Kafka
  zookeeper:
    image: bitnami/zookeeper:3.8.6
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
    volumes:
      - zookeeper_data:/var/lib/zookeeper

volumes:
  postgres_data:
  zookeeper_data:
```

---

## 🧪 4. Steps to Run the Services

1. **Ensure your Spring Boot service is built**:

   ```bash
   cd your-springboot-service
   mvn clean package
   cd ..
   ```

2. **Start all services with Docker Compose**:

   ```bash
   docker-compose up -d
   ```

   This will:
   - Build your Spring Boot service image
   - Start PostgreSQL, Kafka, Zookeeper, and your Spring Boot service

3. **Check logs**:

   ```bash
   docker-compose logs -f
   ```

4. **Test your services**:
   - Visit `http://localhost:8080` (or the appropriate endpoint)
   - Use a Kafka producer/consumer tool to test message passing
   - Use a PostgreSQL client to connect to the database

---

## ⚠️ 5. Additional Tips

### 🔁 Waiting for Dependencies

The `depends_on` keyword in Docker Compose ensures that services start in the correct order, but **does not wait for the services to be ready**. If your Spring Boot app needs to wait for the database or Kafka to be fully up, you can:

- Use a **startup script** with `wait-for-it.sh` or `docker-entrypoint.sh`
- Add logic in your app to retry connecting to the database or Kafka

### 📦 Customizing Spring Boot Configuration

Ensure your `application.properties` or `application.yml` is configured to use environment variables for database and Kafka connections:

```properties
spring.datasource.url=jdbc:postgresql://${SPRING_DATASOURCE_URL}
spring.datasource.username=${SPRING_DATASOURCE_USERNAME}
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD}
spring.kafka.bootstrap-servers=${KAFKA_BOOTSTRAP_SERVERS}
```

---

## 📦 6. Optional: Push to a Container Registry

If you want to push your Spring Boot image to a registry (e.g., Docker Hub):

```bash
docker-compose build your-springboot-service
docker-compose push your-springboot-service
```

---

## 🧭 Summary

By using **Docker Compose**, you can easily manage a **multi-service microservices architecture** that includes your Spring Boot app, **PostgreSQL**, and **Kafka**. This setup is scalable, easy to manage, and ideal for local development or staging environments.

Let me know if you'd like help adding more services (e.g., Redis, RabbitMQ, or another microservice) or deploying this to a cloud platform! 🚀
