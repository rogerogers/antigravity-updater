#!/usr/bin/env bash
#
# Antigravity Dynamic One-Click Upgrade Script
#
# 1. Compares local installed version with the latest remote version from the official site.
# 2. Skips download if already up to date (unless --force / -f is specified).
# 3. Downloads, verifies, and installs new versions safely with proper sandbox permissions.
#

set -euo pipefail

INSTALL_DIR="/usr/local/antigravity"
STAGING_DIR="/tmp/antigravity-upgrade-$$"
DOWNLOAD_FILE="$STAGING_DIR/Antigravity.tar.gz"

FORCE_UPDATE=false
CUSTOM_URL=""

# Parse command line flags
for arg in "$@"; do
    case "$arg" in
        -f|--force)
            FORCE_UPDATE=true
            ;;
        -h|--help)
            echo "Usage: update-antigravity [options] [custom_url]"
            echo ""
            echo "Options:"
            echo "  -f, --force    Reinstall or force-upgrade even if already on the latest version"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        http*://*)
            CUSTOM_URL="$arg"
            ;;
    esac
done

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Antigravity Version Check & Upgrader ===${NC}"

# 1. Detect Local Version
LOCAL_VERSION="none"
if [ -f "$INSTALL_DIR/.version" ]; then
    LOCAL_VERSION=$(cat "$INSTALL_DIR/.version" 2>/dev/null || echo "none")
elif [ -f "$INSTALL_DIR/resources/app.asar" ]; then
    LOCAL_VERSION=$(grep -a -m 1 -o -E '"version":\s*"[0-9]+\.[0-9]+\.[0-9]+"' "$INSTALL_DIR/resources/app.asar" 2>/dev/null | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/' || echo "unknown")
fi

echo -e "Local version:  ${CYAN}$LOCAL_VERSION${NC}"

# 2. Detect Remote Version & URL
echo -e "Checking official release from ${YELLOW}https://antigravity.google/download${NC}..."

if [ -n "$CUSTOM_URL" ]; then
    DOWNLOAD_URL="$CUSTOM_URL"
else
    DOWNLOAD_URL=$(curl --compressed -fsSL https://antigravity.google/download 2>/dev/null | grep -o -E 'https://storage\.googleapis\.com/antigravity-public/antigravity-hub/[^"'\''<> ]+/linux-x64/Antigravity\.tar\.gz' | head -n 1 || true)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}Error: Could not retrieve the official download URL from https://antigravity.google/download.${NC}" >&2
    exit 1
fi

REMOTE_VERSION=$(echo "$DOWNLOAD_URL" | grep -o -E 'antigravity-hub/[0-9]+\.[0-9]+\.[0-9]+' | cut -d'/' -f2 || echo "unknown")
echo -e "Remote version: ${CYAN}$REMOTE_VERSION${NC}"
echo ""

# 3. Version Comparison
if [ "$FORCE_UPDATE" = false ] && [ "$LOCAL_VERSION" != "none" ] && [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}✓ Antigravity is already up to date (version $LOCAL_VERSION).${NC}"
    echo -e "No upgrade needed. (Use ${YELLOW}--force${NC} to reinstall if needed)."
    exit 0
fi

if [ "$FORCE_UPDATE" = true ]; then
    echo -e "${YELLOW}Force update enabled. Proceeding with installation of version $REMOTE_VERSION...${NC}"
else
    echo -e "${GREEN}New version available: $LOCAL_VERSION -> $REMOTE_VERSION${NC}"
    echo -e "Proceeding with upgrade..."
fi
echo ""

# 4. Ensure sudo privileges
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Administrator (sudo) privileges required. You may be prompted for your password.${NC}"
    sudo true
fi

# Prepare staging
cleanup() {
    rm -rf "$STAGING_DIR" 2>/dev/null || true
}
trap cleanup EXIT

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 5. Download Archive
echo -e "${BLUE}[1/4] Downloading package archive ($REMOTE_VERSION)...${NC}"
if command -v curl >/dev/null 2>&1; then
    curl -fL --progress-bar -o "$DOWNLOAD_FILE" "$DOWNLOAD_URL"
elif command -v wget >/dev/null 2>&1; then
    wget --show-progress -q -O "$DOWNLOAD_FILE" "$DOWNLOAD_URL"
else
    echo -e "${RED}Error: Neither curl nor wget was found.${NC}" >&2
    exit 1
fi

# 6. Extract Archive
echo -e "${BLUE}[2/4] Extracting archive...${NC}"
tar -xzf "$DOWNLOAD_FILE" -C "$STAGING_DIR"

EXTRACTED_FOLDER=$(find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type d -name "Antigravity*" | head -n 1)
if [ -z "$EXTRACTED_FOLDER" ] || [ ! -f "$EXTRACTED_FOLDER/antigravity" ]; then
    echo -e "${RED}Error: Extracted archive does not contain the expected Antigravity binaries.${NC}" >&2
    exit 1
fi

# 7. Set Permissions
echo -e "${BLUE}[3/4] Configuring system and sandbox permissions...${NC}"
sudo chown -R root:root "$EXTRACTED_FOLDER"
sudo chmod -R 755 "$EXTRACTED_FOLDER"
if [ -f "$EXTRACTED_FOLDER/chrome-sandbox" ]; then
    sudo chmod 4755 "$EXTRACTED_FOLDER/chrome-sandbox"
fi

# Store version marker
echo "$REMOTE_VERSION" | sudo tee "$EXTRACTED_FOLDER/.version" >/dev/null

# 8. Swap Installation
echo -e "${BLUE}[4/4] Installing update to $INSTALL_DIR...${NC}"
sudo rm -rf "${INSTALL_DIR}.bak"
if [ -d "$INSTALL_DIR" ]; then
    sudo mv "$INSTALL_DIR" "${INSTALL_DIR}.bak"
fi
sudo mv "$EXTRACTED_FOLDER" "$INSTALL_DIR"

echo ""
echo -e "${GREEN}✓ Successfully updated Antigravity to version $REMOTE_VERSION!${NC}"
echo -e "Previous installation backed up to: ${YELLOW}${INSTALL_DIR}.bak${NC}"
echo -e "${GREEN}Please restart Antigravity to load the new version.${NC}"
