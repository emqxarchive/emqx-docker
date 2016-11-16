# EMQTTD Erlang MQTT Broker

Huang Rui <vowstar@gmail.com>

[![Docker Pulls](https://img.shields.io/docker/pulls/devicexx/emqttd.svg)](https://hub.docker.com/r/devicexx/emqttd/) [![Docker Stars](https://img.shields.io/docker/stars/devicexx/emqttd.svg)](https://hub.docker.com/r/devicexx/emqttd/) [![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](https://github.com/vowstar/esp8266/blob/master/LICENSE)

[EMQTTD](https://hub.docker.com/r/devicexx/emqttd/) docker image is Alpine based EMQTT server, 87MB total, Provide MQTT service. 

emqttd(Erlang MQTT Broker) is a massively scalable and clusterable MQTT V3.1/V3.1.1 broker written in Erlang/OTP.
emqttd is fully open source and licensed under the Apache Version 2.0. emqttd implements both MQTT V3.1 and V3.1.1 protocol specifications, and supports

### Run

Execute some command under this docker image

``docker run --rm -ti -v `pwd`:$(somewhere) devicexx/$(image) $(somecommand)``

#### USE EMQTTD

Get emqttd

``docker pull devicexx/emqttd``

Get specific version

``docker pull devicexx/emqttd:1.0``

Tag available

- 1.1.2
- 1.1.1
- 1.1
- 1.0.3
- 1.0.2
- 1.0.1
- 1.0
- latest 

Run emqttd

``docker run --rm -ti --name emqttd-s1 -p 18083:18083 -p 1883:1883 -p 8083:8083 -p 8443:8443 devicexx/emqttd``

Link emqttd as cluster

``docker run --rm -ti --name emqttd-s2 --link emqttd-s1 devicexx/emqttd``

