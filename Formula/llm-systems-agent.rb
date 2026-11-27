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
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v3.5.1/llm-systems-agent-macos-arm64-brew.tar.gz"
      sha256 "d30d05f462ba38ec7b7f1f864cd942201b37f07acd0b3f4dc3aab07c440ba20c"
    end
    on_intel do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v3.5.1/llm-systems-agent-macos-arm64-brew.tar.gz"
      sha256 "d30d05f462ba38ec7b7f1f864cd942201b37f07acd0b3f4dc3aab07c440ba20c"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v3.5.1/llm-systems-agent-linux-x86_64-brew.tar.gz"
      sha256 "8cae14f15dff6e440cde69bed516d10f9fec10399a68eab40537d1f293aecd6d"
    end
    on_arm do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v3.5.1/llm-systems-agent-linux-arm64-brew.tar.gz"
      sha256 "bc2797ba76e4cd22167c994d17116bc7a4f1ddf95b4ef1c87bf445b93bb6ceef"
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
      agent_os = OS.mac? ? "macos" : "linux"
      seeded = seeded.sub(/^AGENT_OS:(\s+)\S+/, "AGENT_OS:\\1#{agent_os}")
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
