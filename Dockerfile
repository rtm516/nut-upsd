ARG NUT_VERSION=2.8.5

# --- Builder ---
FROM alpine:latest AS builder

ARG NUT_VERSION
ENV NUT_VERSION=${NUT_VERSION}

# Build deps derived from NUT CI (docs/config-prereqs.txt + .github/workflows/01-make-dist.yml)
# translated from Ubuntu package names to Alpine equivalents
RUN apk add --no-cache \
    build-base \
    autoconf automake libtool libltdl \
    pkgconf \
    linux-headers \
    perl curl \
    openssl-dev \
    libusb-dev \
    libusb-compat-dev \
    hidapi-dev \
    net-snmp-dev \
    neon-dev \
    libmodbus-dev \
    libgpiod-dev \
    glib-dev \
    i2c-tools-dev

RUN addgroup -S nut && adduser -S -G nut -h /var/run/nut nut

WORKDIR /tmp

RUN curl -fsSL "https://github.com/networkupstools/nut/releases/download/v${NUT_VERSION}/nut-${NUT_VERSION}.tar.gz" \
    -o nut.tar.gz \
    && tar xzf nut.tar.gz \
    && rm nut.tar.gz

WORKDIR /tmp/nut-${NUT_VERSION}

# --with-all=auto: enable every feature whose deps are present, skip the rest
# Mirrors NUT CI's own approach (configure --with-all)
# We have to disable a few features manually since their deps aren't available in Alpine (powerman, ipmi, freeipmi, avahi)
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/nut \
    --datadir=/usr/share/nut \
    --with-user=nut \
    --with-group=nut \
    --with-all=auto \
    --with-ssl=openssl \
    --with-drivers=all \
    --without-doc \
    --without-cgi \
    --without-python \
    --without-python2 \
    --without-python3 \
    --without-powerman \
    --without-ipmi \
    --without-freeipmi \
    --without-avahi \
    --disable-static

RUN make -j"$(nproc)"
RUN make DESTDIR=/build install

# --- Container ---
FROM alpine:latest

# Runtime libs matching what was linked at build time
RUN apk add --no-cache \
    openssl \
    libusb \
    libusb-compat \
    hidapi \
    net-snmp-libs \
    neon \
    libmodbus \
    libgpiod \
    libltdl \
    glib \
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
