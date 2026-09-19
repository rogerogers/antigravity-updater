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
SHOW_CHANGELOG_ONLY=false
NO_CHANGELOG=false
CUSTOM_URL=""

# Parse command line flags
for arg in "$@"; do
    case "$arg" in
        -f|--force)
            FORCE_UPDATE=true
            ;;
        -c|--changelog)
            SHOW_CHANGELOG_ONLY=true
            ;;
        --no-changelog)
            NO_CHANGELOG=true
            ;;
        -h|--help)
            echo "Usage: update-antigravity [options] [custom_url]"
            echo ""
            echo "Options:"
            echo "  -f, --force         Reinstall or force-upgrade even if already on the latest version"
            echo "  -c, --changelog     Show release notes / changelog and exit"
            echo "  --no-changelog      Skip displaying changelog after update"
            echo "  -h, --help          Show this help message"
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

show_changelog() {
    local from_ver="${1:-none}"
    local to_ver="${2:-}"

    if ! command -v python3 >/dev/null 2>&1; then
        echo ""
        echo -e "${CYAN}🔗 View full changelog at: ${YELLOW}https://antigravity.google/changelog${NC}"
        return 0
    fi

    python3 - "$from_ver" "$to_ver" << 'PYEOF' 2>/dev/null || true
import sys, urllib.request, gzip, re, html, shutil, textwrap

from_version = sys.argv[1] if len(sys.argv) > 1 else "none"
to_version = sys.argv[2] if len(sys.argv) > 2 else ""

url = "https://antigravity.google/changelog"
req = urllib.request.Request(
    url,
    headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)",
        "Accept-Encoding": "gzip",
    },
)

try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = resp.read()
        if resp.info().get("Content-Encoding") == "gzip":
            data = gzip.decompress(data)
        content = data.decode("utf-8")
except Exception as err:
    print(f"\033[1;33mNotice: Could not fetch changelog ({err}).\033[0m")
    sys.exit(0)

sections = content.split('class="section-row-wrapper')
entries = []
for sec in sections[1:]:
    v_match = re.search(r"version=([0-9]+\.[0-9]+\.[0-9]+)", sec)
    if not v_match:
        continue
    ver = v_match.group(1)

    date_match = re.search(r"</a><br[^>]*>\s*([A-Za-z0-9, ]+?)\s*</p>", sec)
    date = date_match.group(1).strip() if date_match else ""

    title_match = re.search(r"<h3[^>]*>(.*?)</h3>", sec)
    title = html.unescape(title_match.group(1).strip()) if title_match else ""

    p_match = re.search(r"<div class=\"changes[^\"]*\"><p>(.*?)</p></div>", sec, re.DOTALL)
    summary = html.unescape(re.sub(r"<[^>]+>", "", p_match.group(1)).strip()) if p_match else ""

    details = re.findall(r"<summary[^>]*>(.*?)</summary>\s*<ul[^>]*>(.*?)</ul>", sec, re.DOTALL)
    sections_dict = {}
    for s_title, items in details:
        s_title_clean = html.unescape(re.sub(r"<[^>]+>", "", s_title)).strip()
        clean_items = [
            html.unescape(re.sub(r"<[^>]+>", "", it)).strip()
            for it in re.findall(r"<li[^>]*>(.*?)</li>", items, re.DOTALL)
        ]
        if clean_items:
            sections_dict[s_title_clean] = clean_items

    entries.append({
        "version": ver,
        "date": date,
        "title": title,
        "summary": summary,
        "details": sections_dict,
    })

to_show = []
if from_version and from_version not in ("none", "unknown", to_version):
    for e in entries:
        if e["version"] == from_version:
            break
        to_show.append(e)
        if len(to_show) >= 5:
            break

if not to_show:
    if to_version:
        for e in entries:
            if e["version"] == to_version:
                to_show = [e]
                break
    if not to_show and entries:
        to_show = [entries[0]]

term_width = min(shutil.get_terminal_size((80, 20)).columns, 100)
sep = "=" * term_width
sub_sep = "-" * term_width

BOLD = "\033[1m"
GREEN = "\033[1;32m"
BLUE = "\033[1;34m"
YELLOW = "\033[1;33m"
CYAN = "\033[1;36m"
NC = "\033[0m"

print(f"\n{BLUE}{sep}{NC}")
title_line = "Release Notes & Changelog"
print(f"{BOLD}{title_line.center(term_width)}{NC}")
print(f"{BLUE}{sep}{NC}")

for idx, e in enumerate(to_show):
    if idx > 0:
        print(f"\n{BLUE}{sub_sep}{NC}")
    ver_header = f"Version {e['version']}" + (f" ({e['date']})" if e['date'] else "")
    print(f"\n{CYAN}{BOLD}📦 {ver_header}{NC}")
    if e["title"]:
        print(f"{BOLD}{e['title']}{NC}")
    if e["summary"]:
        print("")
        print(textwrap.fill(e["summary"], width=term_width))

    for cat_name, items in e["details"].items():
        if not items:
            continue
        cat_icon = "✨" if "Improvement" in cat_name else ("🐛" if "Fix" in cat_name else "📌")
        cat_color = GREEN if "Improvement" in cat_name else (YELLOW if "Fix" in cat_name else CYAN)
        print(f"\n{cat_color}{BOLD}{cat_icon} {cat_name}:{NC}")
        for item in items:
            wrapped = textwrap.fill(item, width=term_width, initial_indent="  • ", subsequent_indent="    ")
            print(wrapped)

print(f"\n{BLUE}{sep}{NC}")
print(f"🔗 View online: {YELLOW}https://antigravity.google/changelog{NC}")
print(f"{BLUE}{sep}{NC}\n")
PYEOF
}

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

# Handle --changelog flag
if [ "$SHOW_CHANGELOG_ONLY" = true ]; then
    TARGET_VER="$REMOTE_VERSION"
    if [ "$TARGET_VER" = "unknown" ] && [ "$LOCAL_VERSION" != "none" ]; then
        TARGET_VER="$LOCAL_VERSION"
    fi
    show_changelog "" "$TARGET_VER"
    exit 0
fi

# 3. Version Comparison
if [ "$FORCE_UPDATE" = false ] && [ "$LOCAL_VERSION" != "none" ] && [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo -e "${GREEN}✓ Antigravity is already up to date (version $LOCAL_VERSION).${NC}"
    echo -e "No upgrade needed. (Use ${YELLOW}--force${NC} to reinstall if needed)."
    echo -e "To view release notes: ${YELLOW}update-antigravity --changelog${NC}"
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

# 9. Show Changelog
if [ "$NO_CHANGELOG" = false ]; then
    show_changelog "$LOCAL_VERSION" "$REMOTE_VERSION"
fi
