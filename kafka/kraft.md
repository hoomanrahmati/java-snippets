## Start the Kafka environment

[back](README.md)

- Generate a Cluster UUID

```bash
$ KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
```

- Format Log Directories

```bash
$ bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c config/server.properties
```

- Start the Kafka Server

```bash
$ bin/kafka-server-start.sh config/server.properties
```
