FROM devicexx/erlang

MAINTAINER Huang Rui <vowstar@gmail.com>

ENV EMQTTD_VERSION=master

ADD ./start.sh /start.sh

RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk --no-cache add \
        git \
        make \
        socat \
    && git clone -b ${EMQTTD_VERSION} https://github.com/emqtt/emqttd.git /emqttd \
    && cd /emqttd \
    && git checkout origin/master rebar.config \
    && make && make dist \
    && mkdir /opt && mv /emqttd/rel/emqttd /opt/emqttd \
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
