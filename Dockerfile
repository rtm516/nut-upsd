ARG NUT_VERSION=2.8.5

# --- Builder ---
FROM alpine:latest AS builder

ARG NUT_VERSION
ENV NUT_VERSION=${NUT_VERSION}

# Build deps from Alpine's official APKBUILD for nut
# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/community/nut/APKBUILD
RUN apk add --no-cache \
    build-base \
    autoconf automake libtool \
    openssl-dev \
    nss-dev \
    libusb-dev \
    hidapi-dev \
    net-snmp-dev \
    neon-dev \
    libmodbus-dev \
    i2c-tools-dev \
    curl

RUN addgroup -S nut && adduser -S -G nut -h /var/run/nut nut

WORKDIR /tmp

RUN curl -fsSL "https://github.com/networkupstools/nut/releases/download/v${NUT_VERSION}/nut-${NUT_VERSION}.tar.gz" \
    -o nut.tar.gz \
    && tar xzf nut.tar.gz \
    && rm nut.tar.gz

WORKDIR /tmp/nut-${NUT_VERSION}

# Configure flags aligned with Alpine's official nut APKBUILD
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/nut \
    --datadir=/usr/share/nut \
    --libexecdir=/usr/lib/nut \
    --with-drvpath=/usr/lib/nut \
    --with-statepath=/var/run/nut \
    --with-altpidpath=/var/run/nut \
    --with-user=nut \
    --with-group=nut \
    --without-all \
    --with-serial \
    --with-usb \
    --with-snmp \
    --with-neon \
    --with-modbus \
    --with-i2c \
    --with-openssl \
    --with-nss \
    --with-libltdl \
    --with-drivers=all \
    --without-powerman \
    --without-ipmi \
    --without-freeipmi \
    --without-upower \
    --disable-static

RUN make -j"$(nproc)"
RUN make DESTDIR=/build install

# --- Container ---
FROM alpine:latest

# Runtime libs matching Alpine's nut package dependencies
RUN apk add --no-cache \
    openssl \
    nss \
    libusb \
    hidapi \
    net-snmp-libs \
    neon \
    libmodbus \
    i2c-tools \
    libltdl \
    tini

RUN addgroup -S nut && adduser -S -G nut -h /var/run/nut nut

COPY --from=builder /build/usr /usr
COPY --from=builder /build/etc/nut /etc/nut

# state directory for upsd pid/socket
RUN mkdir -p /var/run/nut \
    && chown -R nut:nut /var/run/nut /etc/nut

ENV NUT_QUIET_INIT_SSL=true \
    NUT_QUIET_INIT_UPSNOTIFY=true

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3493

ENTRYPOINT ["tini", "--"]
CMD ["/entrypoint.sh"]
