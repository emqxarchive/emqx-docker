# EMQ Docker

emqttd(Erlang MQTT Broker) is a massively scalable and clusterable MQTT V3.1/V3.1.1 broker written in Erlang/OTP.

### Run

Execute some command under this docker image

``docker run --rm -ti -v `pwd`:$(somewhere) emq/$(image) $(somecommand)``

#### USE EMQTTD

Get emqttd

- [] TODO: Add EMQ official docker registry

Run emqttd

``docker run --rm -ti --name emq -p 18083:18083 -p 1883:1883 emq:latest``
