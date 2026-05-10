#!/bin/sh
set -e

CONFDIR="/etc/nut"

# nut.conf
cat > "$CONFDIR/nut.conf" << EOF
MODE=netserver
EOF

# upsd.conf
UPSD_LISTEN="${UPSD_LISTEN:-0.0.0.0}"
UPSD_PORT="${UPSD_PORT:-3493}"
UPSD_MAXAGE="${UPSD_MAXAGE:-15}"

cat > "$CONFDIR/upsd.conf" << EOF
LISTEN ${UPSD_LISTEN} ${UPSD_PORT}
MAXAGE ${UPSD_MAXAGE}
EOF

# upsd.users (from env vars)
# Only generate if not bind-mounted (allows full override)
if [ ! -f "$CONFDIR/upsd.users" ] || [ "${GENERATE_USERS:-true}" = "true" ]; then
    UPSMON_USER="${UPSMON_USER:-upsmon}"
    UPSMON_PASSWORD="${UPSMON_PASSWORD:-}"
    UPSMON_ROLE="${UPSMON_ROLE:-primary}"

    if [ -z "$UPSMON_PASSWORD" ]; then
        echo "WARN: UPSMON_PASSWORD not set — generating random password"
        UPSMON_PASSWORD=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 20)
        echo "Generated password for ${UPSMON_USER}: ${UPSMON_PASSWORD}"
    fi

    cat > "$CONFDIR/upsd.users" << EOF
[${UPSMON_USER}]
    password = ${UPSMON_PASSWORD}
    upsmon ${UPSMON_ROLE}
EOF
fi

# Make sure we have an ups.conf before starting (required mount)
if [ ! -f "$CONFDIR/ups.conf" ]; then
    echo "ERROR: No ups.conf found. Mount your UPS config to $CONFDIR/ups.conf"
    echo "       Example: -v ./ups.conf:/etc/nut/ups.conf:ro"
    exit 1
fi

# Fix any ownership issues on the config directory
chown -R nut:nut /var/run/nut /var/state/ups "$CONFDIR"

# Start upsd
echo "Starting NUT drivers..."
/usr/sbin/upsdrvctl -u root start || echo "WARN: Driver start failed (check ups.conf)"

echo "Starting upsd on ${UPSD_LISTEN}:${UPSD_PORT}..."
exec /usr/sbin/upsd -u nut -D -F