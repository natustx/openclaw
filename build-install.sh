#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/prj/util/bin"
ENTRY_PATH="$SCRIPT_DIR/dist/entry.js"
WRAPPER_PATH="$BIN_DIR/moltbot"
LAUNCHD_LABEL="com.moltbot.gateway"

cd "$SCRIPT_DIR"

# Check if daemon is running before build
DAEMON_WAS_RUNNING=false
if launchctl print "gui/$UID/$LAUNCHD_LABEL" &>/dev/null; then
    DAEMON_WAS_RUNNING=true
    echo "Daemon is running - will stop before build and restart after"
fi

# Stop daemon if running
if [ "$DAEMON_WAS_RUNNING" = true ]; then
    echo "Stopping daemon..."
    launchctl bootout "gui/$UID/$LAUNCHD_LABEL" 2>/dev/null || true
    sleep 1
fi

# Clean build artifacts for idempotent builds
echo "Cleaning dist/..."
rm -rf dist/

echo "Installing dependencies..."
bun install

echo "Building..."
bun run build

# Verify build output exists
if [ ! -f "$ENTRY_PATH" ]; then
    echo "ERROR: Build failed - $ENTRY_PATH not found"
    exit 1
fi

# Ensure bin directory exists
mkdir -p "$BIN_DIR"

# Remove old wrapper (file, symlink, or whatever)
rm -f "$WRAPPER_PATH"

# Create wrapper script using single-quoted heredoc to prevent expansion
cat > "$WRAPPER_PATH" << 'WRAPPER_EOF'
#!/usr/bin/env bash
exec node "ENTRY_PLACEHOLDER" "$@"
WRAPPER_EOF

# Replace placeholder with actual path
sed -i '' "s|ENTRY_PLACEHOLDER|$ENTRY_PATH|g" "$WRAPPER_PATH"

chmod +x "$WRAPPER_PATH"
echo "Created wrapper: $WRAPPER_PATH"

# Verify
echo ""
echo "Installed moltbot:"
"$WRAPPER_PATH" --help 2>&1 | head -5

# Restart daemon if it was running
if [ "$DAEMON_WAS_RUNNING" = true ]; then
    echo ""
    echo "Restarting daemon..."
    "$WRAPPER_PATH" daemon install --force

    # Wait for gateway to start
    echo "Waiting for gateway..."
    for i in {1..10}; do
        if launchctl print "gui/$UID/$LAUNCHD_LABEL" 2>/dev/null | grep -q "state = running"; then
            echo "Daemon restarted successfully"
            break
        fi
        sleep 1
    done

    echo ""
    "$WRAPPER_PATH" daemon status --no-probe
fi
