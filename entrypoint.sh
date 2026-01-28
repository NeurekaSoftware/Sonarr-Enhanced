#!/bin/sh
set -e

# Default values
PUID=${PUID:-1000}
PGID=${PGID:-1000}
TZ=${TZ:-Etc/UTC}

echo "Setting up environment..."

# Create required directories
mkdir -p /run/sonarr-temp /config/xdg

# Set timezone
if [ -n "$TZ" ]; then
    if [ -f "/usr/share/zoneinfo/$TZ" ]; then
        ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
        echo "$TZ" > /etc/timezone
        echo "Timezone set to: $TZ"
    else
        echo "Warning: Timezone '$TZ' not found, using UTC"
    fi
fi

# Handle root user (PUID=0 and/or PGID=0)
if [ "$PUID" = "0" ] || [ "$PGID" = "0" ]; then
    echo "Running as root (PUID=$PUID, PGID=$PGID)"
    echo "Warning: Running as root is not recommended for security reasons"

    # Ensure ownership of critical directories
    echo "Setting ownership of /config, /app, and /run/sonarr-temp to root"
    chown -R root:root /config /app /run/sonarr-temp 2>/dev/null || true

    # Execute Sonarr as root
    echo "Starting Sonarr as root..."
    exec /app/sonarr/bin/Sonarr "$@"
fi

# Update user/group IDs if they differ from defaults
CURRENT_PUID=$(id -u sonarr 2>/dev/null || echo "1000")
CURRENT_PGID=$(id -g sonarr 2>/dev/null || echo "1000")

if [ "$PGID" != "$CURRENT_PGID" ]; then
    echo "Changing GID from $CURRENT_PGID to $PGID"
    delgroup sonarr 2>/dev/null || true
    addgroup -g "$PGID" sonarr
fi

if [ "$PUID" != "$CURRENT_PUID" ]; then
    echo "Changing UID from $CURRENT_PUID to $PUID"
    deluser sonarr 2>/dev/null || true
    adduser -u "$PUID" -G sonarr -h /config -D sonarr
fi

# Ensure ownership of critical directories
echo "Setting ownership of /config, /app, and /run/sonarr-temp to $PUID:$PGID"
chown -R sonarr:sonarr /config /app /run/sonarr-temp 2>/dev/null || true

# Execute Sonarr as the sonarr user
echo "Starting Sonarr..."
exec su-exec sonarr /app/sonarr/bin/Sonarr "$@"
