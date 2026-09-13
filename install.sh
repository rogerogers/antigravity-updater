#!/usr/bin/env bash
#
# Installer for Antigravity Updater
#
set -euo pipefail

TARGET_DIR="${HOME}/.local/bin"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/update-antigravity.sh"

mkdir -p "$TARGET_DIR"
cp "$SCRIPT_PATH" "$TARGET_DIR/update-antigravity"
chmod +x "$TARGET_DIR/update-antigravity"

echo "✓ Successfully installed 'update-antigravity' to $TARGET_DIR"
if [[ ":$PATH:" != *":$TARGET_DIR:"* ]]; then
    echo "Notice: $TARGET_DIR is not in your PATH. Add it to ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
