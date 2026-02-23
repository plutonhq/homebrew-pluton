cask "pluton" do
  version "0.5.3"

  on_arm do
    sha256 "1589bdee3bd7073177a6f2be9533a20016a20b71ab2a6701cc7cfbd5b30c6229"
    url "https://github.com/plutonhq/pluton/releases/download/pluton-v#{version}/pluton-macos-arm64.tar.gz",
        verified: "github.com/plutonhq/pluton/"
  end

  on_intel do
    sha256 "e94907e1b1d112f9c7a023122638a6d6d3d57de5722332ef9620a2946f79244f"
    url "https://github.com/plutonhq/pluton/releases/download/pluton-v#{version}/pluton-macos-x64.tar.gz",
        verified: "github.com/plutonhq/pluton/"
  end

  name "Pluton"
  desc "Self-hosted backup automation software"
  homepage "https://usepluton.com"

  depends_on macos: ">= :monterey"

  # Install: copy files to /opt/pluton, create data dirs, install LaunchDaemon
  postflight do
    # Determine the extracted directory (arm64 or x64)
    extracted_dir = if Hardware::CPU.arm?
      "#{staged_path}/pluton-macos-arm64"
    else
      "#{staged_path}/pluton-macos-x64"
    end

    # Create install directory
    system_command "/bin/mkdir", args: ["-p", "/opt/pluton"], sudo: true

    # Copy all files from extracted tarball to install dir
    system_command "/bin/cp", args: ["-R", "#{extracted_dir}/.", "/opt/pluton/"], sudo: true

    # Make executable
    system_command "/bin/chmod", args: ["+x", "/opt/pluton/pluton"], sudo: true

    # Make bundled binaries executable
    system_command "/bin/chmod", args: ["-R", "+x", "/opt/pluton/binaries/"], sudo: true

    # Create service wrapper script that sets up the macOS keychain before starting Pluton.
    # LaunchDaemons run as root, which has no default keychain — @napi-rs/keyring needs one.
    # We add the keychain to BOTH system and user domain search lists because
    # SecItemCopyMatching (used by @napi-rs/keyring) searches the user domain by default.
    wrapper_content = <<~SH
      #!/bin/bash
      set -e
      export HOME=/var/root
      KEYCHAIN_DIR="/var/root/Library/Keychains"
      KEYCHAIN_PATH="${KEYCHAIN_DIR}/pluton.keychain-db"
      KEYCHAIN_PASSWORD="pluton-service-keychain"
      mkdir -p "${KEYCHAIN_DIR}"
      if [ ! -f "${KEYCHAIN_PATH}" ]; then
          security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
      fi
      security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
      security set-keychain-settings "${KEYCHAIN_PATH}"
      EXISTING_USER_KC=$(security list-keychains -d user 2>/dev/null | tr -d '"' | xargs)
      if ! echo "${EXISTING_USER_KC}" | grep -q "pluton.keychain-db"; then
          security list-keychains -d user -s "${KEYCHAIN_PATH}" ${EXISTING_USER_KC}
      fi
      security list-keychains -d system -s "${KEYCHAIN_PATH}"
      security default-keychain -s "${KEYCHAIN_PATH}"
      exec /opt/pluton/pluton
    SH
    wrapper_path = "/opt/pluton/pluton-service.sh"
    system_command "/bin/bash",
                   args: ["-c", "cat > #{wrapper_path} << 'WRAPPER_EOF'\n#{wrapper_content}WRAPPER_EOF"],
                   sudo: true
    system_command "/bin/chmod", args: ["+x", wrapper_path], sudo: true

    # Set up the root keychain now so it's ready for the service.
    # HOME must be set to /var/root because sudo -E preserves the calling user's HOME,
    # and security default-keychain writes to $HOME which root doesn't own.
    # Add to both system and user domain search lists so SecItemCopyMatching can find credentials.
    system_command "/bin/bash", args: ["-c",
      "export HOME=/var/root && " \
      "mkdir -p /var/root/Library/Keychains && " \
      "KC=/var/root/Library/Keychains/pluton.keychain-db && " \
      "([ -f \"$KC\" ] || security create-keychain -p pluton-service-keychain \"$KC\") && " \
      "security unlock-keychain -p pluton-service-keychain \"$KC\" && " \
      "security set-keychain-settings \"$KC\" && " \
      "EXISTING=$(security list-keychains -d user 2>/dev/null | tr -d '\"' | xargs) && " \
      "echo \"$EXISTING\" | grep -q pluton.keychain-db || " \
      "security list-keychains -d user -s \"$KC\" $EXISTING; " \
      "security list-keychains -d system -s \"$KC\" && " \
      "security default-keychain -s \"$KC\""
    ], sudo: true

    # Create data directories
    [
      "/var/lib/pluton",
      "/var/lib/pluton/config",
      "/var/lib/pluton/db",
      "/var/lib/pluton/logs",
      "/var/lib/pluton/backups",
      "/var/lib/pluton/progress",
      "/var/lib/pluton/rescue",
      "/var/lib/pluton/restore",
      "/var/lib/pluton/stats",
      "/var/lib/pluton/sync",
    ].each do |dir|
      system_command "/bin/mkdir", args: ["-p", dir], sudo: true
    end

    # Write default config.json (only if it doesn't already exist)
    config_path = "/var/lib/pluton/config/config.json"
    unless File.exist?(config_path)
      config_content = '{"SERVER_PORT": 5173, "MAX_CONCURRENT_BACKUPS": 2}'
      system_command "/bin/bash",
                     args: ["-c", "echo '#{config_content}' > #{config_path}"],
                     sudo: true
    end

    # Install LaunchDaemon plist
    plist_content = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>com.plutonhq.pluton</string>
          <key>ProgramArguments</key>
          <array>
              <string>/bin/bash</string>
              <string>/opt/pluton/pluton-service.sh</string>
          </array>
          <key>WorkingDirectory</key>
          <string>/opt/pluton</string>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>EnvironmentVariables</key>
          <dict>
              <key>PLUTON_DATA_DIR</key>
              <string>/var/lib/pluton</string>
              <key>NODE_ENV</key>
              <string>production</string>
          </dict>
          <key>StandardOutPath</key>
          <string>/var/lib/pluton/logs/stdout.log</string>
          <key>StandardErrorPath</key>
          <string>/var/lib/pluton/logs/stderr.log</string>
          <key>ThrottleInterval</key>
          <integer>5</integer>
      </dict>
      </plist>
    XML

    plist_path = "/Library/LaunchDaemons/com.plutonhq.pluton.plist"

    # Stop existing service if upgrading
    system_command "/bin/launchctl",
                   args: ["bootout", "system/com.plutonhq.pluton"],
                   sudo: true,
                   must_succeed: false

    # Write the plist file
    system_command "/bin/bash",
                   args: ["-c", "cat > #{plist_path} << 'PLIST_EOF'\n#{plist_content}PLIST_EOF"],
                   sudo: true

    # Set correct ownership and permissions
    system_command "/usr/sbin/chown", args: ["root:wheel", plist_path], sudo: true
    system_command "/bin/chmod", args: ["644", plist_path], sudo: true

    # Load and start the service
    system_command "/bin/launchctl",
                   args: ["bootstrap", "system", plist_path],
                   sudo: true
  end

  # Uninstall: stop service only. Install directory (/opt/pluton) is left in place
  # so that `brew upgrade` can overwrite files without losing keychain access.
  # Use `brew uninstall --zap` for full cleanup.
  uninstall launchctl: "com.plutonhq.pluton",
            delete:    "/Library/LaunchDaemons/com.plutonhq.pluton.plist"

  # zap removes everything including install dir, user data and keychain
  zap script: { executable: "/bin/bash",
                args:       ["-c",
                             "rm -rf /opt/pluton; " \
                             "security delete-keychain /var/root/Library/Keychains/pluton.keychain-db 2>/dev/null || true"],
                sudo:       true },
      trash:  "/var/lib/pluton"

  caveats <<~EOS
    Pluton has been installed and the background service is running.

    Access the dashboard at: http://localhost:5173

    On first launch, you will be prompted to set up your credentials
    via the web interface. Credentials are stored in macOS Keychain.

    IMPORTANT: Full Disk Access
    To back up files in protected directories (Desktop, Documents, etc.),
    you must grant Full Disk Access to the Pluton binary:
      System Settings → Privacy & Security → Full Disk Access
      Click + and add: /opt/pluton/pluton

    Service commands:
      sudo launchctl kickstart -k system/com.plutonhq.pluton   # Restart
      sudo launchctl bootout system/com.plutonhq.pluton        # Stop
      sudo launchctl bootstrap system /Library/LaunchDaemons/com.plutonhq.pluton.plist  # Start

    Logs: /var/lib/pluton/logs/

    To fully uninstall and remove all data:  brew uninstall --zap pluton
  EOS
end