## KSQL

- [back](README.md)

### Bash Command

Generate sample data (ksql-datagense):

```bash
ksql-datagen schema=./datagen/userprofile.avro format=json topic=USERPROFILE key=userid maxInterval=5000 iterations=100
```

### Docker Command

run docker cli:
http://localhost:9021/clusters/

Start ksql: (first go to the docker-compose.yml file then run a bash command then run following command)

```bash
docker-compose exec ksqldb-cli ksql http://ksqldb-server:8088
docker-compose exec broker kafka-topics --bootstrap-server localhost:9092 --list
docker exec broker kafka-topics --bootstrap-server localhost:9092 --create --partitions 1 --replication-factor 1 --topic USERS
docker-compose exec broker kafka-console-producer --bootstrap-server localhost:9092 --topic USERS



```

### KSQL Command

```sql
show topics;
list topics;

print users from beginning limit 10;
```

- create stream

```sql
ksql> create stream user_stream (name varchar, countrycode varchar) with (KAFKA_TOPIC='USERS', VALUE_FORMAT='DELIMITED');
-- emit changes
ksql> select name, countrycode from user_stream emit changes;

ksql> set 'auto.offset.rest'='earliest';

ksql> select name, countrycode from user_stream emit changes limit 4;

ksql> select count(*), countrycode from user_stream group by countrycode emit changes;

ksql> drop stream if exists user_stream;
ksql> drop stream if exists user_stream delete topic;

-- value_format = 'JSON'
create stream userprofile (userid int, firstname varchar, lastname varchar, countrycode varchar, rating double) with (value_format = 'JSON', KAFKA_TOPIC='USERPROFILE');

ksql> describe userprofile;
```
