FROM alpine:3.4

MAINTAINER Huang Rui <vowstar@gmail.com>

ENV EMQ_VERSION=v2.0-rc.3

ADD ./start.sh /start.sh

RUN apk --no-cache add \
        erlang \
        git \
        make \
        socat \
    && git clone -b ${EMQ_VERSION} https://github.com/emqtt/emqttd-relx.git /emqttd \
    && cd /emqttd \
    && make \
    && mkdir /opt && mv /emqttd/_rel/emqttd /opt/emqttd \
    && cd / && rm -rf /emqttd \
    && mv /start.sh /opt/emqttd/start.sh \
    && chmod +x /opt/emqttd/start.sh \
    && apk --purge del \
        git \
        make \
    && rm -rf /var/cache/apk/*

WORKDIR /opt/emqttd

# start emqttd and initial environments
CMD ["/opt/emqttd/start.sh"]

VOLUME ["/opt/emqttd/etc", "/opt/emqttd/data", "/opt/emqttd/plugins"]

# emqttd will occupy 1883 port for MQTT, 8883 port for MQTT(SSL), 8083 for WebSocket/HTTP, 18083 for dashboard
EXPOSE 1883 8883 8083 18083
