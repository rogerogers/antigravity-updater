# Antigravity Updater

A robust, one-click Linux upgrade script for **Google Antigravity** (desktop application).

## Features

- **Official Source Only**: Dynamically resolves the latest release directly from `https://antigravity.google/download` and Google Cloud Storage (`storage.googleapis.com/antigravity-public`).
- **Smart Version Comparison**: Checks your local version against the latest remote release before downloading, avoiding redundant 170MB+ transfers when already up-to-date.
- **SUID Sandbox Setup**: Automatically configures `chrome-sandbox` with root ownership and `4755` permissions for secure, issue-free Chromium runtime.
- **Safety Backup**: Creates an atomic backup (`/usr/local/antigravity.bak`) of your existing install before applying updates.
- **Force Upgrade**: Supports `--force` / `-f` flag to reinstall or repair existing versions.

## Installation

Clone the repository and run `install.sh`:

```bash
git clone https://github.com/rogerogers/antigravity-updater.git
cd antigravity-updater
./install.sh
```

Or copy the script directly into your `PATH`:

```bash
mkdir -p ~/.local/bin
cp update-antigravity.sh ~/.local/bin/update-antigravity
chmod +x ~/.local/bin/update-antigravity
```

## Usage

Check and upgrade Antigravity:

```bash
update-antigravity
```

Force reinstall even if already on the latest version:

```bash
update-antigravity --force
```

Pass a custom archive URL:

```bash
update-antigravity https://storage.googleapis.com/.../Antigravity.tar.gz
```

## License

[MIT](LICENSE)
