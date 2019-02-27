ARG BUILD_FROM

FROM $BUILD_FROM

ARG BUILD_DATE
ARG BUILD_VERSION
ARG BUILD_REF
ARG ARCH
ARG QEMU_ARCH

# Basic build-time metadata as defined at http://label-schema.org
LABEL org.label-schema.build-date=${BUILD_DATE} \
    org.label-schema.docker.dockerfile="Dockerfile" \
    org.label-schema.license="GNU" \
    org.label-schema.name="emqx" \
    org.label-schema.version=${BUILD_VERSION} \
    org.label-schema.description="EMQ (Erlang MQTT Broker) is a distributed, massively scalable, highly extensible MQTT messaging broker written in Erlang/OTP." \
    org.label-schema.url="http://emqx.io" \
    org.label-schema.vcs-ref=${BUILD_REF} \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://github.com/emqx/emqx-docker" \
    maintainer="Raymond M Mouthaan <raymondmmouthaan@gmail.com>, Huang Rui <vowstar@gmail.com>, EMQ X Team <support@emqx.io>"

COPY start.sh tmp/qemu-$QEMU_ARCH-stati* /usr/bin/
COPY emqx-${ARCH} /opt/emqx

RUN ln -s /opt/emqx/bin/* /usr/local/bin/ 
RUN apk add --no-cache ncurses-libs openssl

WORKDIR /opt/emqx

RUN adduser -D -u 1000 emqx

RUN chgrp -Rf emqx /opt/emqx && chmod -Rf g+w /opt/emqx \
      && chown -Rf emqx /opt/emqx

USER emqx

VOLUME ["/opt/emqx/log", "/opt/emqx/data", "/opt/emqx/lib", "/opt/emqx/etc"]

# emqx will occupy these port:
# - 1883 port for MQTT
# - 8883 port for MQTT(SSL)
# - 8083 for WebSocket/HTTP
# - 8084 for WSS/HTTPS
# - 8080 for mgmt API
# - 18083 for dashboard
# - 4369 for port mapping
# - 5369 for gen_rpc port mapping
# - 6369 for distributed node
EXPOSE 1883 8883 8083 8084 8080 18083 4369 5369 6369 6000-6999

CMD ["start.sh"]