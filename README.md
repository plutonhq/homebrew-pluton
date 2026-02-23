# Homebrew Tap for Pluton

[Pluton](https://usepluton.com) is a self-hosted backup automation software.

This tap contains Homebrew casks for both **Pluton** (free/open-source) and **Pluton PRO** (paid).

## Pluton (Free)

### Installation

```bash
brew install plutonhq/pluton/pluton
```

Or add the tap first:

```bash
brew tap plutonhq/pluton
brew install pluton
```

### After Installation

1. **Access the dashboard** at [http://localhost:5173](http://localhost:5173)
2. **Set up your credentials** via the web interface on first launch
3. **Grant Full Disk Access** (required to back up protected directories):
   - System Settings → Privacy & Security → Full Disk Access
   - Click `+` and add `/opt/pluton/pluton`

### Update

```bash
brew update
brew upgrade pluton
```

### Uninstall

```bash
# Uninstall (keeps your backup data)
brew uninstall pluton

# Uninstall and remove all data
brew uninstall --zap pluton
```

---

## Pluton PRO

Pluton PRO requires a valid license key. Get yours at [usepluton.com](https://usepluton.com).

### Installation

```bash
export HOMEBREW_PLUTON_PRO_LICENSE="YOUR_LICENSE_KEY"
brew install plutonhq/pluton/pluton-pro
```

Or add the tap first:

```bash
brew tap plutonhq/pluton
export HOMEBREW_PLUTON_PRO_LICENSE="YOUR_LICENSE_KEY"
brew install pluton-pro
```

### After Installation

1. **Access the dashboard** at [http://localhost:5173](http://localhost:5173)
2. **Set up your credentials** via the web interface on first launch
3. **Grant Full Disk Access** (required to back up protected directories):
   - System Settings → Privacy & Security → Full Disk Access
   - Click `+` and add `/opt/pluton/pluton`

### Update

```bash
export HOMEBREW_PLUTON_PRO_LICENSE="YOUR_LICENSE_KEY"
brew update
brew upgrade pluton-pro
```

### Uninstall

```bash
# Uninstall (keeps your backup data and credentials)
brew uninstall pluton-pro

# Uninstall and remove all data
brew uninstall --zap pluton-pro
```

---

## Service Management

Both Pluton and Pluton PRO use the same service commands:

```bash
# Restart
sudo launchctl kickstart -k system/com.plutonhq.pluton

# Stop
sudo launchctl bootout system/com.plutonhq.pluton

# Start
sudo launchctl bootstrap system /Library/LaunchDaemons/com.plutonhq.pluton.plist
```

## Logs

```bash
tail -f /var/lib/pluton/logs/stdout.log
tail -f /var/lib/pluton/logs/stderr.log
```

## License

Pluton is licensed under [Apache-2.0](https://github.com/plutonhq/pluton/blob/main/LICENSE). Pluton PRO requires a commercial license.
