# Homebrew Tap for Pluton

[Pluton](https://usepluton.com) is a self-hosted backup automation software.

This tap contains Homebrew casks for **Pluton** (free/open-source), **Pluton PRO** (paid), and **Pluton Agent** (paid).

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

## Pluton Agent

Pluton Agent is a backup agent that runs on remote devices and communicates with your Pluton server. It handles incremental backups (Restic), file sync (Rclone), and remote operations. Requires a valid license key and an agent configuration file (downloaded from the Pluton dashboard when adding a new device).

### Installation

```bash
export HOMEBREW_PLUTON_AGENT_LICENSE="YOUR_LICENSE_KEY"
export HOMEBREW_PLUTON_AGENT_CONFIG="/path/to/agent-config.json"
brew install plutonhq/pluton/pluton-agent
```

Or add the tap first:

```bash
brew tap plutonhq/pluton
export HOMEBREW_PLUTON_AGENT_LICENSE="YOUR_LICENSE_KEY"
export HOMEBREW_PLUTON_AGENT_CONFIG="/path/to/agent-config.json"
brew install pluton-agent
```

### After Installation

1. **Verify the connection** from the Pluton dashboard — the agent should appear online
2. **Grant Full Disk Access** (required to back up protected directories):
   - System Settings → Privacy & Security → Full Disk Access
   - Click `+` and add `/usr/local/pluton-agent/bin/pluton-agent`

### Update

On upgrade, only the license key is needed — existing agent credentials are preserved automatically:

```bash
export HOMEBREW_PLUTON_AGENT_LICENSE="YOUR_LICENSE_KEY"
brew update
brew upgrade pluton-agent
```

### Uninstall

```bash
# Uninstall (keeps your data and configuration)
brew uninstall pluton-agent

# Uninstall and remove all data
brew uninstall --zap pluton-agent
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

**Pluton / Pluton PRO:**
```bash
tail -f /var/lib/pluton/logs/stdout.log
tail -f /var/lib/pluton/logs/stderr.log
```

**Pluton Agent:**
```bash
tail -f /var/log/pluton-agent.log
tail -f /var/log/pluton-agent.error.log
```

### Pluton Agent Service

```bash
# Restart
sudo launchctl kickstart -k system/com.pluton.agent

# Stop
sudo launchctl bootout system/com.pluton.agent

# Start
sudo launchctl bootstrap system /Library/LaunchDaemons/com.pluton.agent.plist
```

## License

Pluton is licensed under [Apache-2.0](https://github.com/plutonhq/pluton/blob/main/LICENSE). Pluton PRO and Pluton Agent require a commercial license.
