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
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.12/llm-systems-agent-macos-arm64.tar.gz"
      sha256 "ae51b2b2bcc9f2ad564c9c6d1f61d59ea5cb1378a558ff47cd926ce1b2276b94"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.12/llm-systems-agent-linux-x86_64.tar.gz"
      sha256 "b9875e535ca29dbacbafad774f1bb314b12548653c8f7db0f5f5c791f00ebb20"
    end
    on_arm do
      url "https://github.com/llmsyscore/llm-systems-manager/releases/download/v1.0.12/llm-systems-agent-linux-arm64.tar.gz"
      sha256 "6738c9e8af60c5886fc5ff3457256ecbdbb9c4e9a5843bf215f9ccdcb2aa4595"
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
