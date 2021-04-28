FROM buildpack-deps:stable

WORKDIR /docker

RUN apt-get update && apt-get install -y iptables \
  libgmp-dev

ENV STRONGSWAN_VERSION 5.9.2
ENV GPG_KEY 948F158A4E76A27BF3D07532DF42C170B34DBA77

RUN mkdir -p /usr/src/strongswan \
        && cd /usr/src \
        && curl -SOL "https://download.strongswan.org/strongswan-$STRONGSWAN_VERSION.tar.gz.sig" \
        && curl -SOL "https://download.strongswan.org/strongswan-$STRONGSWAN_VERSION.tar.gz" \
        && export GNUPGHOME="$(mktemp -d)" \
        && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
        && gpg --batch --verify strongswan-$STRONGSWAN_VERSION.tar.gz.sig strongswan-$STRONGSWAN_VERSION.tar.gz \
        && tar -zxf strongswan-$STRONGSWAN_VERSION.tar.gz -C /usr/src/strongswan --strip-components 1 \
        && cd /usr/src/strongswan \
        && ./configure --prefix=/usr --sysconfdir=/etc \
                --enable-openssl \
                --enable-bypass-lan \
                --enable-gcm \
                --enable-log-thread-ids \
                --enable-newhope \
                --enable-sha3 \
#                --disable-swanctl \
        && make -j \
        && make install \
        && rm -rf "/usr/src/strongswan/*"
RUN apt-get install -y traceroute tcpdump net-tools
COPY ./start.sh /docker/start

CMD ["/bin/bash", "/docker/start"]
