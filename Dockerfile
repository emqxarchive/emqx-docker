FROM alpine:3.8

MAINTAINER Huang Rui <vowstar@gmail.com>, EMQ X Team <support@emqx.io>

ENV OTP_VERSION="21.0.7"


RUN set -xe \
        && OTP_DOWNLOAD_URL="https://github.com/erlang/otp/archive/OTP-${OTP_VERSION}.tar.gz" \
        && OTP_DOWNLOAD_SHA256="4e9c98b5f29918d0896b21ce28b13c7928d4c9bd6a0c7d23b4f19b27f6e3b6f7" \
        && apk add --no-cache --virtual .fetch-deps \
                curl \
                ca-certificates \
        && apk add --no-cache --virtual .erlang-rundeps lksctp-tools \
                ncurses \
                unixodbc \
                openssl \
        && apk add --no-cache --virtual .build-deps \
                gcc \
                g++ \
                libc-dev \
                linux-headers \
                bsd-compat-headers \
                make \
                autoconf \
                ncurses-dev \
                openssl-dev \
                unixodbc-dev \
                lksctp-tools-dev \
                tar \
                git \
                wget \
        && curl -fSL -o otp-src.tar.gz "$OTP_DOWNLOAD_URL" \
        && (echo "$OTP_DOWNLOAD_SHA256  otp-src.tar.gz" | sha256sum -c - ) \
        && export ERL_TOP="/usr/src/otp_src_${OTP_VERSION%%@*}" \
        && mkdir -vp $ERL_TOP \
        && tar -xzf otp-src.tar.gz -C $ERL_TOP --strip-components=1 \
        && rm otp-src.tar.gz \
        && ( cd $ERL_TOP \
          && ./otp_build autoconf \
          && ./configure --build=x86_64-alpine-linux-musl \
          && make -j$(getconf _NPROCESSORS_ONLN) \
          && make install ) \
        && rm -rf $ERL_TOP \
        && find /usr/local -regex '/usr/local/lib/erlang/\(lib/\|erts-\).*/\(man\|doc\|obj\|c_src\|emacs\|info\|examples\)' | xargs rm -rf \
        && find /usr/local -name src | xargs -r find | grep -v '\.hrl$' | xargs rm -v || true \
        && find /usr/local -name src | xargs -r find | xargs rmdir -vp || true \
        && scanelf --nobanner -E ET_EXEC -BF '%F' --recursive /usr/local | xargs -r strip --strip-all \
        && scanelf --nobanner -E ET_DYN -BF '%F' --recursive /usr/local | xargs -r strip --strip-unneeded \
        && apk del --purge .fetch-deps .build-deps

ENV EMQX_VERSION=v3.0-beta.3

RUN set -ex \
        && apk add --no-cache --virtual .build-deps \
                bsd-compat-headers \
                gcc \
                g++ \
                make \
                tar \
                git \
                perl \
        && cd / \
        && git clone -b ${EMQX_VERSION} https://github.com/emqx/emqx-rel /emqx \
        && cd /emqx \
        && make \
        && mkdir -p /opt && mv /emqx/_rel/emqx /opt/emqx \
        && cd / && rm -rf /emqx \
        && ln -s /opt/emqx/bin/* /usr/local/bin/ \
        && apk --purge del .build-deps 

WORKDIR /opt/emqx
COPY ./start.sh ./

# start emqx and initial environments
CMD ["/opt/emqx/start.sh"]

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
