class LlmSystemsAgent < Formula
  desc "Monitoring agent for LLM Systems Manager"
  homepage "https://github.com/llmsyscore/llm-systems-manager"
  license "AGPL-3.0-only"

  livecheck do
    url :homepage
    strategy :github_latest
  end

  on_macos do
    depends_on arch: :arm64
    on_arm do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v3.5.0/llm-systems-agent-macos-arm64-brew.tar.gz"
      sha256 "5614c149dd4d35b44aead987e06dd741aa26c124e5cba7dcb03d94a392f66ab1"
    end
    on_intel do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v3.5.0/llm-systems-agent-macos-arm64-brew.tar.gz"
      sha256 "5614c149dd4d35b44aead987e06dd741aa26c124e5cba7dcb03d94a392f66ab1"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v3.5.0/llm-systems-agent-linux-x86_64-brew.tar.gz"
      sha256 "167aa1ff4c54b5516bd2c21dbc84a571aac2d9744ee40a557e9666e3d194d067"
    end
    on_arm do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v3.5.0/llm-systems-agent-linux-arm64-brew.tar.gz"
      sha256 "572776157f4f7ed7e359da4a99f43374e134fd829efae9535ee4fc96e8daf735"
    end
  end

  def install
    seeded = File.read("agent_config.yaml.example")
    bin.install "llm-systems-agent"
    (etc/"llm-systems-agent").install "agent_config.yaml.example"
    # Live config = the full example with AGENT_OS matched to this platform;
    # every other key keeps its runtime-detected default until edited.
    config = etc/"llm-systems-agent/agent_config.yaml"
    unless config.exist?
      seeded = seeded.sub(/^AGENT_OS:(\s+)\S+/, "AGENT_OS:\\1#{OS.mac? ? "macos" : "linux"}")
      # Enrollment secret lives beside the config, not in the keg (survives upgrades).
      unless seeded.match?(/^ENROLLMENT_SECRET_FILE:/)
        seeded << "\nENROLLMENT_SECRET_FILE: \"#{etc}/llm-systems-agent/enrollment-secret\"\n"
      end
      config.write seeded
    end
  end

  def caveats
    conflict_hint = if OS.mac?
      <<~EOS
        If a script-based install exists (~/Library/LaunchAgents/com.llm-systems-agent.plist),
        remove it first: both agents would fight over port 8082.
      EOS
    else
      <<~EOS
        If a script/deb/rpm install exists (/etc/systemd/system/llm-systems-agent.service),
        stop and remove it first: both agents would fight over port 8082.
      EOS
    end
    <<~EOS
      Set MANAGER_URL in #{etc}/llm-systems-agent/agent_config.yaml, then:
        brew services start llmsyscore/tap/llm-systems-agent
      If the manager requires an enrollment secret (Admin > Agents > Manage),
      save it to #{etc}/llm-systems-agent/enrollment-secret before starting;
      the agent deletes that file once it is approved.
      Upgrade with `brew upgrade llm-systems-agent` — a manager-triggered agent
      self-update is reverted by the next brew upgrade, so prefer brew here.
      #{conflict_hint}
    EOS
  end

  service do
    run [opt_bin/"llm-systems-agent"]
    working_dir etc/"llm-systems-agent"
    keep_alive true
    log_path var/"log/llm-systems-agent/agent.log"
    error_log_path var/"log/llm-systems-agent/agent.err.log"
  end

  test do
    assert_match(/^v\d{4}\.\d{2}\.\d{2}/, shell_output("#{bin}/llm-systems-agent --version"))
  end
end
