## Bash Commands

[back](../README.md)

```bash

netstat -ano | findstr 8080
netstat -ano | grep 8080
# tcp 0.0.0.0:8080 listening 5136

taskkill /pid 5136 /F
# Success: the process with PID 5136 has been terminated.
```

Build the images and then run docker compose (https://blog.vinsguru.com/)

```
docker compose up --build

# Dockerfile
# ----------
# FROM eclipse-temurin:25-jre-alpine
# WORKDIR /app
# COPY target/*.jar app.jar
# EXPOSE 8080
# CMD [ "java", "-jar", "app.jar" ]

# docker-compose.yaml
# -------------------
# services:
#   movie-service:
#     image: vinsguru/movie-service
#     build: ./movie-service
#     environment:
#       "actor-service.url": "http://actor-service:8080/api/actors/"
#       "review-service.url": "http://review-service:8080/api/reviews"
#     ports:
#       - "8080:8080"
#   actor-service:
#     image: vinsguru/actor-service
#     build: ./actor-service
#   review-service:
#     image: vinsguru/review-service
#     build: ./review-service
```

Just build the images

```
docker compose build
```

```
docker compose up -d
docker ps -a
docker compose logs movie-service
```
