# Axon Config

- Download axon program zip file and extract the file
- Inside the extracted folder create config folder
- create file inside config file **axonserver.properties** and set properties:

```
# inside axonserver.properties:
server.port=8024
axoniq.axonserver.name=My Axon Server
axoniq.axonserver.hostname=localhost
axoniq.axonserver.devmode.enabled=true
#devmode.enabled -> "Reset Event Stor Button"
```

- run the command

```bash
java -jar axonserver.jar
```

## Docker

```docker
docker run --name axonserver
  -e AXONIQ_AXONSERVER_DEVMODE_ENABLED=true
  -p 8024:8024 -p 8124:8124
  -v "/d/Hooman/interview sample/java-sample/axon-app/app-root-1/docker-data/data":/data
  -v "/d/Hooman/interview sample/java-sample/axon-app/app-root-1/docker-data/eventdata":/eventdata
  -v "/d/Hooman/interview sample/java-sample/axon-app/app-root-1/docker-data/config":/config
  axoniq/axonserver
```

## Dependencies:

- axon-spring-boot-starter
- guava (spring boot with axon)
- inside dependencyManagement: axon-bom
