# EMQ Docker

*EMQ* (Erlang MQTT Broker) is a distributed, massively scalable, highly extensible MQTT message broker written in Erlang/OTP.

Current docker image size: 37.1 MB 

### Get emqttd

You can build this docker image by yourself.

```bash
git clone -b master https://github.com/emqtt/emq_docker.git
cd emq_docker
docker build -t emq:latest . 
```

### Run emqttd

Execute some command under this docker image

``docker run --rm -ti -v `pwd`:$(somewhere) emq/$(image) $(somecommand)``

For example

``docker run --rm -ti --name emq -p 18083:18083 -p 1883:1883 emq:latest``

### Configuration

Use the environment variable to configure the EMQ docker container

#### EMQ Configuration

| Oprtions                 | Default            | Description                           |
| ------------------------ | ------------------ | ------------------------------------- |
| EMQ_NAME                 | container name     | emq node short name                   |
| EMQ_HOST                 | container IP       | emq node host, IP or FQDN             |
| EMQ_NODE_NAME            | EMQ_NAME@EMQ_HOST  | like email address                    |
| EMQ_NODE_COOKIE          | emq_dist_cookie    | cookie for cluster                    |
| EMQ_PROCESS_LIMIT        | 2097152            | erlang vm process limit               |
| EMQ_MAX_PORTS            | 1048576            | erlang vm max ports                   |
| EMQ_LOG_CONSOLE          | file               | log console output method             |
| EMQ_LOG_LEVEL            | error              | log console level                     |
| EMQ_ALLOW_ANONYMOUS      | true               | allow mqtt anonymous login            |
| EMQ_TCP_PORT             | 1883               | MQTT TCP port                         |
| EMQ_TCP_ACCEPTORS        | 64                 | MQTT TCP acceptors                    |
| EMQ_TCP_MAX_CLIENTS      | 1000000            | MQTT TCP max clients                  |
| EMQ_SSL_PORT             | 8883               | MQTTS TCP/SSL port                    |
| EMQ_SSL_ACCEPTORS        | 32                 | MQTTS TCP/SSL acceptors               |
| EMQ_SSL_MAX_CLIENTS      | 500000             | MQTTS TCP/SSL max clients             |
| EMQ_HTTP_PORT            | 8083               | HTTP/WS port                          |
| EMQ_HTTP_ACCEPTORS       | 64                 | HTTP/WS acceptors                     |
| EMQ_HTTP_MAX_CLIENTS     | 1000000            | HTTP/WS max clients                   |
| EMQ_HTTPS_PORT           | 8084               | HTTPS/WSS port                        |
| EMQ_HTTPS_ACCEPTORS      | 32                 | HTTPS/WSS acceptors                   |
| EMQ_HTTPS_MAX_CLIENTS    | 500000             | HTTPS/WSS max clients                 |
| EMQ_MAX_PACKET_SIZE      | 64KB               | Max Packet Size Allowed               |

For example, set mqtt tcp port to 1883

``docker run --rm -ti --name emq -e "EMQ_TCP_PORT=1883" -p 18083:18083 -p 1883:1883 emq:latest``

#### EMQ Loaded Plugins Configuration

| Oprtions                 | Default            | Description                           |
| ------------------------ | ------------------ | ------------------------------------- |
| EMQ_LOADED_PLUGINS       | see content below  | default plugins emq loaded            |

Default environment variable ``EMQ_LOADED_PLUGINS``, including 

- ``emq_recon``
- ``emq_dashboard``
- ``emq_mod_presence``
- ``emq_mod_retainer``
- ``emq_mod_subscription``

```bash
# The default EMQ_LOADED_PLUGINS env
EMQ_LOADED_PLUGINS="emq_recon,emq_dashboard,emq_mod_presence,emq_mod_retainer,emq_mod_subscription"
```

For example, load ``emq_auth_redis`` plugin, set it into ``EMQ_LOADED_PLUGINS`` and use any separator to separates it.

You can use comma

```bash
EMQ_LOADED_PLUGINS="emq_auth_redis,emq_recon,emq_dashboard,emq_mod_presence,emq_mod_retainer,emq_mod_subscription"
```

You can use space

```bash
EMQ_LOADED_PLUGINS="emq_auth_redis emq_recon emq_dashboard emq_mod_presence emq_mod_retainer emq_mod_subscription"
```

You can use other separator that you want

```bash
EMQ_LOADED_PLUGINS="emq_auth_redis | emq_recon | emq_dashboard | emq_mod_presence | emq_mod_retainer | emq_mod_subscription"
```

All the plugin you defined in env ``EMQ_LOADED_PLUGINS`` will be loaded.
