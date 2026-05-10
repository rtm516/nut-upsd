ARG NUT_VERSION=2.8.5

# Builder
FROM alpine:latest AS builder

ARG NUT_VERSION
ENV NUT_VERSION=${NUT_VERSION}

RUN apk add --no-cache \
    build-base \
    autoconf automake libtool \
    openssl-dev \
    libusb-dev \
    net-snmp-dev \
    neon-dev \
    curl

RUN addgroup -S nut && adduser -S -G nut -h /var/run/nut nut

WORKDIR /tmp

RUN curl -fsSL "https://github.com/networkupstools/nut/releases/download/v${NUT_VERSION}/nut-${NUT_VERSION}.tar.gz" \
    -o nut.tar.gz \
    && tar xzf nut.tar.gz \
    && rm nut.tar.gz

WORKDIR /tmp/nut-${NUT_VERSION}

RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/nut \
    --with-user=nut \
    --with-group=nut \
    --with-openssl \
    --with-usb=auto \
    --with-snmp=auto \
    --with-neon=auto \
    --with-drivers=all \
    --datadir=/usr/share/nut \
    --without-doc \
    --without-python \
    --without-python2 \
    --without-python3 \
    --without-cgi \
    --without-avahi \
    --without-powerman \
    --without-ipmi \
    --without-freeipmi \
    --disable-static \
    && make -j"$(nproc)" \
    && make DESTDIR=/build install

# Container
FROM alpine:latest

RUN apk add --no-cache \
    openssl \
    libusb \
    net-snmp-libs \
    neon \
    tini

RUN addgroup -S nut && adduser -S -G nut -h /var/run/nut nut

COPY --from=builder /build/usr /usr
COPY --from=builder /build/etc/nut /etc/nut

# state directory for upsd pid/socket
RUN mkdir -p /var/run/nut /var/state/ups \
    && chown -R nut:nut /var/run/nut /var/state/ups /etc/nut

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3493

ENTRYPOINT ["tini", "--"]
CMD ["/entrypoint.sh"]