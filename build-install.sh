#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/prj/util/bin"
ENTRY_PATH="$SCRIPT_DIR/dist/entry.js"
WRAPPER_PATH="$BIN_DIR/clawdbot"

cd "$SCRIPT_DIR"

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
echo "Installed clawdbot:"
"$WRAPPER_PATH" --help 2>&1 | head -5
