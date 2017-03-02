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

The environment variables which with ``EMQ_`` prefix are mapped to configuration file, ``.`` get replaced by ``__``.

Example:

```bash
EMQ_MQTT__LISTENER__SSL__ACCEPTORS <--> mqtt.listener.ssl.acceptors
```

Also the environment variables which with ``PLATFORM_`` prefix are mapped to template string in configuration file.

```bash
PLATFORM_ETC_DIR                   <--> {{ platform_etc_dir }}
```

#### EMQ Configuration

> NOTE: All EMQ Configuration in [etc/emq.conf](https://github.com/emqtt/emqttd/blob/master/etc/emq.conf) could config by environment. The following list is just an example, not a complete configuration.

| Oprtions                  | Default            | Mapped                    | Description                           |
| ------------------------- | ------------------ | ------------------------- | ------------------------------------- |
| PLATFORM_ETC_DIR          | /opt/emqtt/etc     | {{ platform_etc_dir }}    | The etc directory                     |
| PLATFORM_LOG_DIR          | /opt/emqtt/log     | {{ platform_log_dir }}    | The log directory                     |
| EMQ_NODE__NAME            | EMQ_NAME@EMQ_HOST  | node.name                 | Erlang node name, name@ipaddress/host |
| EMQ_NODE__COOKIE          | emq_dist_cookie    | node.cookie               | cookie for cluster                    |
| EMQ_LOG__CONSOLE          | console            | log.console               | log console output method             |
| EMQ_MQTT__ALLOW_ANONYMOUS | true               | mqtt.allow_anonymous      | allow mqtt anonymous login            |
| EMQ_MQTT__LISTENER__TCP   | 1883               | mqtt.listener.tcp         | MQTT TCP port                         |
| EMQ_MQTT__LISTENER__SSL   | 8883               | mqtt.listener.ssl         | MQTT TCP TLS/SSL port                 |
| EMQ_MQTT__LISTENER__HTTP  | 8083               | mqtt.listener.http        | HTTP and WebSocket port               |
| EMQ_MQTT__LISTENER__HTTPS | 8084               |mqtt.listener.https         | HTTPS and WSS port                    |


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

You can use comma, space or other separator that you want.

All the plugin you defined in env ``EMQ_LOADED_PLUGINS`` will be loaded.

```bash
EMQ_LOADED_PLUGINS="emq_auth_redis,emq_recon,emq_dashboard,emq_mod_presence,emq_mod_retainer,emq_mod_subscription"
EMQ_LOADED_PLUGINS="emq_auth_redis emq_recon emq_dashboard emq_mod_presence emq_mod_retainer emq_mod_subscription"
EMQ_LOADED_PLUGINS="emq_auth_redis | emq_recon | emq_dashboard | emq_mod_presence | emq_mod_retainer | emq_mod_subscription"
```

#### EMQ Plugin Configuration

The environment variables which with ``EMQ_`` prefix are mapped to all emq plugins' configuration file, ``.`` get replaced by ``__``.

Example:

```bash
EMQ_AUTH__REDIS__SERVER   <--> auth.redis.server
EMQ_AUTH__REDIS__PASSWORD <--> auth.redis.password
```

Don't worry about where to find the configuration file of emq plugins, this docker image will find and config them automatically using some magic.

All plugin of emq project could config in this way, following the environment variables mapping rule above.

Assume you are using redis auth plugin, for example:

```bash
#EMQ_AUTH__REDIS__SERVER="redis.at.yourserver"
#EMQ_AUTH__REDIS__PASSWORD="password_for_redis"

docker run --rm -ti --name emq -p 18083:18083 -p 1883:1883 \
    -e "EMQ_TCP_PORT=1883" \
    -e EMQ_LOADED_PLUGINS="emq_auth_redis,emq_recon,emq_dashboard,emq_mod_presence,emq_mod_retainer,emq_mod_subscription" \
    -e EMQ_AUTH__REDIS__SERVER="redis.at.yourserver" \
    -e EMQ_AUTH__REDIS__PASSWORD="password_for_redis"
    emq:latest

```



### Thanks

@je-al https://github.com/emqtt/emq-docker/issues/2 The idea of variable names get mapped, dots get replaced by __.