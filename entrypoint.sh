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

# Ensure sonarr user/group have the correct IDs
CURRENT_PUID=$(id -u sonarr 2>/dev/null || echo "")
CURRENT_PGID=$(id -g sonarr 2>/dev/null || echo "")

# If sonarr user already exists but with wrong IDs, we need to delete it first
if [ -n "$CURRENT_PUID" ] && [ "$PUID" != "$CURRENT_PUID" ]; then
    echo "Removing existing sonarr user with UID $CURRENT_PUID"
    deluser sonarr 2>/dev/null || true
    CURRENT_PUID=""
fi

if [ -n "$CURRENT_PGID" ] && [ "$PGID" != "$CURRENT_PGID" ]; then
    echo "Removing existing sonarr group with GID $CURRENT_PGID"
    delgroup sonarr 2>/dev/null || true
    CURRENT_PGID=""
fi

# Remove any existing group/user with target PGID/PUID to free them up
if getent group "$PGID" >/dev/null 2>&1; then
    CONFLICTING_GROUP=$(getent group "$PGID" | cut -d: -f1)
    if [ "$CONFLICTING_GROUP" != "sonarr" ]; then
        echo "Removing group '$CONFLICTING_GROUP' using GID $PGID"
        delgroup "$CONFLICTING_GROUP" 2>/dev/null || true
    fi
fi

if getent passwd "$PUID" >/dev/null 2>&1; then
    CONFLICTING_USER=$(getent passwd "$PUID" | cut -d: -f1)
    if [ "$CONFLICTING_USER" != "sonarr" ]; then
        echo "Removing user '$CONFLICTING_USER' using UID $PUID"
        deluser "$CONFLICTING_USER" 2>/dev/null || true
    fi
fi

# Create sonarr group if it doesn't exist
if ! getent group sonarr >/dev/null 2>&1; then
    echo "Creating sonarr group with GID $PGID"
    addgroup -g "$PGID" sonarr
fi

# Create sonarr user if it doesn't exist
if ! getent passwd sonarr >/dev/null 2>&1; then
    echo "Creating sonarr user with UID $PUID"
    adduser -u "$PUID" -G sonarr -h /config -D sonarr
fi

# Ensure ownership of critical directories
echo "Setting ownership of /config, /app, and /run/sonarr-temp to $PUID:$PGID"
chown -R sonarr:sonarr /config /app /run/sonarr-temp 2>/dev/null || true

# Execute Sonarr as the sonarr user
echo "Starting Sonarr..."
exec su-exec sonarr /app/sonarr/bin/Sonarr "$@"
