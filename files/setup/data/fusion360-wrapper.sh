#!/usr/bin/env bash

# Fusion 360 wrapper for Distrobox containers
# Handles ownership, user mapping, persistent data symlinks, then launches Fusion.

export HOME="/app"

WINEPREFIX="/app/.autodesk_fusion/wineprefixes/default"
WINE_USERS="$WINEPREFIX/drive_c/users"
CURRENT_USER="$(whoami)"
BUILD_USER="root"

# Real home directory (host, mounted by Distrobox)
REAL_HOME="$(getent passwd "$CURRENT_USER" | cut -d: -f6)"
FUSION_DATA="$REAL_HOME/.fusion360"

# --- First run: fix ownership (built as root, Wine needs current user as owner) ---
if [ ! -f /app/.owner_fixed ]; then
    echo "First run: fixing /app ownership for $CURRENT_USER (this may take a moment)..."
    sudo chown -R "$CURRENT_USER":"$CURRENT_USER" /app
    touch /app/.owner_fixed
fi

# --- Wine user mapping ---
# Build was done as root; ensure current user has a profile in the wineprefix
if [ "$CURRENT_USER" != "$BUILD_USER" ] && [ ! -e "$WINE_USERS/$CURRENT_USER" ]; then
    ln -sf "$BUILD_USER" "$WINE_USERS/$CURRENT_USER"
fi

USER_DIR="$WINE_USERS/$BUILD_USER"

# --- Create persistent directories on host ---
mkdir -p \
    "$FUSION_DATA/Documents" \
    "$FUSION_DATA/Autodesk/Roaming" \
    "$FUSION_DATA/Autodesk/Local"

# --- Helper: migrate existing data then symlink ---
link_persist() {
    local target="$1"  # path inside container
    local persist="$2"  # path on host

    # Already a symlink, nothing to do
    [ -L "$target" ] && return

    # Move existing data to host if present
    if [ -d "$target" ]; then
        cp -an "$target/." "$persist/" 2>/dev/null
        rm -rf "$target"
    fi

    mkdir -p "$(dirname "$target")"
    ln -sf "$persist" "$target"
}

# --- Symlink user data to host ---

# Documents (STL exports, saved files)
link_persist "$USER_DIR/Documents" "$FUSION_DATA/Documents"

# Autodesk account data and settings (login tokens, preferences)
link_persist "$USER_DIR/AppData/Roaming/Autodesk" "$FUSION_DATA/Autodesk/Roaming"

# Autodesk local cache
link_persist "$USER_DIR/AppData/Local/Autodesk" "$FUSION_DATA/Autodesk/Local"

exec /app/.autodesk_fusion/bin/autodesk_fusion_launcher.sh "$@"
