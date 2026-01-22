#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DEST="/Applications/Clawdbot.app"
APP_SRC="$SCRIPT_DIR/dist/Clawdbot.app"

cd "$SCRIPT_DIR"

# Check if app is running before build
APP_WAS_RUNNING=false
if pgrep -x "Clawdbot" >/dev/null 2>&1; then
    APP_WAS_RUNNING=true
    echo "Clawdbot is running - will stop before build and restart after"
fi

# Stop app if running
if [ "$APP_WAS_RUNNING" = true ]; then
    echo "Stopping Clawdbot..."
    killall -q Clawdbot 2>/dev/null || true
    sleep 1
fi

echo "Installing dependencies..."
bun install

echo "Building CLI..."
bun run build

echo "Bundling Canvas A2UI..."
pnpm canvas:a2ui:bundle

echo "Building macOS app..."
cd "$SCRIPT_DIR/apps/macos"
rm -rf .build .build-swift .swiftpm 2>/dev/null || true
swift build -q --product Clawdbot

echo "Packaging app..."
cd "$SCRIPT_DIR"
SKIP_TSC=1 ALLOW_ADHOC_SIGNING=1 "$SCRIPT_DIR/scripts/package-mac-app.sh"

# Verify build output exists
if [ ! -d "$APP_SRC" ]; then
    echo "ERROR: Build failed - $APP_SRC not found"
    exit 1
fi

# Remove old app and install new one
echo "Installing to $APP_DEST..."
rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"

echo ""
echo "Installed Clawdbot.app to $APP_DEST"

# Restart app if it was running
if [ "$APP_WAS_RUNNING" = true ]; then
    echo ""
    echo "Restarting Clawdbot..."
    open "$APP_DEST"

    # Wait for app to start
    sleep 2
    if pgrep -x "Clawdbot" >/dev/null 2>&1; then
        echo "Clawdbot restarted successfully"
    else
        echo "WARN: Clawdbot may not have started - check manually"
    fi
fi
