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

# Ensure ownership of critical directories using numeric IDs
echo "Setting ownership of /config, /app, and /run/sonarr-temp to $PUID:$PGID"
chown -R "$PUID:$PGID" /config /app /run/sonarr-temp 2>/dev/null || true

# Execute Sonarr as the specified UID:GID
echo "Starting Sonarr as UID=$PUID, GID=$PGID..."
exec su-exec "$PUID:$PGID" /app/sonarr/bin/Sonarr "$@"
