cask "pluton-agent" do
  version "0.3.2"

  # A license key is required to download the Pluton Agent from the CDN.
  # A JSON configuration file (from the Pluton dashboard) is required on first install only.
  #
  # First install:
  #   export HOMEBREW_PLUTON_AGENT_LICENSE="YOUR_LICENSE_KEY"
  #   export HOMEBREW_PLUTON_AGENT_CONFIG="/path/to/agent-config.json"
  #   brew install plutonhq/pluton/pluton-agent
  #
  # Upgrade (config file not needed — existing credentials are preserved):
  #   export HOMEBREW_PLUTON_AGENT_LICENSE="YOUR_LICENSE_KEY"
  #   brew upgrade pluton-agent

  on_arm do
    sha256 "a3d389cafa89d6d3a28c31d3cea244c829b79cf7b76e60a3ed2e9a0e947f0e58"
    url "https://dl.usepluton.com/agent/releases/#{version}/pluton-agent-#{version}-darwin-arm64.tar.gz?license=#{ENV["HOMEBREW_PLUTON_AGENT_LICENSE"]}",
        header: "X-License-Key: #{ENV["HOMEBREW_PLUTON_AGENT_LICENSE"]}"
  end

  on_intel do
    sha256 "4c8f37b3a2f6dbe4f7a9c0da08ab4c0d4ba974aec9d0dfa9c48618ce1ff8211e"
    url "https://dl.usepluton.com/agent/releases/#{version}/pluton-agent-#{version}-darwin-amd64.tar.gz?license=#{ENV["HOMEBREW_PLUTON_AGENT_LICENSE"]}",
        header: "X-License-Key: #{ENV["HOMEBREW_PLUTON_AGENT_LICENSE"]}"
  end

  name "Pluton Agent"
  desc "Backup agent for Pluton - incremental backups, file sync, and remote operations"
  homepage "https://usepluton.com"

  depends_on macos: ">= :monterey"

  # Preflight: validate that the license key is set before attempting download.
  # On fresh install, also require the agent config file.
  preflight do
    license_key = ENV["HOMEBREW_PLUTON_AGENT_LICENSE"]
    if license_key.nil? || license_key.strip.empty?
      raise <<~EOS
        Pluton Agent requires a license key to install.

        Please set the HOMEBREW_PLUTON_AGENT_LICENSE environment variable:

          export HOMEBREW_PLUTON_AGENT_LICENSE="YOUR_LICENSE_KEY"
          brew install plutonhq/pluton/pluton-agent

        You can find your license key at: https://usepluton.com/account
      EOS
    end

    # Config file is only required on fresh install, not upgrades.
    # If an existing env file is present, we're upgrading.
    env_file = "/etc/pluton-agent/pluton-agent.env"
    is_upgrade = File.exist?(env_file)

    unless is_upgrade
      config_file = ENV["HOMEBREW_PLUTON_AGENT_CONFIG"]
      if config_file.nil? || config_file.strip.empty?
        raise <<~EOS
          Pluton Agent requires a configuration file for first-time installation.

          Please set the HOMEBREW_PLUTON_AGENT_CONFIG environment variable:

            export HOMEBREW_PLUTON_AGENT_CONFIG="/path/to/agent-config.json"
            brew install plutonhq/pluton/pluton-agent

          You can download the agent configuration file from the Pluton
          dashboard when adding a new device.
        EOS
      end

      unless File.exist?(config_file)
        raise "Agent configuration file not found at: #{config_file}"
      end
    end
  end

  # Install: copy binaries, create directories, write config, set up LaunchDaemon
  postflight do
    # --- Paths ---
    extracted_dir = if Hardware::CPU.arm?
      "#{staged_path}/pluton-agent-#{version}-darwin-arm64"
    else
      "#{staged_path}/pluton-agent-#{version}-darwin-amd64"
    end

    install_dir = "/usr/local/pluton-agent"
    data_dir    = "/var/lib/pluton-agent"
    config_dir  = "/etc/pluton-agent"
    env_file    = "#{config_dir}/pluton-agent.env"
    plist_path  = "/Library/LaunchDaemons/com.pluton.agent.plist"

    # --- Detect upgrade vs fresh install ---
    is_upgrade = File.exist?(env_file)

    # --- Load credentials ---
    if is_upgrade
      # On upgrade, read existing credentials from the env file
      agent_id = nil
      api_key = nil
      server_url = nil
      encryption_key = nil
      signing_key = nil
      license_key_val = nil

      File.readlines(env_file).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")
        key, value = line.split("=", 2)
        case key
        when "PLUTON_AGENT_ID" then agent_id = value
        when "PLUTON_AGENT_APIKEY" then api_key = value
        when "PLUTON_AGENT_SERVER_URL" then server_url = value
        when "PLUTON_AGENT_ENCRYPTION_KEY" then encryption_key = value
        when "PLUTON_AGENT_SIGNING_KEY" then signing_key = value
        when "PLUTON_LICENSE_KEY" then license_key_val = value
        end
      end
    else
      # On fresh install, parse the JSON config file
      require "json"
      config_file = ENV["HOMEBREW_PLUTON_AGENT_CONFIG"]
      config = JSON.parse(File.read(config_file))

      agent_id       = config["agentId"]
      api_key        = config["apiKey"]
      server_url     = config["serverUrl"]
      encryption_key = config["encryptionKey"]
      signing_key    = config["signingKey"]
      license_key_val = config["licenseKey"]

      # Validate required fields
      missing = []
      missing << "agentId" if agent_id.nil? || agent_id.to_s.strip.empty?
      missing << "apiKey" if api_key.nil? || api_key.to_s.strip.empty?
      missing << "serverUrl" if server_url.nil? || server_url.to_s.strip.empty?
      missing << "encryptionKey" if encryption_key.nil? || encryption_key.to_s.strip.empty?
      missing << "signingKey" if signing_key.nil? || signing_key.to_s.strip.empty?
      missing << "licenseKey" if license_key_val.nil? || license_key_val.to_s.strip.empty?

      unless missing.empty?
        raise "Agent configuration file is missing required fields: #{missing.join(", ")}"
      end
    end

    # --- Install binaries ---
    system_command "/bin/mkdir", args: ["-p", "#{install_dir}/bin"], sudo: true

    system_command "/bin/cp",
                   args: ["#{extracted_dir}/pluton-agent", "#{install_dir}/bin/"],
                   sudo: true
    system_command "/bin/cp",
                   args: ["#{extracted_dir}/restic", "#{install_dir}/bin/"],
                   sudo: true
    system_command "/bin/cp",
                   args: ["#{extracted_dir}/rclone", "#{install_dir}/bin/"],
                   sudo: true

    system_command "/bin/chmod", args: ["+x", "#{install_dir}/bin/pluton-agent"], sudo: true
    system_command "/bin/chmod", args: ["+x", "#{install_dir}/bin/restic"], sudo: true
    system_command "/bin/chmod", args: ["+x", "#{install_dir}/bin/rclone"], sudo: true

    # Copy helper scripts if present in the archive
    system_command "/bin/bash",
                   args: ["-c",
                          "cp #{extracted_dir}/*.sh #{install_dir}/bin/ 2>/dev/null; " \
                          "chmod +x #{install_dir}/bin/*.sh 2>/dev/null; true"],
                   sudo: true

    # --- Create data and config directories ---
    [data_dir, config_dir].each do |dir|
      system_command "/bin/mkdir", args: ["-p", dir], sudo: true
    end
    system_command "/bin/chmod", args: ["700", data_dir], sudo: true

    # --- Write environment file (only on fresh install; preserve existing on upgrade) ---
    unless is_upgrade
      env_content = <<~ENV
        # Pluton Agent Configuration
        PLUTON_AGENT_ID=#{agent_id}
        PLUTON_AGENT_APIKEY=#{api_key}
        PLUTON_AGENT_SERVER_URL=#{server_url}
        PLUTON_AGENT_ENCRYPTION_KEY=#{encryption_key}
        PLUTON_AGENT_SIGNING_KEY=#{signing_key}
        PLUTON_LICENSE_KEY=#{license_key_val}
      ENV

      system_command "/bin/bash",
                     args: ["-c", "cat > #{env_file} << 'ENVEOF'\n#{env_content}ENVEOF"],
                     sudo: true
      system_command "/bin/chmod", args: ["600", env_file], sudo: true
    end

    # --- Create LaunchDaemon plist ---
    plist_content = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>com.pluton.agent</string>
          <key>ProgramArguments</key>
          <array>
              <string>#{install_dir}/bin/pluton-agent</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
              <key>PLUTON_AGENT_ID</key>
              <string>#{agent_id}</string>
              <key>PLUTON_AGENT_APIKEY</key>
              <string>#{api_key}</string>
              <key>PLUTON_AGENT_SERVER_URL</key>
              <string>#{server_url}</string>
              <key>PLUTON_AGENT_ENCRYPTION_KEY</key>
              <string>#{encryption_key}</string>
              <key>PLUTON_AGENT_SIGNING_KEY</key>
              <string>#{signing_key}</string>
              <key>PLUTON_LICENSE_KEY</key>
              <string>#{license_key_val}</string>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>StandardOutPath</key>
          <string>/var/log/pluton-agent.log</string>
          <key>StandardErrorPath</key>
          <string>/var/log/pluton-agent.error.log</string>
          <key>WorkingDirectory</key>
          <string>#{data_dir}</string>
      </dict>
      </plist>
    XML

    # Stop existing service if upgrading
    system_command "/bin/launchctl",
                   args: ["bootout", "system/com.pluton.agent"],
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

  # Uninstall: stop service only. Binaries and config are left in place
  # so that `brew upgrade` can overwrite files without losing configuration.
  # Use `brew uninstall --zap` for full cleanup.
  uninstall launchctl: "com.pluton.agent",
            delete:    "/Library/LaunchDaemons/com.pluton.agent.plist"

  # zap removes everything including install dir, config, data, and logs
  zap script: { executable: "/bin/bash",
                args:       ["-c",
                             "rm -rf /usr/local/pluton-agent; " \
                             "rm -rf /etc/pluton-agent"],
                sudo:       true },
      trash:  ["/var/lib/pluton-agent",
               "/var/log/pluton-agent.log",
               "/var/log/pluton-agent.error.log"]

  caveats <<~EOS
    Pluton Agent has been installed and the background service is running.

    The agent is configured to connect to your Pluton server.
    You can verify the connection from the Pluton dashboard.

    IMPORTANT: Full Disk Access
    To back up files in protected directories (Desktop, Documents, etc.),
    you must grant Full Disk Access to the agent binary:
      System Settings → Privacy & Security → Full Disk Access
      Click + and add: /usr/local/pluton-agent/bin/pluton-agent

    Installation paths:
      Binaries:      /usr/local/pluton-agent/bin/
      Configuration: /etc/pluton-agent/
      Data:          /var/lib/pluton-agent/

    Service commands:
      sudo launchctl kickstart -k system/com.pluton.agent   # Restart
      sudo launchctl bootout system/com.pluton.agent        # Stop
      sudo launchctl bootstrap system /Library/LaunchDaemons/com.pluton.agent.plist  # Start

    Logs:
      tail -f /var/log/pluton-agent.log
      tail -f /var/log/pluton-agent.error.log

    To fully uninstall and remove all data:  brew uninstall --zap pluton-agent
  EOS
end
